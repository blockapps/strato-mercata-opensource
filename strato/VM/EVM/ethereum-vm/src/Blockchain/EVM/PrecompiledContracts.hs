{-# LANGUAGE OverloadedStrings #-}

module Blockchain.EVM.PrecompiledContracts
  ( callPrecompiledContract,
  )
where

import Blockchain.EVM.OpcodePrices
import Blockchain.Strato.Model.Address
import Blockchain.Strato.Model.Code
import Blockchain.Strato.Model.Gas
import qualified Blockchain.Strato.Model.Secp256k1 as EC
import Blockchain.Strato.Model.Util
import qualified Crypto.Hash.RIPEMD160 as RIPEMD
import qualified Crypto.Hash.SHA256 as SHA2
import qualified Crypto.Secp256k1 as S
import Data.Binary hiding (get, put)
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Short as Short
import Prelude hiding (EQ, GT, LT)

--import Debug.Trace

ecdsaRecover :: B.ByteString -> B.ByteString
ecdsaRecover input =
  let h = B.take 32 input
      v = byteString2Integer $ B.take 32 $ B.drop 32 input
      r = Short.toShort $ B.take 32 $ B.drop 64 input
      s = Short.toShort $ B.take 32 $ B.drop 96 input
      maybePubKey = EC.recoverPub (EC.Signature (S.CompactRecSig r s (fromInteger v - 0x1b))) h
   in case (v >= 27, v <= 28, maybePubKey) of
        (True, True, Just pubKey) ->
          B.pack [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] `B.append` BL.toStrict (encode $ fromPublicKey pubKey)
        _ -> B.empty -- B.pack (replicate 32 0)

ripemd :: B.ByteString -> B.ByteString
ripemd input =
  B.replicate 12 0 `B.append` RIPEMD.hash input

sha2 :: B.ByteString -> B.ByteString
sha2 input =
  --    let val = fromInteger $ byteString2Integer $ B.take 32 input
  --    in
  SHA2.hash input

-- Byzantium
modExp :: B.ByteString -> B.ByteString
modExp input = -- parse arguments
  let bSize = fromInteger $ byteString2Integer $ B.take 32 input
      eSize = fromInteger $ byteString2Integer $ B.take 32 $ B.drop 32 input
      mSize = fromInteger $ byteString2Integer $ B.take 32 $ B.drop 64 input
      b = byteString2Integer $ B.take bSize $ B.drop 96 input
      e = byteString2Integer $ B.take eSize $ B.drop (96 + bSize) input
      m = byteString2Integer $ B.take mSize $ B.drop (96 + bSize + eSize) input
   in BL.toStrict $ encode $ b + e + m -- just use all vars for now. next, implement modular exponentiation.

callPrecompiledContract :: PrecompiledCode -> B.ByteString -> (Gas, B.ByteString)
callPrecompiledContract NullContract _ = (0, B.empty)
callPrecompiledContract ECRecover inputData =
  let ret = ecdsaRecover $ inputData `B.append` B.replicate 128 0 --need to right pad with zeros to get the full value if the input isn't large enough....  Since extra bytes will be cut off, it doesn't hurt to just add this everywhere
   in (gECRECOVER, ret)
callPrecompiledContract SHA256 inputData = do
  let gas = gSHA256BASE + gSHA256WORD * (ceiling $ fromIntegral (B.length inputData) / (32 :: Double))
   in (gas, sha2 inputData)
callPrecompiledContract RIPEMD160 inputData = do
  let gas =
        gRIPEMD160BASE
          + gRIPEMD160WORD * (ceiling $ fromIntegral (B.length inputData) / (32 :: Double))
   in (gas, ripemd inputData)
callPrecompiledContract IdentityContract inputData = do
  let gas =
        gIDENTITYBASE
          + gIDENTITYWORD * (ceiling $ fromIntegral (B.length inputData) / (32 :: Double))
   in (gas, inputData)
callPrecompiledContract ModExp inputData =
  let gas = gECRECOVER -- ignore gas calc for now; use unrelated constant
   in (gas, modExp inputData)