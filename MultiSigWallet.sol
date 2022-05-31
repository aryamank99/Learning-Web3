// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txID);
    event Approve(address indexed owner, uint indexed txID);
    event Revoke(address indexed owner, uint indexed txID);
    event Execute(uint indexed txID);

    //state variables:
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required; //number of approvals required for transaction to be executed
    uint public contractBalance;

    struct Transaction {
        address to; 
        uint value;
        bytes data;
        bool executed;
    }

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    modifier onlyOwner {
        require(isOwner[msg.sender], "only owners can call this function");
        _;
    }

    modifier txExists(uint _txID) {
        require(_txID < transactions.length, "tx does not exist");
        _;
    }

    modifier notApproved(uint _txID) {
        require(!approved[_txID][msg.sender], "tx already approved");
        _;
    }

    modifier notExecuted(uint _txID) {
        require(!transactions[_txID].executed, "tx already executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "invalid required number of owners");

        //save owners to state 'owners' variable
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            //check owner is not 0 address
            require(owner != address(0), "invalid owner");
            //check owner is unique
            require(!isOwner[owner], "owner is not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required; 
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    //submit function creates new Transaction struct and fills out its properties
    function submit(address _to, uint _value, bytes calldata _data) external onlyOwner {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data, 
            executed: false
        }));

        emit Submit(transactions.length - 1);
    }

    function approve(uint _txID) external onlyOwner txExists(_txID) notApproved(_txID) notExecuted(_txID) {
        approved[_txID][msg.sender] = true;
        emit Approve(msg.sender, _txID);
    }

    //helper function to count number of approvals for a given txID
    function _getApprovalCount(uint _txID) private view returns (uint count){ 
        for(uint i = 0; i < owners.length; i++) {
            if (approved[_txID][owners[i]])
                count += 1;
        }
    }

    function execute(uint _txID) external onlyOwner notExecuted(_txID) txExists(_txID) {
        require(_getApprovalCount(_txID) >= required, "insufficient approvals");
        Transaction storage transaction = transactions[_txID];
        transaction.executed = true;
        //execute tx
        (bool success, ) = transaction.to.call{value: transaction.value} (
            transaction.data
        );
        require(success, "tx failed");
        emit Execute(_txID);
    }

    function revoke(uint _txID) external onlyOwner notExecuted(_txID) txExists(_txID) {
        //check that msg.sender has already approved tx
        require(approved[_txID][msg.sender], "tx not approved");
        approved[_txID][msg.sender] = false;
        emit Revoke(msg.sender, _txID);
    }
}

