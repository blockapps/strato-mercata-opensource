{-# LANGUAGE PackageImports #-}

module Blockchain.AESCTR
  ( encrypt,
    decrypt,
    AESCTRState (..),
    aesIV_,
  )
where

import "cipher-aes" Crypto.Cipher.AES
import Data.Bits
import qualified Data.ByteString as B

data AESCTRState = AESCTRState AES AESIV Int

getNextAESCTRBytes :: AESCTRState -> Int -> (AESCTRState, B.ByteString)
getNextAESCTRBytes (AESCTRState aes iv p) c =
  (AESCTRState aes next ((p + c) `rem` 16), B.drop p bytes)
  where
    (bytes, next) = genCounter aes iv (p + c)

encrypt :: AESCTRState -> B.ByteString -> (AESCTRState, B.ByteString)
encrypt state plainText =
  fmap (B.pack . B.zipWith xor plainText) $ getNextAESCTRBytes state (B.length plainText)

decrypt :: AESCTRState -> B.ByteString -> (AESCTRState, B.ByteString)
decrypt = encrypt
