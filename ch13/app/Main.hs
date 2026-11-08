{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Init (initAll)
import System.Console.Haskeline
    ( noCompletion,
      runInputT)
import qualified System.Console.Haskeline as HL
import App (loop)
import Control.Monad.MRWS
import Middleware (lgInf)
import Util.PrettyPrinting (as, white, bold, yellow, lgreen)

import WebAPI.WebApp (mainServer)
import Control.Concurrent.Async (withAsync, link)


main :: IO ()
main = do
    (sett, initSt) <- initAll
    env <- newMRWSTEnv sett initSt
    runMRWSTWith env (lgInf "starting up Jarvis")
    -- The server, its request middleware and the CLI all reuse this environment.
    withAsync (mainServer 8080 env) $ \server -> do
        link server
        showHeader
        putStrLn "" >> putStrLn (as [white,bold] "[User]")
        let hset = HL.Settings {HL.historyFile = Just ".jarvis_history", HL.complete = noCompletion, HL.autoAddHistory=True}
        runMRWSTWith env (runInputT hset loop)
    (_, w) <- readMRWSTEnv env
    putStrLn "Total usage:"
    print w
    putStrLn "Bye!"

showHeader :: IO ()
showHeader = do
    putStrLn (as [white,bold] "Welcome to the Jarvis AI System!")
    putStrLn "Version 1.0.0"
    putStrLn ""
    putStrLn $ "For help, type " ++ as [yellow, bold] ":help"
    putStrLn $ "In the multiline mode, type freely and then on the new line type " ++ as [yellow, bold] ":send" ++ " to send the message"
    putStrLn $ "In the single-line mode, every time you hit " ++ as [lgreen, bold] "'Enter'" ++ " the message will be sent"
    putStrLn "Enjoy!"
    putStrLn ""