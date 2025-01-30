{-# LANGUAGE TemplateHaskell #-}

module Main where

import Blockchain.GenesisBlockSetup
import HFlags

defineFlag "numAddresses" (100 :: Int) "how many faucet addresses in the genesis block"
$(return []) --see https://github.com/nilcons/hflags/issues/8

main :: IO ()
main = do
  _ <- $initHFlags "Create Hackathon Genesis Block"

  genesisBlockSetup flags_numAddresses
