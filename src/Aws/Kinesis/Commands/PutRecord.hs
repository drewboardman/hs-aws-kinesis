{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- |
-- Module: Aws.Kinesis.Commands.PutRecord
-- Copyright: Copyright © 2014 AlephCloud Systems, Inc.
-- License: MIT
-- Maintainer: Lars Kuhtz <lars@alephcloud.com>
-- Stability: experimental
--
-- /API Version: 2013-12-02/
--
-- This operation puts a data record into an Amazon Kinesis stream from a
-- producer. This operation must be called to send data from the producer into
-- the Amazon Kinesis stream for real-time ingestion and subsequent processing.
-- The PutRecord operation requires the name of the stream that captures,
-- stores, and transports the data; a partition key; and the data blob itself.
-- The data blob could be a segment from a log file, geographic/location data,
-- website clickstream data, or any other data type.
--
-- The partition key is used to distribute data across shards. Amazon Kinesis
-- segregates the data records that belong to a data stream into multiple
-- shards, using the partition key associated with each data record to
-- determine which shard a given data record belongs to.
--
-- Partition keys are Unicode strings, with a maximum length limit of 256
-- bytes. An MD5 hash function is used to map partition keys to 128-bit integer
-- values and to map associated data records to shards using the hash key
-- ranges of the shards. You can override hashing the partition key to
-- determine the shard by explicitly specifying a hash value using the
-- ExplicitHashKey parameter. For more information, see the Amazon Kinesis
-- Developer Guide.
--
-- PutRecord returns the shard ID of where the data record was placed and the
-- sequence number that was assigned to the data record.
--
-- Sequence numbers generally increase over time. To guarantee strictly
-- increasing ordering, use the SequenceNumberForOrdering parameter. For more
-- information, see the Amazon Kinesis Developer Guide.
--
-- If a PutRecord request cannot be processed because of insufficient
-- provisioned throughput on the shard involved in the request, PutRecord
-- throws ProvisionedThroughputExceededException.
--
-- Data records are accessible for only 24 hours from the time that they are
-- added to an Amazon Kinesis stream.
--
-- <http://docs.aws.amazon.com/kinesis/2013-12-02/APIReference/API_PutRecord.html>
--
module Aws.Kinesis.Commands.PutRecord
( PutRecord(..)
, PutRecordResponse(..)
, PutRecordExceptions(..)
) where

import Aws.Core
import Aws.Kinesis.Types
import Aws.Kinesis.Core

import Control.Applicative

import Data.Aeson
import Data.ByteString as B
import qualified Data.ByteString.Lazy as LB
import qualified Data.ByteString.Base64 as B64
import qualified Data.Text.Encoding as T
import Data.Typeable

putRecordAction :: KinesisAction
putRecordAction = KinesisPutRecord

data PutRecord = PutRecord
    { putRecordData :: !B.ByteString
    -- ^ The data blob to put into the record. The maximum size of the data
    -- blob is 50 kilobytes (KB)

    , putRecordExplicitHashKey :: !(Maybe PartitionHash)
    -- ^ The hash value used to explicitly determine the shard the data record
    -- is assigned to by overriding the partition key hash.
    --
    -- FIXME the specification is rather vague about the precise encoding
    -- of this value. The default is to compute it as an MD5 hash of
    -- the partition key. The API reference describes it as an Int128.
    -- However, it is not clear how the result of the hash function is
    -- encoded (big-endian or small endian, word size?) and how it is
    -- serialized to text, which is the type in the JSON serialization.

    , putRecordPartitionKey :: !PartitionKey
    -- ^ Determines which shard in the stream the data record is assigned to.

    , putRecordSequenceNumberForOrdering :: !(Maybe SequenceNumber)
    -- ^ Guarantees strictly increasing sequence numbers, for puts from the
    -- same client and to the same partition key. Usage: set the
    -- SequenceNumberForOrdering of record n to the sequence number of record
    -- n-1 (as returned in the PutRecordResult when putting record n-1). If
    -- this parameter is not set, records will be coarsely ordered based on
    -- arrival time.

    , putRecordStreamName :: !StreamName
    -- ^ The name of the stream to put the data record into.
    }
    deriving (Show, Read, Eq, Ord, Typeable)

instance ToJSON PutRecord where
    toJSON PutRecord{..} = object
        [ "Data" .= T.decodeUtf8 (B64.encode putRecordData)
        , "ExplicitHashKey" .= putRecordExplicitHashKey
        , "PartitionKey" .= putRecordPartitionKey
        , "SequenceNumberForOrdering" .= putRecordSequenceNumberForOrdering
        , "StreamName" .= putRecordStreamName
        ]

data PutRecordResponse = PutRecordResponse
    { putRecordResSequenceNumber :: !SequenceNumber
    -- ^ The sequence number identifier that was assigned to the put data
    -- record. The sequence number for the record is unique across all records
    -- in the stream. A sequence number is the identifier associated with every
    -- record put into the stream.

    , putRecordResShardId :: !ShardId
    -- ^ The shard ID of the shard where the data record was placed.
    }
    deriving (Show, Read, Eq, Ord, Typeable)

instance FromJSON PutRecordResponse where
    parseJSON = withObject "PutRecordResponse" $ \o -> PutRecordResponse
        <$> o .: "SequenceNumber"
        <*> o .: "ShardId"

instance ResponseConsumer r PutRecordResponse where
    type ResponseMetadata PutRecordResponse = KinesisMetadata
    responseConsumer _ = kinesisResponseConsumer

instance SignQuery PutRecord where
    type ServiceConfiguration PutRecord = KinesisConfiguration
    signQuery cmd = kinesisSignQuery KinesisQuery
        { kinesisQueryAction = putRecordAction
        , kinesisQueryBody = Just $ LB.toStrict $ encode cmd
        }

instance Transaction PutRecord PutRecordResponse

instance AsMemoryResponse PutRecordResponse where
    type MemoryResponse PutRecordResponse = PutRecordResponse
    loadToMemory = return

-- -------------------------------------------------------------------------- --
-- Exceptions
--
-- Currently not used for requests. It's included for future usage
-- and as reference.

data PutRecordExceptions
    = PutRecordInvalidArgumentException
    -- ^ /Code 400/

    | PutRecordProvisionedThroughputExceededException
    -- ^ /Code 400/

    | PutRecordResourceNotFoundException
    -- ^ /Code 400/

    deriving (Show, Read, Eq, Ord, Enum, Bounded, Typeable)
