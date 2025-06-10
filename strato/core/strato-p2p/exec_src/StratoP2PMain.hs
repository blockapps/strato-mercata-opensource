{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE OverloadedStrings     #-}

import           System.Environment
import           Data.Maybe
import           Control.Monad.IO.Class
import           Control.Concurrent.Async.Lifted.Safe
import           Blockchain.VMOptions       ()

import           HFlags

import           Network.Wai.Handler.Warp
import           Network.Wai.Middleware.Prometheus

import           Blockchain.EthConf
import           Blockchain.Context
import           Blockchain.Options
import           Blockchain.Strato.Model.Options()
import           Blockchain.Participation (p2pApp, setParticipationMode)
import           Blockchain.SeqEventNotify
import           Blockchain.Strato.Discovery.Data.Peer (resetPeers)
import           Blockchain.Strato.Discovery.Data.PeerIOWiring ()
import           Blockchain.Threads
import           Executable.StratoP2P
import           BlockApps.Init
import           BlockApps.Logging as BL
import           Data.IORef
import           Data.Set.Ordered (empty)
import           Instrumentation

main :: IO ()
main = runLoggingT initP2P

initP2P :: LoggingT IO ()
initP2P = labelTheThread "initP2P" $ do
  liftIO $ maybe (return ()) setEthConfFrom . listToMaybe =<< getArgs
  liftIO $ blockappsInit "strato_p2p"
  liftIO $ runInstrumentation "strato-p2p"
  liftIO $ resetPeers
  _ <- liftIO $ $initHFlags "Strato P2P"
  setParticipationMode flags_participationMode
  wireMessagesRef <- liftIO $ newIORef empty
  cfg <- initConfig wireMessagesRef flags_maxReturnedHeaders
  let sSource = seqEventNotificationSource . contextKafkaState
      runner f = do
        c' <- initContext
        ctx <- liftIO $ newIORef c'
        let cfg' = cfg { configContext = ctx }
        runContextM cfg' . f $ sSource c'
  liftIO $
    race_
      (run 10248 $ prometheus def p2pApp)
      (runLoggingT $ stratoP2P runner)
