{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE RecordWildCards #-}

-- |
-- Module      : Crypto.Secp256k1.Internal
-- License     : UNLICENSE
-- Maintainer  : Jean-Pierre Rupp <jprupp@protonmail.ch>
-- Stability   : experimental
-- Portability : POSIX
--
-- The API for this module may change at any time. This is an internal module only
-- exposed for hacking and experimentation.
module Crypto.Secp256k1.Internal where

import Control.DeepSeq
import Control.Monad
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.ByteString.Short (ShortByteString, fromShort, toShort)
import Data.Serialize (Serialize (..))
import qualified Data.Serialize.Get as Get
import qualified Data.Serialize.Put as Put
import Foreign
import Foreign.C
import GHC.Generics (Generic)
import System.Entropy
import System.IO.Unsafe

data Ctx = Ctx

newtype PubKey64 = PubKey64 {getPubKey64 :: ShortByteString}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

newtype Msg32 = Msg32 {getMsg32 :: ShortByteString}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

newtype Sig64 = Sig64 {getSig64 :: ShortByteString}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

data CompactSig = CompactSig
  { getCompactSigR :: !ShortByteString,
    getCompactSigS :: !ShortByteString
  }
  deriving (Show, Eq, Ord, Generic, NFData)

newtype RecSig65 = RecSig65 {getRecSig65 :: ShortByteString}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

#ifdef RECOVERY
data CompactRecSig =
    CompactRecSig
        { getCompactRecSigR :: !ShortByteString
        , getCompactRecSigS :: !ShortByteString
        , getCompactRecSigV :: !Word8
        }
    deriving (Show, Eq, Ord, Generic, NFData)
#endif

newtype Seed32 = Seed32 {getSeed32 :: ShortByteString}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

newtype SecKey32 = SecKey32 {getSecKey32 :: ShortByteString}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

newtype Tweak32 = Tweak32 {getTweak32 :: ShortByteString}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

newtype Nonce32 = Nonce32 {getNonce32 :: ShortByteString}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

newtype Algo16 = Algo16 {getAlgo16 :: ShortByteString}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

newtype CtxFlags = CtxFlags {getCtxFlags :: CUInt}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

newtype SerFlags = SerFlags {getSerFlags :: CUInt}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

newtype Ret = Ret {getRet :: CInt}
  deriving (Read, Show, Eq, Ord, Generic, NFData)

#ifdef SCHNORR
newtype XOnlyPubKey64 = XOnlyPubKey64 { getXOnlyPubKey64 :: ShortByteString }
    deriving (Read, Show, Eq, Ord, Generic, NFData)

newtype SchnorrSig64 = SchnorrSig64 { getSchnorrSig64 :: ShortByteString }
    deriving (Read, Show, Eq, Ord, Generic, NFData)
#endif

-- | Nonce32-generating function
type NonceFunction a =
  Ptr Nonce32 ->
  Ptr Msg32 ->
  Ptr SecKey32 ->
  Ptr Algo16 ->
  -- | extra data
  Ptr a ->
  -- | attempt
  CUInt ->
  Ret

verify :: CtxFlags
verify = CtxFlags 0x0101

sign :: CtxFlags
sign = CtxFlags 0x0201

signVerify :: CtxFlags
signVerify = CtxFlags 0x0301

compressed :: SerFlags
compressed = SerFlags 0x0102

uncompressed :: SerFlags
uncompressed = SerFlags 0x0002

useByteString :: ByteString -> ((Ptr CUChar, CSize) -> IO a) -> IO a
useByteString bs f =
  BS.useAsCStringLen bs $ \(b, l) -> f (castPtr b, fromIntegral l)

packByteString :: (Ptr CUChar, CSize) -> IO ByteString
packByteString (b, l) = BS.packCStringLen (castPtr b, fromIntegral l)

#if SCHNORR
instance Storable XOnlyPubKey64 where
    sizeOf _ = 64
    alignment _ = 1
    peek p = XOnlyPubKey64 . toShort <$> packByteString (castPtr p, 64)
    poke p (XOnlyPubKey64 k) = useByteString (fromShort k) $
        \(b, _) -> copyArray (castPtr p) b 64

instance Storable SchnorrSig64 where
    sizeOf _ = 64
    alignment _ = 1
    peek p = SchnorrSig64 . toShort <$> packByteString (castPtr p, 64)
    poke p (SchnorrSig64 k) = useByteString (fromShort k) $
        \(b, _) -> copyArray (castPtr p) b 64
#endif

instance Storable PubKey64 where
  sizeOf _ = 64
  alignment _ = 1
  peek p = PubKey64 . toShort <$> packByteString (castPtr p, 64)
  poke p (PubKey64 k) = useByteString (fromShort k) $
    \(b, _) -> copyArray (castPtr p) b 64

instance Storable Sig64 where
  sizeOf _ = 64
  alignment _ = 1
  peek p = Sig64 . toShort <$> packByteString (castPtr p, 64)
  poke p (Sig64 k) = useByteString (fromShort k) $
    \(b, _) -> copyArray (castPtr p) b 64

instance Storable CompactSig where
  sizeOf _ = 64
  alignment _ = 1
  peek p = do
    bs <- BS.packCStringLen (castPtr p, 64)
    let (s, r) = BS.splitAt 32 bs
    guard $ BS.length s == 32
    guard $ BS.length r == 32
    return
      CompactSig
        { getCompactSigR = toShort r,
          getCompactSigS = toShort s
        }
  poke p CompactSig {..} =
    useByteString bs $ \(b, _) -> copyArray (castPtr p) b 64
    where
      bs = fromShort getCompactSigS `BS.append` fromShort getCompactSigR

instance Serialize CompactSig where
  get = do
    s <- Get.getByteString 32
    r <- Get.getByteString 32
    return
      CompactSig
        { getCompactSigR = toShort r,
          getCompactSigS = toShort s
        }
  put (CompactSig r s) = do
    Put.putShortByteString s
    Put.putShortByteString r

#ifdef RECOVERY
instance Storable RecSig65 where
    sizeOf _ = 65
    alignment _ = 1
    peek p = RecSig65 . toShort <$> packByteString (castPtr p, 65)
    poke p (RecSig65 k) = useByteString (fromShort k) $
        \(b, _) -> copyArray (castPtr p) b 65

instance Storable CompactRecSig where
    sizeOf _ = 65
    alignment _ = 1
    peek p = do
        bs <- BS.packCStringLen (castPtr p, 65)
        let (s, r) = BS.splitAt 32 $ BS.take 64 bs
            v = BS.last bs
        return CompactRecSig { getCompactRecSigR = toShort r
                             , getCompactRecSigS = toShort s
                             , getCompactRecSigV = v
                             }
    poke p CompactRecSig{..} =
        useByteString bs $ \(b, _) -> copyArray (castPtr p) b 65
      where
        bs = fromShort getCompactRecSigS `BS.append`
             fromShort getCompactRecSigR `BS.snoc`
             getCompactRecSigV

instance Serialize CompactRecSig where
    get = do
        s <- Get.getByteString 32
        r <- Get.getByteString 32
        v <- Get.getWord8
        return CompactRecSig { getCompactRecSigR = toShort r
                             , getCompactRecSigS = toShort s
                             , getCompactRecSigV = v
                             }
    put (CompactRecSig r s v) = do
        Put.putShortByteString s
        Put.putShortByteString r
        Put.putWord8 v
#endif

instance Storable Msg32 where
  sizeOf _ = 32
  alignment _ = 1
  peek p = Msg32 . toShort <$> packByteString (castPtr p, 32)
  poke p (Msg32 k) = useByteString (fromShort k) $
    \(b, _) -> copyArray (castPtr p) b 32

instance Storable Seed32 where
  sizeOf _ = 32
  alignment _ = 1
  peek p = Seed32 . toShort <$> packByteString (castPtr p, 32)
  poke p (Seed32 k) = useByteString (fromShort k) $
    \(b, _) -> copyArray (castPtr p) b 32

instance Storable SecKey32 where
  sizeOf _ = 32
  alignment _ = 1
  peek p = SecKey32 . toShort <$> packByteString (castPtr p, 32)
  poke p (SecKey32 k) = useByteString (fromShort k) $
    \(b, _) -> copyArray (castPtr p) b 32

instance Storable Tweak32 where
  sizeOf _ = 32
  alignment _ = 1
  peek p = Tweak32 . toShort <$> packByteString (castPtr p, 32)
  poke p (Tweak32 k) = useByteString (fromShort k) $
    \(b, _) -> copyArray (castPtr p) b 32

instance Storable Nonce32 where
  sizeOf _ = 32
  alignment _ = 1
  peek p = Nonce32 . toShort <$> packByteString (castPtr p, 32)
  poke p (Nonce32 k) = useByteString (fromShort k) $
    \(b, _) -> copyArray (castPtr p) b 32

instance Storable Algo16 where
  sizeOf _ = 16
  alignment _ = 1
  peek p = Algo16 . toShort <$> packByteString (castPtr p, 16)
  poke p (Algo16 k) = useByteString (fromShort k) $
    \(b, _) -> copyArray (castPtr p) b 16

isSuccess :: Ret -> Bool
isSuccess (Ret 0) = False
isSuccess (Ret 1) = True
isSuccess _ = undefined

{-# NOINLINE fctx #-}
fctx :: ForeignPtr Ctx
fctx = unsafePerformIO $ do
  x <- contextCreate signVerify
  e <- getEntropy 32
  ret <- alloca $ \s -> poke s (Seed32 (toShort e)) >> contextRandomize x s
  unless (isSuccess ret) $ error "failed to randomize context"
  newForeignPtr contextDestroy x

{-# INLINE withContext #-}
withContext :: (Ptr Ctx -> IO a) -> a
withContext f = unsafeDupablePerformIO (withForeignPtr fctx f)

foreign import ccall "secp256k1.h secp256k1_context_create"
  contextCreate ::
    CtxFlags ->
    IO (Ptr Ctx)

foreign import ccall "secp256k1.h secp256k1_context_clone"
  contextClone ::
    Ptr Ctx ->
    IO (Ptr Ctx)

foreign import ccall "secp256k1.h &secp256k1_context_destroy"
  contextDestroy ::
    FunPtr (Ptr Ctx -> IO ())

foreign import ccall "secp256k1.h secp256k1_context_set_illegal_callback"
  setIllegalCallback ::
    Ptr Ctx ->
    -- | message, data
    FunPtr (CString -> Ptr a -> IO ()) ->
    -- | data
    Ptr a ->
    IO ()

foreign import ccall "secp256k1.h secp256k1_context_set_error_callback"
  setErrorCallback ::
    Ptr Ctx ->
    -- | message, data
    FunPtr (CString -> Ptr a -> IO ()) ->
    -- | data
    Ptr a ->
    IO ()

foreign import ccall "secp256k1.h secp256k1_ec_pubkey_parse"
  ecPubKeyParse ::
    Ptr Ctx ->
    Ptr PubKey64 ->
    -- | encoded public key array
    Ptr CUChar ->
    -- | size of encoded public key array
    CSize ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ec_pubkey_serialize"
  ecPubKeySerialize ::
    Ptr Ctx ->
    -- | array for encoded public key, must be large enough
    Ptr CUChar ->
    -- | size of encoded public key, will be updated
    Ptr CSize ->
    Ptr PubKey64 ->
    SerFlags ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ecdsa_signature_parse_compact"
  ecdsaSignatureParseCompact ::
    Ptr Ctx ->
    Ptr Sig64 ->
    Ptr CompactSig ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ecdsa_signature_parse_der"
  ecdsaSignatureParseDer ::
    Ptr Ctx ->
    Ptr Sig64 ->
    -- | encoded DER signature
    Ptr CUChar ->
    -- | size of encoded signature
    CSize ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ecdsa_signature_serialize_der"
  ecdsaSignatureSerializeDer ::
    Ptr Ctx ->
    -- | array for encoded signature, must be large enough
    Ptr CUChar ->
    -- | size of encoded signature, will be updated
    Ptr CSize ->
    Ptr Sig64 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ecdsa_signature_serialize_compact"
  ecdsaSignatureSerializeCompact ::
    Ptr Ctx ->
    Ptr CompactSig ->
    Ptr Sig64 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ecdsa_verify"
  ecdsaVerify ::
    Ptr Ctx ->
    Ptr Sig64 ->
    Ptr Msg32 ->
    Ptr PubKey64 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ecdsa_signature_normalize"
  ecdsaSignatureNormalize ::
    Ptr Ctx ->
    -- | output
    Ptr Sig64 ->
    -- | input
    Ptr Sig64 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ecdsa_sign"
  ecdsaSign ::
    Ptr Ctx ->
    Ptr Sig64 ->
    Ptr Msg32 ->
    Ptr SecKey32 ->
    FunPtr (NonceFunction a) ->
    -- | nonce data
    Ptr a ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ec_seckey_verify"
  ecSecKeyVerify ::
    Ptr Ctx ->
    Ptr SecKey32 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ec_pubkey_create"
  ecPubKeyCreate ::
    Ptr Ctx ->
    Ptr PubKey64 ->
    Ptr SecKey32 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ec_privkey_tweak_add"
  ecSecKeyTweakAdd ::
    Ptr Ctx ->
    Ptr SecKey32 ->
    Ptr Tweak32 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ec_privkey_negate"
  ecTweakNegate ::
    Ptr Ctx ->
    Ptr Tweak32 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ec_pubkey_tweak_add"
  ecPubKeyTweakAdd ::
    Ptr Ctx ->
    Ptr PubKey64 ->
    Ptr Tweak32 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ec_privkey_tweak_mul"
  ecSecKeyTweakMul ::
    Ptr Ctx ->
    Ptr SecKey32 ->
    Ptr Tweak32 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ec_pubkey_tweak_mul"
  ecPubKeyTweakMul ::
    Ptr Ctx ->
    Ptr PubKey64 ->
    Ptr Tweak32 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_context_randomize"
  contextRandomize ::
    Ptr Ctx ->
    Ptr Seed32 ->
    IO Ret

foreign import ccall "secp256k1.h secp256k1_ec_pubkey_combine"
  ecPubKeyCombine ::
    Ptr Ctx ->
    -- | pointer to public key storage
    Ptr PubKey64 ->
    -- | pointer to array of public keys
    Ptr (Ptr PubKey64) ->
    -- | number of public keys
    CInt ->
    IO Ret

#ifdef RECOVERY
foreign import ccall
    "secp256k1_recovery.h secp256k1_ecdsa_recoverable_signature_parse_compact"
    ecdsaRecoverableSignatureParseCompact
    :: Ptr Ctx
    -> Ptr RecSig65
    -> Ptr CompactSig
    -> CInt
    -> IO Ret

foreign import ccall
    "secp256k1_recovery.h secp256k1_ecdsa_recoverable_signature_convert"
    ecdsaRecoverableSignatureConvert
    :: Ptr Ctx
    -> Ptr Sig64
    -> Ptr RecSig65
    -> IO Ret

foreign import ccall
    "secp256k1_recovery.h secp256k1_ecdsa_recoverable_signature_serialize_compact"
    ecdsaRecoverableSignatureSerializeCompact
    :: Ptr Ctx
    -> Ptr CompactSig
    -> Ptr CInt
    -> Ptr RecSig65
    -> IO Ret

foreign import ccall
    "secp256k1_recovery.h secp256k1_ecdsa_sign_recoverable"
    ecdsaSignRecoverable
    :: Ptr Ctx
    -> Ptr RecSig65
    -> Ptr Msg32
    -> Ptr SecKey32
    -> FunPtr (NonceFunction a)
    -> Ptr a -- ^ nonce data
    -> IO Ret

foreign import ccall
    "secp256k1_recovery.h secp256k1_ecdsa_recover"
    ecdsaRecover
    :: Ptr Ctx
    -> Ptr PubKey64
    -> Ptr RecSig65
    -> Ptr Msg32
    -> IO Ret
#endif

#ifdef SCHNORR
foreign import ccall
    "secp256k1.h secp256k1_xonly_pubkey_tweak_add"
    schnorrPubKeyTweakAdd
    :: Ptr Ctx
    -> Ptr XOnlyPubKey64
    -> Ptr CInt
    -> Ptr Tweak32
    -> IO Ret

foreign import ccall
    "secp256k1.h secp256k1_xonly_seckey_tweak_add"
    schnorrSecKeyTweakAdd
    :: Ptr Ctx
    -> Ptr SecKey32
    -> Ptr Tweak32
    -> IO Ret

foreign import ccall
    "secp256k1.h secp256k1_schnorrsig_serialize"
    signatureSerializeSchnorr
    :: Ptr Ctx
    -> Ptr CUChar -- ^ array for encoded signature, must be large enough
    -> Ptr SchnorrSig64
    -> IO Ret

foreign import ccall
    "secp256k1.h secp256k1_schnorrsig_sign"
    schnorrSign
    :: Ptr Ctx
    -> Ptr SchnorrSig64
    -> Ptr Msg32
    -> Ptr SecKey32
    -- TODO
    -- This is actually an "extended nonce function" in the C code. So this signature is broken,
    -- but we pass a nullFunPtr (and this module is Internal), so it doesn't matter right now.
    -> FunPtr (NonceFunction a)
    -> Ptr a -- ^ nonce data
    -> IO Ret

foreign import ccall
    "secp256k1.h secp256k1_xonly_pubkey_tweak_test"
    xOnlyPubKeyTweakTest
    :: Ptr Ctx
    -> Ptr XOnlyPubKey64 -- output_pubkey
    -> CInt -- is_negated
    -> Ptr XOnlyPubKey64 -- internal_pubkey
    -> Ptr Tweak32
    -> IO Ret

foreign import ccall
    "secp256k1.h secp256k1_xonly_pubkey_serialize"
    schnorrPubKeySerialize
    :: Ptr Ctx
    -> Ptr CUChar -- 32 bytes output buffer
    -> Ptr XOnlyPubKey64
    -> IO Ret

foreign import ccall
    "secp256k1.h secp256k1_schnorrsig_verify"
    schnorrSignatureVerify
    :: Ptr Ctx
    -> Ptr SchnorrSig64
    -> Ptr Msg32
    -> Ptr XOnlyPubKey64
    -> IO Ret

foreign import ccall
    "secp256k1.h secp256k1_schnorrsig_parse"
    schnorrSignatureParse
    :: Ptr Ctx
    -> Ptr SchnorrSig64 -- out
    -> Ptr CUChar -- in
    -> IO Ret

foreign import ccall
    "secp256k1.h secp256k1_xonly_pubkey_parse"
    schnorrXOnlyPubKeyParse
    :: Ptr Ctx
    -> Ptr XOnlyPubKey64 -- out
    -> Ptr CUChar -- in
    -> IO Ret

foreign import ccall
    "secp256k1.h secp256k1_xonly_pubkey_create"
    schnorrXOnlyPubKeyCreate
    :: Ptr Ctx
    -> Ptr XOnlyPubKey64
    -> Ptr SecKey32
    -> IO Ret
#endif

#ifdef ECDH
foreign import ccall
    "secp256k1_ecdh.h secp256k1_ecdh"
    ecEcdh
    :: Ptr Ctx
    -> Ptr CUChar
    -> Ptr PubKey64
    -> Ptr SecKey32
    -> Ptr a
    -> Ptr b
    -> IO Ret
#endif
