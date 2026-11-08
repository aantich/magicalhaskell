{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import Control.Concurrent (newEmptyMVar, putMVar, takeMVar)
import Control.Concurrent.Async (cancel, concurrently, concurrently_, mapConcurrently_, wait, withAsync)
import Control.Concurrent.STM
    ( check, newTVarIO, orElse, readTVar, readTVarIO, retry, throwSTM, writeTVar )
import qualified Control.Exception as E
import Control.Monad (forM_, replicateM_, unless)
import qualified Control.Monad.Catch as C
import qualified Control.Monad.Except as X
import Control.Monad.IO.Unlift (withRunInIO)
import qualified Control.Monad.MRWS as M
import qualified Control.Monad.Reader as R
import qualified Control.Monad.RWS.Class as RWS
import qualified Control.Monad.State.Class as S
import qualified Control.Monad.Writer.Class as W
import Data.Either (isLeft)
import Data.Monoid (Sum(..))
import System.Timeout (timeout)

type TestM = M.MRWST Int [String] Int IO

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual label expected actual = unless (expected == actual) $
    E.throwIO $ userError $ label ++ ": expected " ++ show expected ++ ", got " ++ show actual

run :: TestM a -> IO (a, Int, [String])
run action = M.runMRWST action 7 0

newTestEnv :: IO (M.MRWSTEnv Int [String] Int)
newTestEnv = M.newMRWSTEnv 7 0

genericAction :: RWS.MonadRWS Int [String] Int m => m (Int, Int, [String])
genericAction = do
    settings <- R.ask
    S.put settings
    old <- S.state (\s -> (s, s + 1))
    (value, output) <- W.listen $ do
        W.tell ["generic"]
        R.local (+1) R.ask
    pure (old, value, output)

testInterfaces :: IO ()
testInterfaces = run genericAction >>=
    assertEqual "standard mtl interfaces" ((7, 8, ["generic"]), 8, ["generic"])

testRunners :: IO ()
testRunners = do
    let action = M.modify' (+1) >> M.tell ["one"] >> M.get :: TestM Int
    run action >>= assertEqual "run" (1, 1, ["one"])
    run action >>= assertEqual "independent run" (1, 1, ["one"])
    M.evalMRWST action 7 0 >>= assertEqual "eval" (1, ["one"])
    M.execMRWST action 7 0 >>= assertEqual "exec" (1, ["one"])
    env <- newTestEnv
    M.runMRWSTWith env action >>= assertEqual "first shared run" 1
    M.runMRWSTWith env action >>= assertEqual "second shared run" 2
    M.readMRWSTEnv env >>= assertEqual "shared output" (2, ["one", "one"])

testReader :: IO ()
testReader = do
    result <- run $ do
        before <- M.ask
        inside <- M.local (+10) $ do
            M.modify' (+1)
            M.tell ["local"]
            M.local (*2) M.ask
        after <- M.asks id
        pure (before, inside, after)
    assertEqual "local changes only settings" ((7, 34, 7), 1, ["local"]) result
    let failLocally = M.local (+1) (C.throwM (userError "local failure")) :: TestM Int
    run (C.catch failLocally (\(_ :: E.IOException) -> M.ask)) >>=
        assertEqual "local restores on exception" (7, 0, [])

testStrictness :: IO ()
testStrictness = do
    (caught, finalState, output) <- run $ do
        M.put 3
        result <- C.try (M.modify' (const (error "invalid state")))
        pure (isLeft (result :: Either E.ErrorCall ()))
    assertEqual "strict update throws before commit" (True, 3, []) (caught, finalState, output)
    run (do
        result <- C.try (M.modify (const (error "lazy state")))
        M.put 4
        pure (isLeft (result :: Either E.ErrorCall ()))) >>=
        assertEqual "unprimed modify stays lazy" (False, 4, [])

testUnlift :: IO ()
testUnlift = do
    result <- run $ do
        withRunInIO $ \runInIO -> do
            runInIO (M.modify' (+1) >> M.tell ["first"])
            runInIO (M.modify' (+2) >> M.tell ["second"])
        M.get
    assertEqual "callbacks reuse references" (3, 3, ["first", "second"]) result

testWriter :: IO ()
testWriter = do
    result <- run $ do
        W.tell ["before"]
        heard <- W.listen $ do
            W.tell ["a"]
            nested <- W.listen (W.writer (3 :: Int, ["b"]))
            W.censor (map (++ "!")) (W.tell ["c"])
            W.pass (W.tell ["d"] >> pure ((), map (++ "?")))
            M.modify' (+1)
            pure nested
        W.tell ["after"]
        pure heard
    assertEqual "nested scoped writer"
        (((3, ["b"]), ["a", "b", "c!", "d?"]), 1,
         ["before", "a", "b", "c!", "d?", "after"]) result
    run (M.listens length (M.tell ["x", "y"])) >>=
        assertEqual "listens" (((), 2), 0, ["x", "y"])

testWriterConcurrency :: IO ()
testWriterConcurrency = do
    ready <- newEmptyMVar
    resume <- newEmptyMVar
    result <- run $ withRunInIO $ \runInIO -> concurrently
        (runInIO $ M.listen $ do
            M.tell ["private"]
            M.modify' (+1)
            M.liftIO $ putMVar ready () >> takeMVar resume
            M.tell ["done"])
        (do
            takeMVar ready
            runInIO $ M.tell ["sibling"] >> M.modify' (+1)
            putMVar resume ())
    assertEqual "listen excludes sibling output"
        ((((), ["private", "done"]), ()), 2, ["sibling", "private", "done"]) result
    readyPass <- newEmptyMVar
    resumePass <- newEmptyMVar
    passResult <- run $ withRunInIO $ \runInIO -> concurrently_
        (runInIO $ M.censor (map (++ "!")) $ do
            M.tell ["private"]
            M.liftIO $ putMVar readyPass () >> takeMVar resumePass)
        (takeMVar readyPass >> runInIO (M.tell ["sibling"]) >> putMVar resumePass ())
    assertEqual "pass cannot transform sibling output" ((), 0, ["sibling", "private!"]) passResult

testExceptions :: IO ()
testExceptions = do
    let throwing = M.modify' (+1) >> M.tell ["before"] >> C.throwM (userError "failed") :: TestM ()
        recover (_ :: E.IOException) = M.tell ["caught"]
    run (C.catch throwing recover) >>=
        assertEqual "mutations survive caught exceptions" ((), 1, ["before", "caught"])
    run (C.catch (M.listen throwing >> pure ()) recover) >>=
        assertEqual "listen publishes on failure" ((), 1, ["before", "caught"])
    run (C.catch (M.pass (throwing >> pure ((), reverse))) recover) >>=
        assertEqual "pass publishes untransformed output on failure" ((), 1, ["before", "caught"])
    let invalidTransform = M.censor (const (error "invalid transformation")) (M.tell ["original"])
    run (C.catch invalidTransform (\(_ :: E.ErrorCall) -> M.tell ["caught"])) >>=
        assertEqual "failed transformation preserves original output" ((), 0, ["original", "caught"])
    let invalidResult = M.pass (M.tell ["original"] >> pure (error "invalid pass result"))
    run (C.catch invalidResult (\(_ :: E.ErrorCall) -> M.tell ["caught"])) >>=
        assertEqual "failed pass result preserves original output" ((), 0, ["original", "caught"])
    env <- newTestEnv
    failed <- E.try (M.runMRWSTWith env throwing) :: IO (Either E.IOException ())
    assertEqual "unhandled exception propagates" True (isLeft failed)
    M.readMRWSTEnv env >>= assertEqual "environment remains inspectable" (1, ["before"])

testMonadicAbort :: IO ()
testMonadicAbort = do
    env <- newTestEnv
    let abort = do
            M.modify' (+1)
            M.tell ["partial"]
            M.lift $ X.throwError "aborted"
        listened = M.listen abort :: M.MRWST Int [String] Int (X.ExceptT String IO) ((), [String])
    result <- X.runExceptT $ M.runMRWSTWith env listened
    assertEqual "ExceptT abort propagates" (Left "aborted") result
    M.readMRWSTEnv env >>= assertEqual "aborted scope flushes its output" (1, ["partial"])
    let passed = M.pass (abort >> pure ((), reverse)) :: M.MRWST Int [String] Int (X.ExceptT String IO) ()
    passResult <- X.runExceptT $ M.runMRWSTWith env passed
    assertEqual "pass abort propagates" (Left "aborted") passResult
    M.readMRWSTEnv env >>= assertEqual "aborted pass flushes untransformed output" (2, ["partial", "partial"])

testCancellation :: IO ()
testCancellation = do
    env <- newTestEnv
    ready <- newEmptyMVar
    never <- newEmptyMVar
    let action = M.listen $ do
            M.modify' (+1)
            M.tell ["partial"]
            M.liftIO $ putMVar ready () >> takeMVar never
    withAsync (M.runMRWSTWith env action :: IO ((), [String])) $ \worker -> do
        takeMVar ready
        cancel worker
    M.readMRWSTEnv env >>= assertEqual "cancelled writer publishes exactly once" (1, ["partial"])

testAtomicState :: IO ()
testAtomicState = do
    env <- M.newMRWSTEnv () (0 :: Int) :: IO (M.MRWSTEnv () (Sum Int) Int)
    mapConcurrently_ (\_ -> M.runMRWSTWith env $
        replicateM_ 1000 (M.modify' (+1) >> M.tell (Sum 1))) [1..8 :: Int]
    M.readMRWSTEnv env >>= assertEqual "concurrent atomic modify" (8000, Sum 8000)
    envState <- M.newMRWSTEnv () (0 :: Int) :: IO (M.MRWSTEnv () () Int)
    mapConcurrently_ (\_ -> M.runMRWSTWith envState $
        replicateM_ 1000 (S.state (\s -> ((), s + 1)))) [1..8 :: Int]
    M.readMRWSTEnv envState >>= assertEqual "standard state transition is atomic" (8000, ())

testAtomicStateWriter :: IO ()
testAtomicStateWriter = do
    env <- M.newMRWSTEnv () (0 :: Int) :: IO (M.MRWSTEnv () (Sum Int) Int)
    let update = M.runMRWSTWith env $
            replicateM_ 2000 $ M.stateWriter $ \(s, Sum w) -> ((), s + 1, Sum (w + 1))
        inspect = replicateM_ 2000 $ do
            (s, Sum w) <- M.readMRWSTEnv env
            assertEqual "consistent snapshot" s w
    concurrently_ update inspect
    M.readMRWSTEnv env >>= assertEqual "atomic state and writer" (2000, Sum 2000)
    let invalid = M.stateWriter (\(s, _) -> ((), s + 1, error "invalid output"))
    failure <- E.try (M.runMRWSTWith env invalid) :: IO (Either E.ErrorCall ())
    assertEqual "bad output rejects transaction" True (isLeft failure)
    M.readMRWSTEnv env >>= assertEqual "bad output cannot partially commit state" (2000, Sum 2000)

testSTM :: IO ()
testSTM = do
    env <- newTestEnv
    ref <- newTVarIO (0 :: Int)
    let rejected = M.atomicallyMRWST $ \_ -> do
            writeTVar ref 1
            throwSTM (userError "rollback")
    failure <- E.try (M.runMRWSTWith env rejected :: IO ()) :: IO (Either E.IOException ())
    assertEqual "STM exception propagates" True (isLeft failure)
    readTVarIO ref >>= assertEqual "external mutable variable rolls back" 0
    M.readMRWSTEnv env >>= assertEqual "state and output roll back" (0 :: Int, [] :: [String])
    result <- M.runMRWSTWith env $ M.atomicallyMRWST $ \(s, w) ->
        (writeTVar ref 99 >> retry) `orElse` do
            old <- readTVar ref
            writeTVar ref (old + 1)
            pure (old, s + 1, w ++ ["committed"])
    assertEqual "orElse does not see rolled back writes" 0 result
    readTVarIO ref >>= assertEqual "external variable commits with state" 1
    M.readMRWSTEnv env >>= assertEqual "fallback transaction commits" (1, ["committed"])
    ready <- newTVarIO False
    withAsync (M.runMRWSTWith env $ M.atomicallyMRWST $ \(s, w) -> do
        allowed <- readTVar ready
        check allowed
        pure ((), s + 1, w ++ ["resumed"])) $ \worker -> do
            M.runMRWSTWith env $ M.atomicallyMRWST $ \(s, w) -> do
                writeTVar ready True
                pure ((), s, w)
            wait worker
    M.readMRWSTEnv env >>= assertEqual "retry resumes after dependency changes" (2, ["committed", "resumed"])

main :: IO ()
main = forM_ tests $ \(name, action) -> do
    finished <- timeout 15000000 action
    case finished of
        Nothing -> E.throwIO $ userError (name ++ " timed out")
        Just () -> putStrLn ("PASS " ++ name)
  where
    tests =
        [ ("standard interfaces", testInterfaces)
        , ("runners and shared lifetime", testRunners)
        , ("reader scope", testReader)
        , ("strict state updates", testStrictness)
        , ("unlifted callbacks", testUnlift)
        , ("nested writer operations", testWriter)
        , ("concurrent writer scopes", testWriterConcurrency)
        , ("exception semantics", testExceptions)
        , ("underlying monad aborts", testMonadicAbort)
        , ("writer cancellation", testCancellation)
        , ("concurrent state updates", testAtomicState)
        , ("atomic state/output updates", testAtomicStateWriter)
        , ("STM composition and rollback", testSTM)
        ]
