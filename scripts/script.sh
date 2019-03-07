#!/bin/bash

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Build multi host TESTNET network"
echo
CHANNEL_NAME="$1"
DELAY="$2"
LANGUAGE="$3"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${LANGUAGE:="golang"}
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
COUNTER=1
MAX_RETRY=5

CC_SRC_PATH="github.com/chaincode/increment/go/"
#if [ "$LANGUAGE" = "node" ]; then
#	CC_SRC_PATH="/opt/gopath/src/github.com/chaincode/chaincode_example02/node/"
#fi

#if [ "$LANGUAGE" = "java" ]; then
#	CC_SRC_PATH="/opt/gopath/src/github.com/chaincode/chaincode_example02/java/"
#fi

echo "Channel name : "$CHANNEL_NAME

# import utils
#. scripts/utils.sh

# verify the result of the end-to-end test
verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
    echo
    exit 1
  fi
}

setGlobals () {
	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="Org1MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
		if [ $1 -eq 0 ]; then
			CORE_PEER_ADDRESS=peer0.org1.example.com:7051
		else
			CORE_PEER_ADDRESS=peer1.org1.example.com:7051
		fi
	fi

	env |grep CORE
}

createChannel() {
	setGlobals 0

	peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ../channel-artifacts/channel.tx >&log.txt
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel '$CHANNEL_NAME' created ===================== "
	echo
}

## Sometimes Join takes time hence RETRY at least 5 times
joinChannelWithRetry() {
  peer channel join -b $CHANNEL_NAME.block >&log.txt
  res=$?
  cat log.txt
  if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
    COUNTER=$(expr $COUNTER + 1)
    echo "peer $1 failed to join the channel, Retry after $DELAY seconds"
    sleep $DELAY
    joinChannelWithRetry $1
  else
    COUNTER=1
  fi
  verifyResult $res "After $MAX_RETRY attempts, peer $1 has failed to join channel '$CHANNEL_NAME' "
}

joinChannel () {
	for peer in 0 1; do
        setGlobals $peer
		joinChannelWithRetry $peer
		echo "===================== peer $peer joined channel '$CHANNEL_NAME' ===================== "
		sleep $DELAY
		echo
	done
}

updateAnchorPeers() {
  PEER=$1
  setGlobals $PEER

  peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f ../channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
  res=$?
  cat log.txt
  verifyResult $res "Anchor peer update failed"
  echo "===================== Anchor peers updated for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME' ===================== "
  sleep $DELAY
  echo
}

installChaincode() {
  PEER=$1
  setGlobals $PEER
  VERSION=${3:-1.0}
  peer chaincode install -n cc -v ${VERSION} -l ${LANGUAGE} -p ${CC_SRC_PATH} >&log.txt
  res=$?
  cat log.txt
  verifyResult $res "Chaincode installation on peer${PEER} has failed"
  echo "===================== Chaincode is installed on peer${PEER} ===================== "
  echo
}

instantiateChaincode() {
  PEER=$1
  setGlobals $PEER
  VERSION=${3:-1.0}

  # while 'peer chaincode' command can get the orderer endpoint from the peer
  # (if join was successful), let's supply it directly as we know it using
  # the "-o" option
  peer chaincode instantiate -o orderer.example.com:7050 -C $CHANNEL_NAME -n cc -l ${LANGUAGE} -v ${VERSION} -c '{"Args":[]}' -P "OR ('Org1MSP.peer','Org2MSP.peer')" >&log.txt
  res=$?
  cat log.txt
  verifyResult $res "Chaincode instantiation on peer${PEER} on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode is instantiated on peer${PEER} on channel '$CHANNEL_NAME' ===================== "
  echo
}

## Create channel
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel

## Set the anchor peers for each org in the channel
echo "Updating anchor peers for org1..."
updateAnchorPeers 0 1

## Install chaincode on peer0.org1 and peer1.org1
echo "Installing chaincode on peer0.org1..."
installChaincode 0 1
echo "Install chaincode on peer1.org1..."
installChaincode 1 1

# Instantiate chaincode on peer0.org1
echo "Instantiating chaincode on peer0.org2..."
instantiateChaincode 0 1

# Query chaincode on peer0.org1
#echo "Querying chaincode on peer0.org1..."
#chaincodeQuery 0 1 100

# Invoke chaincode on peer0.org1 and peer0.org2
#echo "Sending invoke transaction on peer0.org1 peer0.org2..."
#chaincodeInvoke 0 1 0 2

## Install chaincode on peer1.org2
#echo "Installing chaincode on peer1.org2..."
#installChaincode 1 2

# Query on chaincode on peer1.org2, check if the result is 90
#echo "Querying chaincode on peer1.org2..."
#chaincodeQuery 1 2 90

echo
echo "========= All GOOD, TESTNET execution completed =========== "
echo

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0
