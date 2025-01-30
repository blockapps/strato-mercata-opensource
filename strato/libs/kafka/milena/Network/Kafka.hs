{-# OPTIONS -fno-warn-deprecations #-}
{-# OPTIONS -fno-warn-orphans      #-}
{-# LANGUAGE FlexibleInstances     #-}

module Network.Kafka where

-- base
import Control.Concurrent (threadDelay)
import Control.Exception (Exception, IOException)
-- Hackage
import Control.Exception.Lifted (catch)
import Control.Lens
import Control.Monad.Except (ExceptT (..), MonadError (..), runExceptT)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.State.Class (MonadState)
import Control.Monad.Trans.Control 
import Control.Monad.Trans.State
import Data.ByteString.Char8 (ByteString)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NE
import qualified Data.Map as M
import qualified Data.Pool as Pool
import Data.Set (Set)
import qualified Data.Set as Set
import qualified DeprecatedNetworkFunction
import GHC.Generics (Generic)

-- local
import Network.Kafka.Protocol
import System.IO
import Prelude

type KafkaAddress = (Host, Port)

data KafkaState = KafkaState
  { -- | Name to use as a client ID.
    _stateName :: KafkaString,
    -- | How many acknowledgements are required for producing.
    _stateRequiredAcks :: RequiredAcks,
    -- | Time in milliseconds to wait for messages to be produced by broker.
    _stateRequestTimeout :: Timeout,
    -- | Minimum size of response bytes to block for.
    _stateWaitSize :: MinBytes,
    -- | Maximum size of response bytes to retrieve.
    _stateBufferSize :: MaxBytes,
    -- | Maximum time in milliseconds to wait for response.
    _stateWaitTime :: MaxWaitTime,
    -- | An incrementing counter of requests.
    _stateCorrelationId :: CorrelationId,
    -- | Broker cache
    _stateBrokers :: M.Map Leader Broker,
    -- | Connection cache
    _stateConnections :: M.Map KafkaAddress (Pool.Pool Handle),
    -- | Topic metadata cache
    _stateTopicMetadata :: M.Map TopicName TopicMetadata,
    -- | Address cache
    _stateAddresses :: NonEmpty KafkaAddress
  }
  deriving (Generic)

makeLenses ''KafkaState


instance Show (Pool.Pool Handle) where
  show _ = "Pool Handle"

instance Show KafkaState where
  show s =
    "KafkaState {"
      ++ "\n\tstateName = "
      ++ show (s ^. stateName)
      ++ "\n\tstateRequiredAcks = "
      ++ show (s ^. stateRequiredAcks)
      ++ "\n\tstateRequestTimeout = "
      ++ show (s ^. stateRequestTimeout)
      ++ "\n\tstateWaitSize = "
      ++ show (s ^. stateWaitSize)
      ++ "\n\tstateBufferSize = "
      ++ show (s ^. stateBufferSize)
      ++ "\n\tstateWaitTime = "
      ++ show (s ^. stateWaitTime)
      ++ "\n\tstateCorrelationId = "
      ++ show (s ^. stateCorrelationId)
      ++ "\n\tstateBrokers = "
      ++ show (s ^. stateBrokers)
      ++ "\n\tstateConnections = "
      ++ show (s ^. stateConnections)
      ++ "\n\tstateTopicMetadata = "
      ++ show (s ^. stateTopicMetadata)
      ++ "\n\tstateAddresses = "
      ++ show (s ^. stateAddresses)
      ++ "\n}"

-- | The core Kafka monad.
type Kafka m = (MonadState KafkaState m, MonadError KafkaClientError m, MonadIO m, MonadBaseControl IO m)

type KafkaClientId = KafkaString

-- | Errors given from the Kafka monad.
data KafkaClientError
  = -- | A response did not contain an offset.
    KafkaNoOffset
  | -- | A value could not be deserialized correctly.
    KafkaDeserializationError String -- TODO: cereal is Stringly typed, should use tickle
  | -- | Could not find a cached broker for the found leader.
    KafkaInvalidBroker Leader
  | KafkaFailedToFetchMetadata
  | KafkaFailedToFetchGroupCoordinator KafkaError
  | KafkaIOException IOException
  deriving (Eq, Generic, Show)

instance Exception KafkaClientError

-- | An abstract form of Kafka's time. Used for querying offsets.
data KafkaTime
  = -- | The latest time on the broker.
    LatestTime
  | -- | The earliest time on the broker.
    EarliestTime
  | -- | A specific time.
    OtherTime Time
  deriving (Eq, Generic)

data PartitionAndLeader = PartitionAndLeader
  { _palTopic :: TopicName,
    _palPartition :: Partition,
    _palLeader :: Leader
  }
  deriving (Show, Generic, Eq, Ord)

makeLenses ''PartitionAndLeader

data TopicAndPartition = TopicAndPartition
  { _tapTopic :: TopicName,
    _tapPartition :: Partition
  }
  deriving (Eq, Generic, Ord, Show)

-- | A topic with a serializable message.
data TopicAndMessage = TopicAndMessage
  { _tamTopic :: TopicName,
    _tamMessage :: Message
  }
  deriving (Eq, Generic, Show)

makeLenses ''TopicAndMessage

-- | Get the bytes from the Kafka message, ignoring the topic.
tamPayload :: TopicAndMessage -> ByteString
tamPayload = foldOf (tamMessage . payload)

-- * Configuration

-- | Default: @0@
defaultCorrelationId :: CorrelationId
defaultCorrelationId = 0

-- | Default: @1@
defaultRequiredAcks :: RequiredAcks
defaultRequiredAcks = 1

-- | Default: @10000@
defaultRequestTimeout :: Timeout
defaultRequestTimeout = 10000

-- | Default: @0@
defaultMinBytes :: MinBytes
defaultMinBytes = MinBytes 0

-- | Default: @32 * 1024 * 1024@
defaultMaxBytes :: MaxBytes
defaultMaxBytes = 32 * 1024 * 1024

-- | Default: @0@
defaultMaxWaitTime :: MaxWaitTime
defaultMaxWaitTime = 0

-- | Create a consumer using default values.
mkKafkaState :: KafkaClientId -> KafkaAddress -> KafkaState
mkKafkaState cid addy =
  KafkaState
    cid
    defaultRequiredAcks
    defaultRequestTimeout
    defaultMinBytes
    defaultMaxBytes
    defaultMaxWaitTime
    defaultCorrelationId
    M.empty
    M.empty
    M.empty
    (addy :| [])

addKafkaAddress :: KafkaAddress -> KafkaState -> KafkaState
addKafkaAddress = over stateAddresses . NE.nub .: NE.cons
  where
    infixr 9 .:
    (.:) :: (c -> d) -> (a -> b -> c) -> a -> b -> d
    (.:) = (.) . (.)

-- | Run the underlying Kafka monad.
runKafka :: KafkaState -> StateT KafkaState (ExceptT KafkaClientError IO) a -> IO (Either KafkaClientError a)
runKafka s k = runExceptT $ evalStateT k s

-- | Catch 'IOException's and wrap them in 'KafkaIOException's.
tryKafka :: Kafka m => m a -> m a
tryKafka = (`catch` \e -> throwError $ KafkaIOException (e :: IOException))

-- | Make a request, incrementing the `_stateCorrelationId`.
makeRequest :: Kafka m => Handle -> ReqResp (m a) -> m a
makeRequest h reqresp = do
  (clientId, correlationId) <- makeIds
  eitherResp <- tryKafka $ doRequest clientId correlationId h reqresp
  case eitherResp of
    Left s -> throwError $ KafkaDeserializationError s
    Right r -> return r
  where
    makeIds :: MonadState KafkaState m => m (ClientId, CorrelationId)
    makeIds = do
      corid <- use stateCorrelationId
      stateCorrelationId += 1
      conid <- use stateName
      return (ClientId conid, corid)

-- | Send a metadata request to any broker.
metadata :: Kafka m => MetadataRequest -> m MetadataResponse
metadata request = withAnyHandle $ flip metadata' request

-- | Send a metadata request.
metadata' :: Kafka m => Handle -> MetadataRequest -> m MetadataResponse
metadata' h request = makeRequest h $ MetadataRR request

createTopic :: Kafka m => CreateTopicsRequest -> m CreateTopicsResponse
createTopic request = withAnyHandle $ flip createTopic' request

createTopic' ::
  Kafka m => Handle -> CreateTopicsRequest -> m CreateTopicsResponse
createTopic' h request = makeRequest h $ TopicsRR request

createTopicsRequest ::
  TopicName ->
  Partition ->
  ReplicationFactor ->
  [(Partition, Replicas)] ->
  [(KafkaString, Metadata)] ->
  CreateTopicsRequest
createTopicsRequest topic partition replication_factor replica_assignment config =
  CreateTopicsReq
    ([(topic, partition, replication_factor, replica_assignment, config)], defaultRequestTimeout)

deleteTopic :: Kafka m => DeleteTopicsRequest -> m DeleteTopicsResponse
deleteTopic request = withAnyHandle $ flip deleteTopic' request

deleteTopic' :: Kafka m => Handle -> DeleteTopicsRequest -> m DeleteTopicsResponse
deleteTopic' h request = makeRequest h $ DeleteTopicsRR request

deleteTopicsRequest :: TopicName -> DeleteTopicsRequest
deleteTopicsRequest topic = DeleteTopicsReq ([topic], defaultRequestTimeout)

fetchOffset :: Kafka m => OffsetFetchRequest -> m OffsetFetchResponse
fetchOffset request@(OffsetFetchReq (group, _)) = do
  coordinator <- getConsumerGroupCoordinator group
  withBrokerHandle coordinator $ flip fetchOffset' request

fetchOffset' :: Kafka m => Handle -> OffsetFetchRequest -> m OffsetFetchResponse
fetchOffset' h request = makeRequest h $ OffsetFetchRR request

fetchOffsetRequest ::
  ConsumerGroup -> TopicName -> Partition -> OffsetFetchRequest
fetchOffsetRequest consumerGroup topic partition =
  OffsetFetchReq
    (consumerGroup, [(topic, [partition])])

-- | Send a heartbeat request.
heartbeat :: Kafka m => HeartbeatRequest -> m HeartbeatResponse
heartbeat request = withAnyHandle $ flip heartbeat' request

heartbeat' :: Kafka m => Handle -> HeartbeatRequest -> m HeartbeatResponse
heartbeat' h request = makeRequest h $ HeartbeatRR request

-- | Create a heartbeat request.
heartbeatRequest :: GroupId -> GenerationId -> MemberId -> HeartbeatRequest
heartbeatRequest genId gId memId = HeartbeatReq (genId, gId, memId)

commitOffset :: Kafka m => OffsetCommitRequest -> m OffsetCommitResponse
commitOffset request@(OffsetCommitReq (group, _, _, _, _)) = do
  coordinator <- getConsumerGroupCoordinator group
  withBrokerHandle coordinator $ flip commitOffset' request

commitOffset' ::
  Kafka m => Handle -> OffsetCommitRequest -> m OffsetCommitResponse
commitOffset' h request = makeRequest h $ OffsetCommitRR request

commitOffsetRequest ::
  ConsumerGroup -> TopicName -> Partition -> Offset -> OffsetCommitRequest
commitOffsetRequest consumerGroup topic partition offset =
  let time = -1
      metadata_ = Metadata "milena"
   in OffsetCommitReq
        (consumerGroup, -1, "", time, [(topic, [(partition, offset, metadata_)])])

getConsumerGroupCoordinator :: Kafka m => ConsumerGroup -> m Broker
getConsumerGroupCoordinator group = do
  let theReq = GroupCoordinatorRR $ GroupCoordinatorReq group
  (GroupCoordinatorResp (err, broker)) <- withAnyHandle $ flip makeRequest theReq
  case err of
    ConsumerCoordinatorNotAvailableCode -> do
      -- coordinator not ready, must retry with backoff
      liftIO $ threadDelay 100000 -- todo something better than threadDelay?
      getConsumerGroupCoordinator group
    NoError -> return broker
    other -> throwError $ KafkaFailedToFetchGroupCoordinator other

getTopicPartitionLeader :: Kafka m => TopicName -> Partition -> m Broker
getTopicPartitionLeader t p = do
  let s = stateTopicMetadata . at t
  tmd <- findMetadataOrElse [t] s KafkaFailedToFetchMetadata
  leader <- expect KafkaFailedToFetchMetadata (firstOf $ findPartitionMetadata t . (folded . findPartition p) . partitionMetadataLeader) tmd
  use stateBrokers >>= expect (KafkaInvalidBroker leader) (view $ at leader)

expect :: Kafka m => KafkaClientError -> (a -> Maybe b) -> a -> m b
expect e f = maybe (throwError e) return . f

-- | Find a leader and partition for the topic.
brokerPartitionInfo :: Kafka m => TopicName -> m (Set PartitionAndLeader)
brokerPartitionInfo t = do
  let s = stateTopicMetadata . at t
  tmd <- findMetadataOrElse [t] s KafkaFailedToFetchMetadata
  return $ Set.fromList $ pal <$> tmd ^. partitionsMetadata
  where
    pal d = PartitionAndLeader t (d ^. partitionId) (d ^. partitionMetadataLeader)

findMetadataOrElse :: Kafka m => [TopicName] -> Getting (Maybe a) KafkaState (Maybe a) -> KafkaClientError -> m a
findMetadataOrElse ts s err = do
  maybeFound <- use s
  case maybeFound of
    Just x -> return x
    Nothing -> do
      updateMetadatas ts
      maybeFound' <- use s
      case maybeFound' of
        Just x -> return x
        Nothing -> throwError err

-- | Convert an abstract time to a serializable protocol value.
protocolTime :: KafkaTime -> Time
protocolTime LatestTime = Time (-1)
protocolTime EarliestTime = Time (-2)
protocolTime (OtherTime o) = o

updateMetadatas :: Kafka m => [TopicName] -> m ()
updateMetadatas ts = do
  md <- metadata $ MetadataReq ts
  let (brokers, tmds) = (md ^.. metadataResponseBrokers . folded, md ^.. topicsMetadata . folded)
      addresses = map broker2address brokers
  stateAddresses %= NE.nub . NE.fromList . (++ addresses) . NE.toList
  stateBrokers %= \m -> foldr addBroker m brokers
  stateTopicMetadata %= \m -> foldr addTopicMetadata m tmds
  return ()
  where
    addBroker :: Broker -> M.Map Leader Broker -> M.Map Leader Broker
    addBroker b = M.insert (Leader . Just $ b ^. brokerNode . nodeId) b
    addTopicMetadata :: TopicMetadata -> M.Map TopicName TopicMetadata -> M.Map TopicName TopicMetadata
    addTopicMetadata tm = M.insert (tm ^. topicMetadataName) tm

updateMetadata :: Kafka m => TopicName -> m ()
updateMetadata t = updateMetadatas [t]

updateAllMetadata :: Kafka m => m ()
updateAllMetadata = updateMetadatas []

-- | Execute a Kafka action with a 'Handle' for the given 'Broker', updating
-- the connections cache if needed.
--
-- When the action throws an 'IOException', it is caught and returned as a
-- 'KafkaIOException' in the Kafka monad.
--
-- Note that when the given action throws an exception, any state changes will
-- be discarded. This includes both 'IOException's and exceptions thrown by
-- 'throwError' from 'Control.Monad.Except'.
withBrokerHandle :: Kafka m => Broker -> (Handle -> m a) -> m a
withBrokerHandle broker = withAddressHandle (broker2address broker)

-- | Execute a Kafka action with a 'Handle' for the given 'KafkaAddress',
-- updating the connections cache if needed.
--
-- When the action throws an 'IOException', it is caught and returned as a
-- 'KafkaIOException' in the Kafka monad.
--
-- Note that when the given action throws an exception, any state changes will
-- be discarded. This includes both 'IOException's and exceptions thrown by
-- 'throwError' from 'Control.Monad.Except'.
withAddressHandle :: Kafka m => KafkaAddress -> (Handle -> m a) -> m a
withAddressHandle address kafkaAction = do
  conns <- use stateConnections
  let foundPool = conns ^. at address
  pool <- case foundPool of
    Nothing -> do
      newPool <- tryKafka $ liftIO $ mkPool address
      stateConnections .= (at address ?~ newPool $ conns)
      return newPool
    Just p -> return p
  tryKafka $ liftBaseWith (\runInIO -> 
    Pool.withResource pool (\handle -> runInIO (kafkaAction handle))
    ) >>= restoreM

--  tryKafka $ liftBaseWith $ \runInIO -> Pool.withResource pool (runInIO . kafkaAction)
--  tryKafka $ Pool.withResource pool kafkaAction
  where
    mkPool :: KafkaAddress -> IO (Pool.Pool Handle)
    mkPool a = Pool.createPool (createHandle a) hClose 1 10 1
      where
        createHandle (h, p) = DeprecatedNetworkFunction.connectTo (h ^. hostString) (fromIntegral p)

broker2address :: Broker -> KafkaAddress
broker2address broker = (,) (broker ^. brokerHost) (broker ^. brokerPort)

-- | Like 'withAddressHandle', but round-robins the addresses in the 'KafkaState'.
--
-- When the action throws an 'IOException', it is caught and returned as a
-- 'KafkaIOException' in the Kafka monad.
--
-- Note that when the given action throws an exception, any state changes will
-- be discarded. This includes both 'IOException's and exceptions thrown by
-- 'throwError' from 'Control.Monad.Except'.
withAnyHandle :: Kafka m => (Handle -> m a) -> m a
withAnyHandle f = do
  (addy :| _) <- use stateAddresses
  x <- withAddressHandle addy f
  stateAddresses %= rotate
  return x
  where
    rotate :: NonEmpty a -> NonEmpty a
    rotate = NE.fromList . rotate' 1 . NE.toList
    rotate' n xs = zipWith const (drop n (cycle xs)) xs

-- * Offsets

-- | Fields to construct an offset request, per topic and partition.
data PartitionOffsetRequestInfo = PartitionOffsetRequestInfo
  { -- | Time to find an offset for.
    _kafkaTime :: KafkaTime,
    -- | Number of offsets to retrieve.
    _maxNumOffsets :: MaxNumberOfOffsets
  }

-- | Get the first found offset.
getLastOffset :: Kafka m => KafkaTime -> Partition -> TopicName -> m Offset
getLastOffset m p t = do
  broker <- getTopicPartitionLeader t p
  withBrokerHandle broker (\h -> getLastOffset' h m p t)

-- | Get the first found offset.
getLastOffset' :: Kafka m => Handle -> KafkaTime -> Partition -> TopicName -> m Offset
getLastOffset' h m p t = do
  let offsetRR = OffsetRR $ offsetRequest [(TopicAndPartition t p, PartitionOffsetRequestInfo m 1)]
  offsetResponse <- makeRequest h offsetRR
  let maybeResp = firstOf (offsetResponseOffset p) offsetResponse
  maybe (throwError KafkaNoOffset) return maybeResp

-- | Create an offset request.
offsetRequest :: [(TopicAndPartition, PartitionOffsetRequestInfo)] -> OffsetRequest
offsetRequest ts =
  OffsetReq (ReplicaId (-1), M.toList . M.unionsWith (<>) $ fmap f ts)
  where
    f (TopicAndPartition t p, i) = M.singleton t [g p i]
    g p (PartitionOffsetRequestInfo kt mno) = (p, protocolTime kt, mno)
