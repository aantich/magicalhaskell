{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- | Reader, Writer and State backed by mutable references. IO callbacks share
-- those references, so 'MonadUnliftIO' does not discard their effects.
--
-- Mutations survive caught exceptions. Use 'atomicallyMRWST' when several
-- changes (including other TVars) must commit or roll back together. Arbitrary
-- IO cannot be rolled back. Join child threads before leaving a runner or a
-- scoped writer operation; otherwise its result is only a snapshot.
module Control.Monad.MRWS
    ( MRWST
    , MRWSTEnv
    , newMRWSTEnv
    , runMRWSTWith
    , readMRWSTEnv
    , runMRWST
    , evalMRWST
    , execMRWST
    , ask
    , asks
    , reader
    , local
    , tell
    , writer
    , listen
    , listens
    , pass
    , censor
    , get
    , gets
    , put
    , state
    , state'
    , modify
    , modify'
    , stateWriter
    , atomicallyMRWST
    , R.lift
    , R.liftIO
    ) where

import Control.Concurrent.STM
    ( STM, TVar, atomically, modifyTVar', newTVar, newTVarIO
    , readTVar, readTVarIO, writeTVar )
import qualified Control.Monad.Catch as C
import Control.Monad.IO.Unlift (MonadUnliftIO)
import qualified Control.Monad.Reader as R
import qualified Control.Monad.RWS.Class as RWS
import qualified Control.Monad.State.Class as S
import qualified Control.Monad.Writer.Class as W

-- | An opaque environment. Reuse it to share state and output between runs.
-- Separate cells let scoped writers share state without capturing sibling logs.
data MRWSTEnv r w s = MRWSTEnv
    { environment :: r
    , stateRef :: TVar s
    , writerRef :: TVar w
    }

newtype MRWST r w s m a = MRWST (R.ReaderT (MRWSTEnv r w s) m a)
    deriving (Functor, Applicative, Monad, R.MonadTrans, R.MonadIO,
              C.MonadThrow, C.MonadCatch, C.MonadMask, MonadUnliftIO)

instance Monad m => R.MonadReader r (MRWST r w s m) where
    ask = MRWST $ R.asks environment
    local f (MRWST action) = MRWST $
        R.local (\env -> env { environment = f (environment env) }) action

instance R.MonadIO m => S.MonadState s (MRWST r w s m) where
    get = MRWST $ R.asks stateRef >>= R.liftIO . readTVarIO
    put value = MRWST $ do
        ref <- R.asks stateRef
        R.liftIO $ atomically $ writeTVar ref value
    state = state

instance (R.MonadIO m, C.MonadMask m, Monoid w) =>
        W.MonadWriter w (MRWST r w s m) where
    writer = writer
    tell = tell
    listen = listen
    pass = pass

instance (R.MonadIO m, C.MonadMask m, Monoid w) =>
        RWS.MonadRWS r w s (MRWST r w s m)

newMRWSTEnv :: (R.MonadIO m, Monoid w) => r -> s -> m (MRWSTEnv r w s)
newMRWSTEnv settings initial = R.liftIO $ atomically $
    MRWSTEnv settings <$> newTVar initial <*> newTVar mempty

-- | Run in an existing environment, retaining mutations even if the action
-- throws. This is the runner for callbacks, requests and application-wide state.
runMRWSTWith :: MRWSTEnv r w s -> MRWST r w s m a -> m a
runMRWSTWith env (MRWST action) = R.runReaderT action env

-- | Take a consistent snapshot of state and accumulated output.
readMRWSTEnv :: R.MonadIO m => MRWSTEnv r w s -> m (s, w)
readMRWSTEnv env = R.liftIO $ atomically $
    (,) <$> readTVar (stateRef env) <*> readTVar (writerRef env)

-- | Allocate an independent environment for one computation, like 'RWST'.
runMRWST :: (R.MonadIO m, Monoid w) =>
    MRWST r w s m a -> r -> s -> m (a, s, w)
runMRWST action settings initial = do
    env <- newMRWSTEnv settings initial
    result <- runMRWSTWith env action
    (finalState, output) <- readMRWSTEnv env
    pure (result, finalState, output)

evalMRWST :: (R.MonadIO m, Monoid w) =>
    MRWST r w s m a -> r -> s -> m (a, w)
evalMRWST action settings initial = do
    (result, _, output) <- runMRWST action settings initial
    pure (result, output)

execMRWST :: (R.MonadIO m, Monoid w) =>
    MRWST r w s m a -> r -> s -> m (s, w)
execMRWST action settings initial = do
    (_, finalState, output) <- runMRWST action settings initial
    pure (finalState, output)

ask :: Monad m => MRWST r w s m r
ask = R.ask

asks :: Monad m => (r -> a) -> MRWST r w s m a
asks = R.asks

reader :: Monad m => (r -> a) -> MRWST r w s m a
reader = R.reader

local :: Monad m => (r -> r) -> MRWST r w s m a -> MRWST r w s m a
local = R.local

-- | Atomically append output, forcing the accumulator to WHNF. For strict
-- numeric fields inside a record, use strict fields in the record as well.
tell :: (R.MonadIO m, Semigroup w) => w -> MRWST r w s m ()
tell output = MRWST $ do
    ref <- R.asks writerRef
    R.liftIO $ atomically $ modifyTVar' ref (<> output)

writer :: (R.MonadIO m, Semigroup w) => (a, w) -> MRWST r w s m a
writer (result, output) = tell output >> pure result

-- Run with private output but the same state. Publish exactly once, including
-- on cancellation or a synchronous exception. On failure, 'pass' publishes the
-- original output if the action or its transformation fails. generalBracket
-- also flushes on monadic aborts, such as an ExceptT action returning Left.
scopedWriter :: (R.MonadIO m, C.MonadMask m, Monoid w) =>
    MRWST r w s m (a, w -> w) -> MRWST r w s m (a, w)
scopedWriter action = MRWST $ R.ReaderT $ \env -> do
    let publish outputRef transform = R.liftIO $ atomically $ do
            output <- readTVar outputRef
            let transformed = transform output
            transformed `seq` modifyTVar' (writerRef env) (<> transformed)
            pure output
        release outputRef exitCase = case exitCase of
            C.ExitCaseSuccess completed ->
                publish outputRef (snd completed) `C.onException` publish outputRef id
            _ -> publish outputRef id
    ((result, _), output) <- C.generalBracket
        (R.liftIO $ newTVarIO mempty)
        release
        (\outputRef -> runMRWSTWith (env { writerRef = outputRef }) action)
    pure (result, output)

listen :: (R.MonadIO m, C.MonadMask m, Monoid w) =>
    MRWST r w s m a -> MRWST r w s m (a, w)
listen action = scopedWriter $ do
    result <- action
    pure (result, id)

listens :: (R.MonadIO m, C.MonadMask m, Monoid w) =>
    (w -> b) -> MRWST r w s m a -> MRWST r w s m (a, b)
listens select action = do
    (result, output) <- listen action
    pure (result, select output)

pass :: (R.MonadIO m, C.MonadMask m, Monoid w) =>
    MRWST r w s m (a, w -> w) -> MRWST r w s m a
pass action = fst <$> scopedWriter action

censor :: (R.MonadIO m, C.MonadMask m, Monoid w) =>
    (w -> w) -> MRWST r w s m a -> MRWST r w s m a
censor transform action = pass $ do
    result <- action
    pure (result, transform)

get :: R.MonadIO m => MRWST r w s m s
get = S.get

gets :: R.MonadIO m => (s -> a) -> MRWST r w s m a
gets = S.gets

put :: R.MonadIO m => s -> MRWST r w s m ()
put = S.put

-- | An atomic read/modify/return operation. Unlike a separate 'get' and 'put',
-- concurrent calls cannot overwrite a change based on a stale read.
state :: R.MonadIO m => (s -> (a, s)) -> MRWST r w s m a
state transition = MRWST $ do
    ref <- R.asks stateRef
    R.liftIO $ atomically $ do
        old <- readTVar ref
        let (result, new) = transition old
        writeTVar ref new
        pure result

state' :: R.MonadIO m => (s -> (a, s)) -> MRWST r w s m a
state' transition = MRWST $ do
    ref <- R.asks stateRef
    R.liftIO $ atomically $ do
        old <- readTVar ref
        let (result, new) = transition old
        new `seq` writeTVar ref new
        pure result

modify :: R.MonadIO m => (s -> s) -> MRWST r w s m ()
modify f = state (\old -> ((), f old))

-- | Force the new state itself to WHNF before committing it. Exceptions while
-- evaluating the new state leave the previous state intact.
modify' :: R.MonadIO m => (s -> s) -> MRWST r w s m ()
modify' f = state' (\old -> ((), f old))

-- | Atomically update state and output together, returning a result. Both new
-- values are forced to WHNF before commit.
stateWriter :: R.MonadIO m => ((s, w) -> (a, s, w)) -> MRWST r w s m a
stateWriter transition = atomicallyMRWST (pure . transition)

-- | Compose state/output changes with arbitrary STM operations on other TVars.
-- 'retry', 'orElse' and exceptions have normal STM rollback semantics. Only STM
-- actions belong here; use 'liftIO' for IO outside the transaction.
atomicallyMRWST :: R.MonadIO m =>
    ((s, w) -> STM (a, s, w)) -> MRWST r w s m a
atomicallyMRWST transition = MRWST $ do
    env <- R.ask
    R.liftIO $ atomically $ do
        old <- (,) <$> readTVar (stateRef env) <*> readTVar (writerRef env)
        (result, newState, newOutput) <- transition old
        newState `seq` newOutput `seq` do
            writeTVar (stateRef env) newState
            writeTVar (writerRef env) newOutput
        pure result
