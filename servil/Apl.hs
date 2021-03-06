{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralisedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ViewPatterns #-}

import qualified Data.ByteString as ByteString
import Data.Function
import Data.Maybe
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEnc
import Database.MongoDB.Connection
import Database.Persist
import Database.Persist.MongoDB
import Database.Persist.TH
import Datum
import Language.Haskell.TH (Type(..))
import Lingvar
import qualified System.FilePath as FilePath
import Yesod
import qualified Yesod.Core.Content as YesCont

share
  [mkPersist (mkPersistSettings (ConT ''MongoContext))]
  [persistLowerCase|
|]

data DosierPeto =
  DosierPeto
    { dosPlenNomo :: !Text.Text
    , dosFin :: !Text.Text
    }
  deriving (Eq, Show, Read)

instance PathPiece DosierPeto where
  toPathPiece = dosPlenNomo
  fromPathPiece x =
    let (kom, fin) = Text.breakOnEnd "." x
     in if Text.null kom
          then Nothing
          else Just $ DosierPeto x fin

mkYesod
  "Servil"
  [parseRoutes|
/lingvar Lingvar GET
!/#DosierPeto DosierP GET
|]

instance Yesod Servil

getLingvar :: Handler TypedContent
getLingvar = lingvar

-- /#DosierPeto DosierP GET
sufAlTip :: DosierPeto -> ContentType
sufAlTip = f' . dosFin
  where
    f' "html" = YesCont.typeHtml
    f' x
      | x `elem` ["jpeg", "jpg"] = YesCont.typeJpeg
    f' "png" = YesCont.typePng
    f' "gif" = YesCont.typeGif
    f' "svg" = YesCont.typeSvg
    f' "js" = YesCont.typeJavascript
    f' "css" = YesCont.typeCss
    f' "json" = YesCont.typeJson
    f' x
      | x `elem` ["oft", "ttf", "woff", "woff2"] =
        ByteString.concat ["font/", TextEnc.encodeUtf8 x]
    f' _ = YesCont.typeOctet

statVoj =
  FilePath.joinPath .
  ("stat/" :) .
  filter purF . FilePath.splitPath . FilePath.normalise . dropWhile (== '/')
  where
    purF x = x /= "../" && x /= "./"

getDosierP :: DosierPeto -> Handler ()
getDosierP peto =
  sendFile (sufAlTip peto) $ statVoj $ Text.unpack $ dosPlenNomo peto

main :: IO ()
main = do
  mongo <-
    createMongoDBPool
      "obskura"
      "10.233.2.2"
      defaultPort
      Nothing
      defaultPoolStripes
      defaultStripeConnections
      defaultConnectionIdleTime
  mankoj <- legMankojn
  warp 3000 $ Servil {akirKonekt = mongo, akirLingvMank = mankoj}
