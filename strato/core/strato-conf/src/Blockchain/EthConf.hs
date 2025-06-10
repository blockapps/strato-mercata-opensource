{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

module Blockchain.EthConf
  (
    ethConf,
    setEthConfFrom,
    connStr,
    lookupRedisBlockDBConfig,
    cirrusConnStr,
    runKafkaMConfigured,
    module Blockchain.EthConf.Model,
  )
where

import Blockchain.EthConf.Model
import Control.Monad.Composable.Kafka
import Control.Monad.IO.Class
import Control.Concurrent
import qualified Data.ByteString as B
import Data.String
import Data.Yaml
import qualified Database.Redis as Redis
import System.IO.Unsafe

{- CONFIG: first change, make this local -}

-- noinline cause its not like we had any guarantee of whether or not the file
-- got re-read anyway
{-# NOINLINE ethConf #-}
ethConfMVar :: MVar EthConf
ethConfMVar = unsafePerformIO newEmptyMVar

ethConf :: EthConf
ethConf = unsafePerformIO $ do
  isEmpty <- isEmptyMVar ethConfMVar
  if isEmpty
    then do
    putStrLn "ethConf: Filling with default"
    ethConf_ <- readEthConf ".ethereumH/ethconf.yaml"
    tryPutMVar ethConfMVar ethConf_ >> return ethConf_
    else do
    putStrLn "ethConf: Filled"
    readMVar ethConfMVar

readEthConf :: FilePath -> IO EthConf
readEthConf path_ = do
  contents <- B.readFile path_
  return $ (either (error . show) id . decodeEither') contents

-- | Convenience function to set path to @EthConf@ from command line
-- argmunts returned by @getArgs@.
setEthConfFrom :: FilePath -> IO ()
setEthConfFrom path_ = putMVar ethConfMVar =<< readEthConf path_

{- CONFIG: clobber connection string -}

connStr :: B.ByteString
connStr = postgreSQLConnectionString . sqlConfig $ ethConf

cirrusConnStr :: B.ByteString
cirrusConnStr = postgreSQLConnectionString . cirrusConfig $ ethConf

runKafkaMConfigured :: MonadIO m =>
                       KafkaClientId -> KafkaM m a -> m a
runKafkaMConfigured name =
  let k = kafkaConfig ethConf
  in runKafkaM name (fromString $ kafkaHost k, fromIntegral $ kafkaPort k)

lookupRedisBlockDBConfig :: Redis.ConnectInfo
lookupRedisBlockDBConfig = redisConnection $ redisBlockDBConfig ethConf
