{-# LANGUAGE OverloadedStrings #-}

module Main where

import Blockchain.Strato.Mining.Ethash.Cache
import Blockchain.Strato.Mining.Ethash.Constants
import Blockchain.Strato.Mining.Ethash.Dataset
import Control.Monad
import qualified Data.Array.IO as A
import Data.Binary
import qualified Data.ByteString as B
import Data.ByteString.Internal
import qualified Data.ByteString.Lazy as BL
import Numeric

encodeWord8 :: Word8 -> String
encodeWord8 c | c < 0x20 || c > 0x7e = "\\x" ++ showHex c ""
encodeWord8 c = [w2c c]

encodeByteString :: B.ByteString -> String
encodeByteString = (encodeWord8 =<<) . B.unpack

main :: IO ()
main = do
  cache <- mkCache (fromIntegral $ cacheSize 0) $ B.replicate 32 0

  forM_ [0 .. fullSize 0 `quot` 64 - 1] $ \i -> do
    slice <- calcDatasetItem cache $ fromIntegral i
    forM_ [0 .. 15] $ \j -> do
      x <- A.readArray slice j
      BL.putStr $ encode x
