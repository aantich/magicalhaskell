{-# LANGUAGE OverloadedStrings, DuplicateRecordFields #-}

module Commands
where
import qualified Data.Text as T
import Control.Monad.MRWS

import StackTypes
import Middleware (chatCompletionMid, embedTextMid, searchRAGM, buildContextM)
import LLM.OpenAI (userMessage, embedText, systemMessage)
import System.Console.Haskeline (outputStrLn, InputT)
import Util.PrettyPrinting (as, yellow, white, bold, blue, lblue, lgreen)
import Util.Formatting
import qualified Data.Vector as V


import CMark
import MidMonad (Mid)
import Data.ByteString (unpack)

type App = InputT Mid

data CommandDescription = CommandDescription {
    helpTextShort :: String,
    helpTextLong :: String,
    commandName :: String,
    commandAction :: [String] -> App() -- [String] only includes options
}

allCommands::[CommandDescription]
allCommands = [
        CommandDescription {
            helpTextShort = ":send -- send a multiline message currently typed",
            helpTextLong = ":send -- send a multiline message currently typed",
            commandName = "send",
            commandAction = commandSendText
        },
        CommandDescription {
            helpTextShort = ":multi -- toggle multiline mode on or off",
            helpTextLong = ":multi -- toggle multiline mode on or off",
            commandName = "multi",
            commandAction = commandToggleMultiline
        },
        CommandDescription {
            helpTextShort = ":embed -- create embeddings for the buffer text and save them to in-memory storage and mongo",
            helpTextLong = ":embed -- create embeddings for the buffer text and save them to in-memory storage and mongo",
            commandName = "embed",
            commandAction = commandEmbed
        },
        CommandDescription {
            helpTextShort = ":search n -- search in the Vector RAG and show top n items",
            helpTextLong = ":search n -- search in the Vector RAG and show top n items",
            commandName = "search",
            commandAction = commandSearchRAG
        }
    ]

processCommand :: [String] -> App()
processCommand ("help":_) = commandHelp
processCommand (cmd:opts) = do
    let c = filter (\x -> commandName x == cmd) allCommands
    if not (null c) then commandAction (head c) opts
    else controlMessage [white, bold] "No such command. Please try :help"
processCommand _ = controlMessage [white, bold] "No such command. Please try :help"

commandHelp :: App()
commandHelp = mapM_ (controlMessage [white,bold] . helpTextShort) allCommands

commandSearchRAG :: [String] -> App()
commandSearchRAG (x:_) =
    let n = read x :: Int
    in  _commandSearchRAG n
commandSearchRAG _ = _commandSearchRAG 5

_commandSearchRAG :: Int -> App()
_commandSearchRAG n = do
    txt <- currentLineBuffer <$> lift (gets uiState)
    if T.length txt > 0 then do
        res <- lift (searchRAGM n txt)
        uis <- lift (gets uiState)
        lift $ modify (\s -> s { uiState = uis { currentLineBuffer = ""}})
        controlMessage [lgreen] "[Search Results:]"
        V.mapM_ (\(txt, score) -> controlMessage [white] ("[" ++ show score ++ "] " ++ T.unpack (T.take 80 txt))) res
    else controlMessage [yellow] "[WARNING] Your message is empty, please type something first"


commandEmbed :: [String] -> App()
commandEmbed _ = do
    txt <- currentLineBuffer <$> lift (gets uiState)
    if T.length txt > 0 then do
        lift (embedTextMid txt)
        uis <- lift (gets uiState)
        lift $ modify (\s -> s { uiState = uis { currentLineBuffer = ""}})
        controlMessage [lgreen] "[SUCCESS] Embedded"
    else controlMessage [yellow] "[WARNING] Your message is empty, please type something first"

-- toggle multiline mode on or off
commandToggleMultiline :: [String] -> App()
commandToggleMultiline _ = do
    uis <- lift (gets uiState)
    lift $ modify (\s -> s { uiState = uis {multilineMode = not (multilineMode uis)}})
    controlMessage [lgreen] ("[INFO] Multiline mode: " ++ show (not (multilineMode uis)))

-- send the text that is currently in the text buffer
commandSendText :: [String] -> App()
commandSendText _ = do
    txt <- currentLineBuffer <$> lift (gets uiState)
    if T.length txt > 0 then do
        -- getting RAG context
        ctx <- lift (searchRAGM 3 txt >>= buildContextM 0.6)
        msgs <- lift (gets messageHistory)
        lift $ modify (\s -> s {messageHistory = systemMessage ctx : msgs} )
        (asMsg, _) <- lift (chatCompletionMid $ userMessage txt)
        uis <- lift (gets uiState)
        lift $ modify (\s -> s { uiState = uis { currentLineBuffer = ""}})
        let fmt = highlightCode "Markdown" (T.pack asMsg)
        outputStrLn (T.unpack fmt)
    else controlMessage [yellow] "[WARNING] Your message is empty, please type something first"


-- output ansified text message
controlMessage :: [String] -> String -> App()
controlMessage opts msg = outputStrLn (as opts msg)

-- checking for multiline mode
isMultilineOn :: App Bool
isMultilineOn = multilineMode <$> lift (gets uiState)
