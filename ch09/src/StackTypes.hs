{-# LANGUAGE OverloadedStrings, DuplicateRecordFields #-}

module StackTypes
where
    
import LLM.OpenAI (ProviderData)
import Data.Text (Text)

-- type that will hold our read-only configuration data
data Settings = Settings {
    llmProviders :: [ProviderData]
} deriving (Show)

-- type that will hold the State for our App
data AppState = AppState {}

-- returns provider data (url, secrets etc) by its name
findProviderByName :: Settings -> Text -> ProviderData
-- default is OpenAI
findProviderByName st _ = head (llmProviders st)
