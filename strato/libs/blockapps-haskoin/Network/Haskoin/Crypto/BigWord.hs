{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleInstances #-}

-- {-# OPTIONS -fno-warn-unused-top-binds #-}
-- {-# OPTIONS -fno-warn-unused-imports #-}

module Network.Haskoin.Crypto.BigWord
  ( Word512,
    Word256,
    Word160,
    Word128,
    --, FieldP
    --, FieldN

    -- Data types
    BigWord (..),
  )
where

import Control.DeepSeq (NFData, rnf)
import Control.Monad (mzero, unless, (<=<))
import Data.Aeson
  ( FromJSON,
    ToJSON,
    Value (String),
    parseJSON,
    toJSON,
    withText,
  )
import Data.Binary (Binary, get, put)
import Data.Binary.Get
  ( Get,
    getByteString,
    getWord32be,
    getWord64be,
    getWord8,
  )
import Data.Binary.Put
  ( putByteString,
    putWord32be,
    putWord64be,
    putWord8,
  )
import Data.Bits (Bits (..), FiniteBits (..))
import qualified Data.ByteString as BS (head, length, reverse)
import Data.Data (Data (..))
import Data.Hashable (Hashable)
import Data.Ratio (denominator, numerator)
import qualified Data.Text as T (pack, unpack)
import Data.Typeable (Typeable)
import GHC.Generics (Generic)
import Network.Haskoin.Crypto.Curve
import Network.Haskoin.Crypto.NumberTheory
import Network.Haskoin.Util
import Test.QuickCheck
  ( Arbitrary,
    arbitrary,
    arbitrarySizedBoundedIntegral,
  )
import Text.Printf
import Text.Read (Read (..))

-- | Type representing a transaction hash.
type TxHash = BigWord Mod256Tx

-- | Type representing a block hash.
type BlockHash = BigWord Mod256Block

-- | Data type representing a 512 bit unsigned integer.
-- It is implemented as an Integer modulo 2^512.
type Word512 = BigWord Mod512

-- | Data type representing a 256 bit unsigned integer.
-- It is implemented as an Integer modulo 2^256.
type Word256 = BigWord Mod256

-- | Data type representing a 160 bit unsigned integer.
-- It is implemented as an Integer modulo 2^160.
type Word160 = BigWord Mod160

-- | Data type representing a 128 bit unsigned integer.
-- It is implemented as an Integer modulo 2^128.
type Word128 = BigWord Mod128

-- | Data type representing an Integer modulo coordinate field order P.
type FieldP = BigWord ModP

-- | Data type representing an Integer modulo curve order N.
type FieldN = BigWord ModN

data Mod512 deriving (Data, Typeable)

data Mod256 deriving (Data, Typeable)

data Mod256Tx deriving (Data, Typeable)

data Mod256Block deriving (Data, Typeable)

data Mod160 deriving (Data, Typeable)

data Mod128 deriving (Data, Typeable)

data ModP deriving (Data, Typeable)

data ModN deriving (Data, Typeable)

newtype BigWord n = BigWord {getBigWordInteger :: Integer}
  deriving (Eq, Ord, Data, Typeable, Generic, Hashable)

instance Show (BigWord n) where
  show (BigWord n) = show n

instance Read (BigWord n) where
  readPrec = BigWord <$> readPrec

instance NFData (BigWord n) where
  rnf (BigWord n) = rnf n

instance PrintfArg (BigWord n) where
  formatArg (BigWord n) = formatArg n

inverseP :: FieldP -> FieldP
inverseP (BigWord i) = fromInteger $ mulInverse i curveP

inverseN :: FieldN -> FieldN
inverseN (BigWord i) = fromInteger $ mulInverse i curveN

class BigWordMod a where
  rFromInteger :: Integer -> BigWord a
  rBitSize :: BigWord a -> Int

instance BigWordMod Mod512 where
  rFromInteger i = BigWord $ i `mod` 2 ^ (512 :: Int)
  rBitSize _ = 512

instance BigWordMod Mod256 where
  rFromInteger i = BigWord $ i `mod` 2 ^ (256 :: Int)
  rBitSize _ = 256

instance BigWordMod Mod256Tx where
  rFromInteger i = BigWord $ i `mod` 2 ^ (256 :: Int)
  rBitSize _ = 256

instance BigWordMod Mod256Block where
  rFromInteger i = BigWord $ i `mod` 2 ^ (256 :: Int)
  rBitSize _ = 256

instance BigWordMod Mod160 where
  rFromInteger i = BigWord $ i `mod` 2 ^ (160 :: Int)
  rBitSize _ = 160

instance BigWordMod Mod128 where
  rFromInteger i = BigWord $ i `mod` 2 ^ (128 :: Int)
  rBitSize _ = 128

instance BigWordMod ModP where
  rFromInteger i = BigWord $ i `mod` curveP
  rBitSize _ = 256

instance BigWordMod ModN where
  rFromInteger i = BigWord $ i `mod` curveN
  rBitSize _ = 256

instance BigWordMod n => Num (BigWord n) where
  fromInteger = rFromInteger
  (BigWord i1) + (BigWord i2) = fromInteger $ i1 + i2
  (BigWord i1) * (BigWord i2) = fromInteger $ i1 * i2
  negate (BigWord i) = fromInteger $ negate i
  abs r = r
  signum (BigWord i) = fromInteger $ signum i

instance BigWordMod n => Bits (BigWord n) where
  (BigWord i1) .&. (BigWord i2) = fromInteger $ i1 .&. i2
  (BigWord i1) .|. (BigWord i2) = fromInteger $ i1 .|. i2
  (BigWord i1) `xor` (BigWord i2) = fromInteger $ i1 `xor` i2
  complement (BigWord i) = fromInteger $ complement i
  bitSizeMaybe = Just . rBitSize
  bitSize = rBitSize
  shift (BigWord i) j = fromInteger $ shift i j
  testBit (BigWord i) = testBit i
  bit n = fromInteger $ bit n
  popCount (BigWord i) = popCount i
  isSigned _ = False
  rotate x i = shift x i' .|. shift x (i' - rBitSize x)
    where
      i' = i `mod` rBitSize x

instance BigWordMod n => FiniteBits (BigWord n) where
  finiteBitSize = rBitSize

instance BigWordMod n => Bounded (BigWord n) where
  minBound = fromInteger 0
  maxBound = fromInteger (-1)

instance BigWordMod n => Real (BigWord n) where
  toRational (BigWord i) = toRational i

instance BigWordMod n => Enum (BigWord n) where
  succ r@(BigWord i)
    | r == maxBound = error "BigWord: tried to take succ of maxBound"
    | otherwise = fromInteger $ succ i
  pred r@(BigWord i)
    | r == minBound = error "BigWord: tried to take pred of minBound"
    | otherwise = fromInteger $ pred i
  toEnum i
    | toInteger i >= toInteger (minFrom r)
        && toInteger i <= toInteger (maxFrom r) =
      r
    | otherwise = error "BigWord: toEnum is outside of bounds"
    where
      r = fromInteger $ toEnum i
      minFrom :: BigWordMod a => BigWord a -> BigWord a
      minFrom _ = minBound
      maxFrom :: BigWordMod a => BigWord a -> BigWord a
      maxFrom _ = maxBound
  fromEnum (BigWord i) = fromEnum i

instance BigWordMod n => Integral (BigWord n) where
  (BigWord i1) `quot` (BigWord i2) = fromInteger $ i1 `quot` i2
  (BigWord i1) `rem` (BigWord i2) = fromInteger $ i1 `rem` i2
  (BigWord i1) `div` (BigWord i2) = fromInteger $ i1 `div` i2
  (BigWord i1) `mod` (BigWord i2) = fromInteger $ i1 `mod` i2
  (BigWord i1) `quotRem` (BigWord i2) = (fromInteger a, fromInteger b)
    where
      (a, b) = i1 `quotRem` i2
  (BigWord i1) `divMod` (BigWord i2) = (fromInteger a, fromInteger b)
    where
      (a, b) = i1 `divMod` i2
  toInteger (BigWord i) = i

{- Fractional is only defined for prime orders -}

instance Fractional (BigWord ModP) where
  recip = inverseP
  fromRational r = fromInteger (numerator r) / fromInteger (denominator r)

instance Fractional (BigWord ModN) where
  recip = inverseN
  fromRational r = fromInteger (numerator r) / fromInteger (denominator r)

{- Binary instances for serialization / deserialization -}

instance Binary (BigWord Mod512) where
  get = do
    a <- fromIntegral <$> (get :: Get Word256)
    b <- fromIntegral <$> (get :: Get Word256)
    return $ (a `shiftL` 256) + b

  put (BigWord i) = do
    put $ (fromIntegral (i `shiftR` 256) :: Word256)
    put $ (fromIntegral i :: Word256)

instance Binary (BigWord Mod256) where
  get = do
    a <- fromIntegral <$> getWord64be
    b <- fromIntegral <$> getWord64be
    c <- fromIntegral <$> getWord64be
    d <- fromIntegral <$> getWord64be
    return $ (a `shiftL` 192) + (b `shiftL` 128) + (c `shiftL` 64) + d

  put (BigWord i) = do
    putWord64be $ fromIntegral (i `shiftR` 192)
    putWord64be $ fromIntegral (i `shiftR` 128)
    putWord64be $ fromIntegral (i `shiftR` 64)
    putWord64be $ fromIntegral i

instance Binary (BigWord Mod256Tx) where
  get = do
    a <- fromIntegral <$> getWord64be
    b <- fromIntegral <$> getWord64be
    c <- fromIntegral <$> getWord64be
    d <- fromIntegral <$> getWord64be
    return $ (a `shiftL` 192) + (b `shiftL` 128) + (c `shiftL` 64) + d

  put (BigWord i) = do
    putWord64be $ fromIntegral (i `shiftR` 192)
    putWord64be $ fromIntegral (i `shiftR` 128)
    putWord64be $ fromIntegral (i `shiftR` 64)
    putWord64be $ fromIntegral i

instance Binary (BigWord Mod256Block) where
  get = do
    a <- fromIntegral <$> getWord64be
    b <- fromIntegral <$> getWord64be
    c <- fromIntegral <$> getWord64be
    d <- fromIntegral <$> getWord64be
    return $ (a `shiftL` 192) + (b `shiftL` 128) + (c `shiftL` 64) + d

  put (BigWord i) = do
    putWord64be $ fromIntegral (i `shiftR` 192)
    putWord64be $ fromIntegral (i `shiftR` 128)
    putWord64be $ fromIntegral (i `shiftR` 64)
    putWord64be $ fromIntegral i

instance Binary (BigWord Mod160) where
  get = do
    a <- fromIntegral <$> getWord32be
    b <- fromIntegral <$> getWord64be
    c <- fromIntegral <$> getWord64be
    return $ (a `shiftL` 128) + (b `shiftL` 64) + c

  put (BigWord i) = do
    putWord32be $ fromIntegral (i `shiftR` 128)
    putWord64be $ fromIntegral (i `shiftR` 64)
    putWord64be $ fromIntegral i

instance Binary (BigWord Mod128) where
  get = do
    a <- fromIntegral <$> getWord64be
    b <- fromIntegral <$> getWord64be
    return $ (a `shiftL` 64) + b

  put (BigWord i) = do
    putWord64be $ fromIntegral (i `shiftR` 64)
    putWord64be $ fromIntegral i

-- DER encoding of a FieldN element as Integer
-- http://www.itu.int/ITU-T/studygroups/com17/languages/X.690-0207.pdf
instance Binary (BigWord ModN) where
  get = do
    t <- getWord8
    unless
      (t == 0x02)
      ( fail $
          "Bad DER identifier byte " ++ (show t) ++ ". Expecting 0x02"
      )
    l <- getWord8
    i <- bsToInteger <$> getByteString (fromIntegral l)
    unless (isIntegerValidKey i) $
      fail $
        "Invalid fieldN element: " ++ (show i)
    return $ fromInteger i

  put (BigWord 0) = error "0 is an invalid FieldN element to serialize"
  put (BigWord i) = do
    putWord8 0x02 -- Integer type
    let b = integerToBS i
        l = fromIntegral $ BS.length b
    if BS.head b >= 0x80
      then do
        putWord8 (l + 1)
        putWord8 0x00
      else do
        putWord8 l
    putByteString b

instance Binary (BigWord ModP) where
  -- Section 2.3.6 http://www.secg.org/download/aid-780/sec1-v2.pdf
  get = do
    (BigWord i) <- get :: Get Word256
    unless (i < curveP) (fail $ "Get: Integer not in FieldP: " ++ (show i))
    return $ fromInteger i

  -- Section 2.3.7 http://www.secg.org/download/aid-780/sec1-v2.pdf
  put r = put (fromIntegral r :: Word256)

instance ToJSON (BigWord Mod256Tx) where
  toJSON = String . T.pack . encodeTxHashLE

instance FromJSON (BigWord Mod256Tx) where
  parseJSON =
    withText "TxHash" $
      maybe mzero return . decodeTxHashLE . T.unpack

instance ToJSON (BigWord Mod256Block) where
  toJSON = String . T.pack . encodeBlockHashLE

instance FromJSON (BigWord Mod256Block) where
  parseJSON =
    withText "BlockHash" $
      maybe mzero return . decodeBlockHashLE . T.unpack

instance ToJSON (BigWord Mod256) where
  toJSON = String . T.pack . bsToHex . encode'

instance FromJSON (BigWord Mod256) where
  parseJSON =
    withText "Word256" $
      maybe mzero return . (decodeToMaybe <=< hexToBS) . T.unpack

instance BigWordMod n => Arbitrary (BigWord n) where
  arbitrary = arbitrarySizedBoundedIntegral

isIntegerValidKey :: Integer -> Bool
isIntegerValidKey i = i > 0 && i < curveN

-- | Encodes a 'TxHash' as little endian in HEX format. This is mostly used for
-- displaying transaction ids. Internally, these ids are handled as big endian
-- but are transformed to little endian when displaying them.
encodeTxHashLE :: TxHash -> String
encodeTxHashLE = bsToHex . BS.reverse . encode'

-- | Decodes a little endian 'TxHash' in HEX format.
decodeTxHashLE :: String -> Maybe TxHash
decodeTxHashLE = (decodeToMaybe . BS.reverse =<<) . hexToBS

-- | Encodes a 'BlockHash' as little endian in HEX format. This is mostly used
-- for displaying Block hash ids. Internally, these ids are handled as big
-- endian but are transformed to little endian when displaying them.
encodeBlockHashLE :: BlockHash -> String
encodeBlockHashLE = bsToHex . BS.reverse . encode'

-- | Decodes a little endian 'BlockHash' in HEX format.
decodeBlockHashLE :: String -> Maybe BlockHash
decodeBlockHashLE = (decodeToMaybe . BS.reverse =<<) . hexToBS
