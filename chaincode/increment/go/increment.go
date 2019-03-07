package main

import (
	"fmt"
	"strconv"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	"github.com/hyperledger/fabric/protos/peer"
)

type IncrementContract struct {
}

func (t *IncrementContract) Init(stub shim.ChaincodeStubInterface) peer.Response {
	count, _ := stub.GetState("count")
	if count == nil {
		_ = stub.PutState("count", []byte(fmt.Sprintf("%d", 0)))
	}
	fmt.Printf("The contract was called %d times", count)

	return shim.Success(nil)
}

func (t *IncrementContract) Invoke(stub shim.ChaincodeStubInterface) peer.Response {
	fn, args := stub.GetFunctionAndParameters()

	var result string
	var err error
	if fn == "plus" {
		result, err = plus(stub, args)
	} else {
		result, err = get(stub, args)
	}

	if err != nil {
		return shim.Error(err.Error())
	}

	return shim.Success([]byte(result))
}

func plus(stub shim.ChaincodeStubInterface, args []string) (string, error) {
	count, err := stub.GetState("count")
	if err != nil {
		return "", fmt.Errorf("Failed to get count")
	}
	tmp, _ := strconv.Atoi(string(count))
	tmp++
	err = stub.PutState("count", []byte(fmt.Sprintf("%d", tmp)))
	if err != nil {
		return "", fmt.Errorf("Failed to put value")
	}

	return string(tmp), nil
}

func get(stub shim.ChaincodeStubInterface, args []string) (string, error) {
	count, err := stub.GetState("count")
	if err != nil {
		return "", fmt.Errorf("Failed to get count")
	}

	return string(count), nil
}

func main() {
	if err := shim.Start(new(IncrementContract)); err != nil {
		fmt.Printf("Error starting IncrementContract chaincode: %s", err)
	}
}
