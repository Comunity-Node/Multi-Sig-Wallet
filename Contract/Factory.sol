// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MultiSigWallet.sol";  

contract MultiSigWalletFactory {
    address[] public deployedWallets;
        mapping(address => address[]) public walletCreator;

    event WalletCreated(address indexed walletAddress, address[] owners, uint requiredSignatures, address tokenAddress, address creator);

    function createWallet(address[] memory _owners, uint _requiredSignatures, address _tokenAddress) public returns (address) {
        MultiSigWallet newWallet = new MultiSigWallet(_owners, _requiredSignatures, _tokenAddress);
        address walletAddress = address(newWallet);
        
        deployedWallets.push(walletAddress);
        walletCreator[msg.sender].push(walletAddress);  
        
        emit WalletCreated(walletAddress, _owners, _requiredSignatures, _tokenAddress, msg.sender);
        return walletAddress;
    }

    function getWalletsByCreator(address creator) public view returns (address[] memory) {
        return walletCreator[creator];
    }
}
