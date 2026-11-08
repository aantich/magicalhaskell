{-# LANGUAGE OverloadedStrings, DuplicateRecordFields #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}

module WebAPI.WebApp
where

import MidMonad
import Middleware (lgDbg)
import Web.Scotty.Trans (ScottyT, scottyT, text, status, middleware)
import qualified Web.Scotty.Trans as SC
import Network.Wai (Response, Request (..), Middleware)
import StackTypes (AppState, Settings)
import Network.Wai.Handler.Warp (Port)
import Control.Monad.MRWS 
import Network.HTTP.Types (status401)
import Data.ByteString.Char8 (unpack)
import LLM.OpenAI (Usage)

type WebApp = ScottyT Mid


tact :: Request -> Mid ()
tact req = do
    let path = rawPathInfo req
    lgDbg $ "Received request on " ++ unpack path ++ ":\n" ++ show (requestHeaders req)

loggingMiddleware :: MRWSTEnv Settings Usage AppState -> Middleware
loggingMiddleware env app req respond = do
    runMRWSTWith env (tact req)
    app req respond


mainServer :: Port -> MRWSTEnv Settings Usage AppState -> IO ()
mainServer port env = do
    scottyT port (convertResponse env) $ do
            middleware (loggingMiddleware env)
            SC.get "/" $ text "Hello world in ScottyT"
            SC.get "/error" $ do
                status status401
                text "Not authorized!"
            {-
            get "/api/node/list" $ do
                json defaultNodesResponse
            post "/api/appUserToken" $ do
                req <- request
                body <- liftIO $ requestBody req
                let sbody = decodeUtf8 (BL.fromStrict body)
                lift $ logDbg $ "Received appUserToken request:\n" ++ show sbody
                appUserToken
            post "/api/pipeline/:pipelineId/execute" $ do 
                apiExecutePipeline
            -}




convertResponse :: MRWSTEnv Settings Usage AppState -> Mid Response -> IO Response
convertResponse = runMRWSTWith
