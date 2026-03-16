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
import Data.Bits (countLeadingZeros)

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

-- Byzantium, EIP-198
modExp :: B.ByteString -> B.ByteString
modExp input = -- parse arguments: base, exp, mod
  let bSize = fromInteger $ byteString2Integer $ B.take 32 input
      eSize = fromInteger $ byteString2Integer $ B.take 32 $ B.drop 32 input
      mSize = fromInteger $ byteString2Integer $ B.take 32 $ B.drop 64 input
      b = byteString2Integer $ B.take bSize $ B.drop 96 input
      e = byteString2Integer $ B.take eSize $ B.drop (96 + bSize) input
      m = byteString2Integer $ B.take mSize $ B.drop (96 + bSize + eSize) input
   in BL.toStrict $ encode $ powMod b e m -- return b**e % m

powMod :: Integer -> Integer -> Integer -> Integer
powMod b e m =
  case (b, e, even e) of
    (0, _, _) -> 0
    (_, 0, _) -> 1
    (_, _, True) ->
      let y = powMod b (e `div` 2) m
        in (y * y) `mod` m
    (_, _, False) ->
      b * (powMod b (e - 1) m) `mod` m

modExpGas :: B.ByteString -> Gas
modExpGas input =
  let bSize = byteString2Integer $ B.take 32 input
      eSize = byteString2Integer $ B.take 32 $ B.drop 32 input
      mSize = byteString2Integer $ B.take 32 $ B.drop 64 input
      eHead = B.take (min (fromInteger eSize) 32) $ B.drop (96 + fromInteger bSize) input
      complexity = multComplexity (max mSize bSize)
      adjustedESize = max (adjustExponentLength eSize eHead) 1
   in Gas $ (complexity * adjustedESize) `div` (getGasValue gQUADDIVISOR)

multComplexity :: Integer -> Integer
multComplexity x =
  if x <= 64 then x*x
  else if x <= 1024 then x*x `div` 4 + 96 * x - 3072
  else x*x `div` 16 + 480 * x - 199680

adjustExponentLength :: Integer -> B.ByteString -> Integer
adjustExponentLength eSize eHead =
  (if eSize > 32 then 8 * (eSize - 32) else 0) +
  case (bitLen eHead) of
    0 -> 0
    x -> toInteger x - 1

bitLen :: B.ByteString -> Int
bitLen input =
  case B.dropWhile (== 0) input of
    rest | B.null rest -> 0
         | otherwise   ->
            let k  = B.length rest
                b  = B.head rest :: Word8
                lz = countLeadingZeros b
            in (k - 1) * 8 + (8 - lz)

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
  (modExpGas inputData, modExp inputData)