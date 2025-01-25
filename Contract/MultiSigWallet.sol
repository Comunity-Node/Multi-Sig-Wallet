// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IStakingContract {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function claimRewards() external;
}

contract MultiSigWallet {
    address[] public owners;
    uint public required;
    
    mapping(address => bool) public isOwner;
    mapping(uint => Transaction) public transactions;
    
    uint public transactionCount;
    
    address public tokenAddress; 
    
    struct Transaction {
        address to;
        uint amount;
        bool executed;
        uint approvalCount;
        bool isTokenTransaction;
        bool isStakingTransaction; 
        bool isUnstakingTransaction; 
        bool isClaimRewardTransaction; 
        address tokenAddress; 
        address stakingContractAddress;  
    }
    
    event Deposit(address indexed sender, uint amount);
    event TokenDeposit(address indexed sender, address indexed token, uint amount);
    event TransactionCreated(
        uint indexed transactionId, 
        address indexed to, 
        uint amount, 
        bool isTokenTransaction, 
        bool isStakingTransaction,
        bool isUnstakingTransaction,
        bool isClaimRewardTransaction
    );
    event TransactionExecuted(uint indexed transactionId);
    event TransactionApproved(uint indexed transactionId, address indexed owner);
    
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }
    
    modifier txExists(uint transactionId) {
        require(transactionId < transactionCount, "Transaction does not exist");
        _;
    }
    
    modifier notExecuted(uint transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }
    
    modifier notApproved(uint transactionId) {
        require(!isApproved(transactionId), "Transaction already approved");
        _;
    }
    
    constructor(address[] memory _owners, uint _required, address _tokenAddress) {
        require(_owners.length > 0, "At least one owner required");
        require(_required > 0 && _required <= _owners.length, "Invalid number of required signers");
        
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");
            
            isOwner[owner] = true;
            owners.push(owner);
        }
        
        required = _required;
        tokenAddress = _tokenAddress;
    }
    
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
    
    function createTransaction(
        address _to, 
        uint _amount, 
        bool _isTokenTransaction, 
        bool _isStakingTransaction,
        bool _isUnstakingTransaction,
        bool _isClaimRewardTransaction,
        address _stakingContractAddress
    ) public onlyOwner {
        uint transactionId = transactionCount;
        
        transactions[transactionId] = Transaction({
            to: _to,
            amount: _amount,
            executed: false,
            approvalCount: 0,
            isTokenTransaction: _isTokenTransaction,
            isStakingTransaction: _isStakingTransaction,
            isUnstakingTransaction: _isUnstakingTransaction,
            isClaimRewardTransaction: _isClaimRewardTransaction,
            tokenAddress: tokenAddress,
            stakingContractAddress: _stakingContractAddress
        });
        
        transactionCount++;
        
        emit TransactionCreated(
            transactionId, 
            _to, 
            _amount, 
            _isTokenTransaction, 
            _isStakingTransaction,
            _isUnstakingTransaction,
            _isClaimRewardTransaction
        );
    }
    
    function approveTransaction(uint transactionId) public onlyOwner txExists(transactionId) notExecuted(transactionId) notApproved(transactionId) {
        Transaction storage txn = transactions[transactionId];
        txn.approvalCount++;
        
        emit TransactionApproved(transactionId, msg.sender);
        
        if (txn.approvalCount >= required) {
            executeTransaction(transactionId);
        }
    }
        function executeTransaction(uint transactionId) private txExists(transactionId) notExecuted(transactionId) {
        Transaction storage txn = transactions[transactionId];
        
        require(txn.approvalCount >= required, "Not enough approvals");
        
        txn.executed = true;
        
        if (txn.isStakingTransaction) {
            require(IERC20(txn.tokenAddress).approve(txn.stakingContractAddress, txn.amount), "Token approval for staking failed");
            IStakingContract(txn.stakingContractAddress).stake(txn.amount);
        } else if (txn.isUnstakingTransaction) {
            IStakingContract(txn.stakingContractAddress).unstake(txn.amount);
        } else if (txn.isClaimRewardTransaction) {
            IStakingContract(txn.stakingContractAddress).claimRewards();
        } else if (txn.isTokenTransaction) {
            require(IERC20(txn.tokenAddress).transfer(txn.to, txn.amount), "Token transfer failed");
        } else {
            (bool success, ) = txn.to.call{value: txn.amount}("");
            require(success, "Transaction failed");
        }
        
        emit TransactionExecuted(transactionId);
    }

        function isApproved(uint transactionId) public view returns (bool) {
        return transactions[transactionId].approvalCount > 0;
    }
    
    function getOwners() public view returns (address[] memory) {
        return owners;
    }
    
    function getTransactionCount() public view returns (uint) {
        return transactionCount;
    }
}
