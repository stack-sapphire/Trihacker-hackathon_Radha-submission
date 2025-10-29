// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DisasterReliefFund
 * @notice A Multi-Signature contract to hold and transparently disburse aid funds, 
 * requiring a minimum number of confirmations to prevent corruption.
 */
contract DisasterReliefFund {
    // --- STATE VARIABLES ---
    address[] public owners;
    uint256 public required; 
    uint256 public transactionCount; // Total number of aid requests submitted

    // Maps owner address to a boolean indicating ownership status
    mapping(address => bool) public isOwner; 
    
    // Maps transaction index => owner address => confirmation status (true/false)
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    struct Transaction {
        address payable to;     // The recipient (NGO/Victim wallet)
        uint256 value;          // The amount of aid to send
        bool executed;          // True if the transfer has happened
        uint256 numConfirmations; // Current number of confirmations
    }

    // Array to store all submitted aid requests
    Transaction[] public transactions;

    // --- NEW HELPER FUNCTION (For Frontend Reading) ---
    // This allows the frontend to easily determine how many transactions to display.
    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }
    
    // --- EVENTS (For Transparency) ---
    event Deposit(address indexed sender, uint256 amount);
    event Submission(uint256 indexed txIndex, address indexed owner, address indexed to, uint256 value);
    event Confirmation(address indexed owner, uint256 indexed txIndex);
    event Execution(uint256 indexed txIndex);

    // --- MODIFIERS ---
    modifier onlyOwners() {
        require(isOwner[msg.sender], "Not an owner (Access Denied)");
        _;
    }

    // CONSTRUCTOR
    // Sets the list of officials (owners) and the number of required signatures (required).
    constructor(address[] memory _owners, uint256 _required) payable {
        require(_owners.length > 0, "Owners list cannot be empty");
        require(_required > 0 && _required <= _owners.length, "Invalid required confirmation count");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Zero address cannot be an owner");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        required = _required;
    }

    // FALLBACK FUNCTION (Receives Ether donations)
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // --- CORE FUNCTIONS ---
    
    /**
     * @notice Submits a new transaction (aid request) to the contract.
     * @param _to The address to send the aid money to.
     * @param _value The amount of Ether to send.
     */
    function submitTransaction(
        address payable _to,
        uint256 _value
    ) public onlyOwners returns (uint256 txIndex) {
        require(_value <= address(this).balance, "Insufficient funds in contract");

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                executed: false,
                numConfirmations: 0
            })
        );
        txIndex = transactions.length - 1;

        emit Submission(txIndex, msg.sender, _to, _value);
        confirmTransaction(txIndex); // Auto-confirm by the submitter

        return txIndex;
    }

    /**
     * @notice Confirms a pending transaction (votes to approve aid).
     * @param _txIndex The index of the transaction in the `transactions` array.
     */
    function confirmTransaction(
        uint256 _txIndex
    ) public onlyOwners {
        require(_txIndex < transactions.length, "Transaction does not exist");
        Transaction storage transaction = transactions[_txIndex];
        require(!transaction.executed, "Transaction already executed");
        require(!isConfirmed[_txIndex][msg.sender], "Transaction already confirmed by this account");
        
        // Record the confirmation
        isConfirmed[_txIndex][msg.sender] = true;
        transaction.numConfirmations += 1;

        emit Confirmation(msg.sender, _txIndex);

        // Anti-Corruption Logic: Auto-execute if quorum is met
        if (transaction.numConfirmations >= required) {
            executeTransaction(_txIndex);
        }
    }
    
    /**
     * @notice Executes the transaction, sending funds to the recipient.
     * @param _txIndex The index of the transaction in the `transactions` array.
     */
    function executeTransaction(
        uint256 _txIndex
    ) public onlyOwners {
        require(_txIndex < transactions.length, "Transaction does not exist");
        Transaction storage transaction = transactions[_txIndex];
        require(!transaction.executed, "Transaction already executed");

        // FINAL CHECK: Ensure Quorum is reached (required confirmations met)
        require(transaction.numConfirmations >= required, "Cannot execute: Quorum not yet reached");

        transaction.executed = true; // Prevents re-execution
        
        // Send the ETH to the recipient (the key action)
        (bool success, ) = transaction.to.call{value: transaction.value}("");
        require(success, "Transaction failed to send Ether");

        emit Execution(_txIndex);
    }
}