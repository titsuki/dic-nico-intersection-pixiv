{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}
module Main where

import           Codec.Archive.Zip
import qualified Data.ByteString.Lazy as BL
import           Data.Maybe
import           Data.Monoid
import qualified Data.Set             as S
import qualified Data.Text            as T
import qualified Data.Text.Encoding   as T
import qualified Data.Text.IO         as T
import qualified Data.Text.Lazy       as TL
import           Data.Text.Normalize
import           Network.HTTP.Simple
import           Network.HTTP.Types
import           Text.XML
import           Text.XML.Cursor
import           Text.XML.Scraping
import           Text.XML.Selector.TH

main :: IO ()
main = do
    dicNico <- getDicNico
    dicPixiv <- getDicPixiv
    mapM_ (\(y, w) -> T.putStrLn $ y <> "\t" <> w <> "\t" <> "固有名詞") $
        S.filter (\(_, w) -> S.member w dicPixiv) dicNico

getDicNico :: IO (S.Set (T.Text, T.Text))
getDicNico = do
    Archive { zEntries = [ _, msimeEntry@Entry { eRelativePath = "nicoime_msime.txt" } ] } <-
        toArchive . getResponseBody <$> httpLbs "http://tkido.com/data/nicoime.zip"
    return . S.map (\[y, w, _] -> (normalize NFKC y, normalize NFKC w)) .
        S.map (T.split ('\t' ==)) . S.fromList . drop 8 . T.lines . T.decodeUtf16LE . BL.toStrict $
        fromEntry msimeEntry

getDicPixiv :: IO (S.Set T.Text)
getDicPixiv = do
    sitemap <- fromDocument . parseLBS_ def . getResponseBody <$>
        httpLbs "https://dic.pixiv.net/sitemap/"
    sitemaps <- mapM (\loc -> fromDocument . parseLBS_ def . getResponseBody <$>
                         httpLbs (parseRequest_ (TL.unpack (innerText loc)))) $
        queryT [jq|loc|] sitemap
    return $ S.fromList $ map (normalize NFKC . T.decodeUtf8 . urlDecode False . T.encodeUtf8) $
        mapMaybe (T.stripPrefix "https://dic.pixiv.net/a/") $
        concatMap (map (TL.toStrict . innerText) . queryT [jq|loc|]) sitemaps
