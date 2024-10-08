{-# LANGUAGE OverloadedStrings, DuplicateRecordFields #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeApplications #-}

module Middleware
where

import StackTypes (Settings (..), AppState (AppState, loggerState, currentModelId, memoryStore), findProviderByName, currentProvider, messageHistory)
import Util.Logger
import LLM.OpenAI (Usage, chatCompletion, Message, processResp, providerDefaultOptions, assistantMessage, embedText, embeddingModels, embeddingName)
import Data.Text (pack, Text)
import Util.PrettyPrinting (as, white, bold, lgreen)
import Control.Monad.MRWS
import qualified Data.Vector as V
import Mongo.MongoRAG
import qualified Database.MongoDB
import Mongo.Core (MongoState(..))
import Data.Functor ((<&>))
import Mongo.MidLayer (MongoCollection(findAll, insertOne))
import MidMonad (Mid)
import VectorStorage.InMemory (addRAGData, sortedSearchResults)
import qualified Data.ByteString as T
import qualified Data.Text as TX
import qualified Data.Aeson as AE
import Integrail.API (callAgentStreaming, processRespInt)
import Control.Monad (void)
-- import Mongo.MongoRAG (insertRAGM)

-- in memory storage
buildRAGM :: Mid (V.Vector RAGData)
buildRAGM = do
    -- Explicitly specify the type application for `RAGData`
    records <- findAll @RAGData
    return $ V.fromList records

-- search the storage and return top n results
searchRAGM :: Int -> Text -> Mid (V.Vector (Text, Float))
searchRAGM n txt = do
    st <- get
    let prov = currentProvider st
    let mdlName = embeddingName (head embeddingModels)
    v <- lift $ embedText txt mdlName prov (loggerState st)
    let ms = memoryStore st
    let res = sortedSearchResults n v ms
    pure res

-- build context out of the RAG results with a minimum threshold
buildContextM :: Float -> V.Vector (Text, Float) -> Mid Text
buildContextM minScore res = do
    let fres = V.filter (\(_, sc) -> sc >= minScore) res
    let txt = V.foldl' (\acc v -> acc `TX.append` "\n\n" `TX.append` (fst v)) "Please use the following additional context when answering the user but only if it is relevant:\n\n" fres
    pure txt

-- integrail ------------------------------
callAgentMid :: AE.Value -> Mid ()
callAgentMid inp = do
    let agentId = "N2jB2ZX35mDWXw8Z4"
    lgs <- gets loggerState
    ind <- asks integrailSettings
    maybe (liftIO $ putStrLn "Integrail Key and / or API URL not found. Please register at https://integrail.ai and fill in the .env file")
          (\ind' -> liftIO $ void (callAgentStreaming ind' inp agentId lgs processRespInt))
          ind



-- openai ---------------------------------
embedTextMid :: Text -> Mid ()
embedTextMid txt = do
    st <- get
    let prov = currentProvider st
    let mdlName = embeddingName (head embeddingModels)
    v <- lift $ embedText txt mdlName prov (loggerState st)
    let obj = RAGData Nothing txt v
    -- inserting to mongo
    _id <- insertOne @RAGData obj
    lgDbg $ "Succesfully inserted " ++ show _id
    -- now inserting to in-memory store
    modify (\s -> s { memoryStore = addRAGData (memoryStore s) obj})

chatCompletionMid :: Message -> Mid (String, Usage)
chatCompletionMid message = do
    st <- get
    let provider = currentProvider st
    let msgs = messageHistory st
    let messages = msgs ++ [message]
    liftIO (putStrLn "" >> putStrLn (as [white,bold] "[Jarvis]"))
    (asMsg, us) <- lift $ chatCompletion messages (currentModelId st) provider Nothing (loggerState st) processResp
    let messages' = messages ++ [assistantMessage $ pack asMsg]
    modify (\s -> s {messageHistory = messages'})
    tell us
    pure (asMsg, us)
    -- liftIO (putStrLn "" >> putStrLn (as [lgreen,bold] "[DONE]"))
    -- liftIO (putStrLn "" >> putStrLn (as [white,bold] "[User]"))



-- logging --------------------------------
lgL :: LogLevels -> String -> Mid ()
lgL lvl msg = gets loggerState >>= liftIO . lgl lvl msg

lgFtl :: [Char] -> Mid ()
lgFtl msg = gets loggerState >>= liftIO . lg_ftl msg
lgErr :: [Char] -> Mid ()
lgErr msg = gets loggerState >>= liftIO . lg_err msg
lgWrn :: [Char] -> Mid ()
lgWrn msg = gets loggerState >>= liftIO . lg_wrn msg
lgInf :: [Char] -> Mid ()
lgInf msg = gets loggerState >>= liftIO . lg_inf msg
lgSuc :: [Char] -> Mid ()
lgSuc msg = gets loggerState >>= liftIO . lg_suc msg
lgDbg :: [Char] -> Mid ()
lgDbg msg = gets loggerState >>= liftIO . lg_dbg msg
lgVrb :: [Char] -> Mid ()
lgVrb msg = gets loggerState >>= liftIO . lg_vrb msg

