//SPDX-License-Identifier: MIT
//IN BILLIONAIRE WE TRUST

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.0;
    
contract Worker {
    address private immutable executeAddress;

    constructor(address a) {
        executeAddress = a;
    }

    fallback(bytes calldata data) external payable returns(bytes memory) {
        address a = executeAddress;
        assembly { // solium-disable-line
            calldatacopy(0x0, 0x0, calldatasize())
            let success := delegatecall(gas(), a, 0x0, calldatasize(), 0, 0)
            let retSz := returndatasize()
            returndatacopy(0, 0, retSz)
            switch success
            case 0 {
                revert(0, retSz)
            }
            default {
                return(0, retSz)
            }
        }
    }
}

contract MassMinter is Ownable {
    mapping(address => address[]) public workers;
    address public NFT;
    address public executeAddress;
    mapping(address => uint256) public current;

    constructor(address nftAddress) {
        NFT = nftAddress;
    }

    function executeDif(
        address _contract, 
        uint256 _amt, 
        bytes[] calldata _cmd, 
        uint256 _value,
        uint256 _startingWorker
    ) external payable {
        ERC1155 unchainedPass = ERC1155(NFT);
        require(unchainedPass.balanceOf(tx.origin, 0) > 0, "Must own Unchained Pass!");
        require(_startingWorker + _amt <= workers[tx.origin].length, "Not enough workers from starting point");
        
        for (uint i = 0; i < _amt; i++) {
            uint256 workerIndex = _startingWorker + i;
            if (msg.value > 0) {
                Address.sendValue(payable(workers[tx.origin][workerIndex]), msg.value/_amt);
            }

            bytes memory encodedData = abi.encodeWithSignature(
                "execute(address,bytes,uint256)", 
                _contract, 
                _cmd[i], 
                _value
            );
            
            (bool success, ) = workers[tx.origin][workerIndex].call(encodedData);
            if (!success) {
                break;
            }
        }
    }

    function execute(
        address _contract, 
        uint256 _amt, 
        bytes calldata _cmd, 
        uint256 _value,
        uint256 _startingWorker
    ) external payable {
        ERC1155 unchainedPass = ERC1155(NFT);
        require(unchainedPass.balanceOf(tx.origin, 0) > 0, "Must own Unchained Pass!");
        require(_startingWorker + _amt <= workers[tx.origin].length, "Not enough workers from starting point");

        for (uint i = 0; i < _amt; i++) {
            uint256 workerIndex = _startingWorker + i;
            if (msg.value > 0) {
                Address.sendValue(payable(workers[tx.origin][workerIndex]), msg.value/_amt);
            }

            bytes memory encodedData = abi.encodeWithSignature(
                "execute(address,bytes,uint256)", 
                _contract, 
                _cmd, 
                _value
            );
            
            (bool success, ) = workers[tx.origin][workerIndex].call(encodedData);
            if (!success) {
                break;
            }
        }
    }

    function transferERC20(
        address _tokenContract, 
        address _receiver, 
        uint256 _workerCount, 
        uint256 _startingWorker
    ) external {
        ERC1155 unchainedPass = ERC1155(NFT);
        require(unchainedPass.balanceOf(tx.origin, 0) > 0, "Must own Unchained Pass!");
        require(_startingWorker < workers[tx.origin].length, "Invalid starting worker");
        require(_startingWorker + _workerCount <= workers[tx.origin].length, "Not enough workers");

        for (uint i = 0; i < _workerCount; i++) {
            uint256 workerIndex = _startingWorker + i;
            bytes memory encodedData = abi.encodeWithSignature(
                "transferAllERC20(address,address)", 
                _tokenContract, 
                _receiver
            );
            
            (bool success, ) = workers[tx.origin][workerIndex].call(encodedData);
            if (!success) {
                continue;
            }
        }
    }

    function transfer(
        address _contract, 
        uint256[][] calldata _tokenIds,
        uint256 _startingWorker
    ) external {
        require(_startingWorker + _tokenIds.length <= workers[tx.origin].length, "Not enough workers from starting point");

        for (uint i = 0; i < _tokenIds.length; i++) {
            uint256 workerIndex = _startingWorker + i;
            bytes memory encodedData = abi.encodeWithSignature(
                "transfer(address,uint256[])", 
                _contract, 
                _tokenIds[i]
            );
                              
            workers[tx.origin][workerIndex].call(encodedData);
        }
    }

    function transferTwo(
        address _contract, 
        uint256[][] calldata _tokenIds, 
        uint256[][] calldata _tokenAmounts,
        uint256 _startingWorker
    ) external {
        require(_startingWorker + _tokenIds.length <= workers[tx.origin].length, "Not enough workers from starting point");

        for (uint i = 0; i < _tokenIds.length; i++) {
            uint256 workerIndex = _startingWorker + i;
            bytes memory encodedData = abi.encodeWithSignature(
                "transferTwo(address,uint256[],uint256[])", 
                _contract, 
                _tokenIds[i], 
                _tokenAmounts[i]
            );
                              
            workers[tx.origin][workerIndex].call(encodedData);
        }
    }
      
    function distributeMoney(
        uint256 loopAmount, 
        uint256 _startingWorker
    ) external payable {
        ERC1155 unchainedPass = ERC1155(NFT);
        require(unchainedPass.balanceOf(tx.origin, 0) > 0, "Must own Unchained Pass!");
        require(workerSize() > 0, "Must have Workers Deployed!");
        require(_startingWorker + loopAmount <= workers[tx.origin].length, "Not enough workers from starting point");

        for (uint i = 0; i < loopAmount; i++) {
            uint256 workerIndex = _startingWorker + i;
            Address.sendValue(payable(workers[tx.origin][workerIndex]), msg.value/loopAmount);
        }
    }

    function recallMoney(
        uint256 loopAmount,
        uint256 _startingWorker
    ) external {
        ERC1155 unchainedPass = ERC1155(NFT);
        require(unchainedPass.balanceOf(tx.origin, 0) > 0, "Must own Unchained Pass!");
        require(workerSize() > 0, "Must have Workers Deployed!");
        require(_startingWorker + loopAmount <= workers[tx.origin].length, "Not enough workers from starting point");

        for (uint i = 0; i < loopAmount; i++) {
            uint256 workerIndex = _startingWorker + i;
            bytes memory encodedData = abi.encodeWithSignature("recallMoney()");
            address(workers[tx.origin][workerIndex]).call(encodedData);
        }
    }

    function deployNewWorkers(uint256 loopAmount) external {
        ERC1155 unchainedPass = ERC1155(NFT);
        require(unchainedPass.balanceOf(tx.origin, 0) > 0, "Must own Unchained Pass!");

        for (uint i = 0; i < loopAmount; i++) {
            deployWorker();
        }
    }
      
    function deployWorker() private {
        Worker w = new Worker(executeAddress);
        workers[tx.origin].push(address(w));
    }

    function workerSize() public view returns (uint256) {
        return workers[tx.origin].length;
    }

    function getWorkers() public view returns (address[] memory) {
        return workers[tx.origin];
    }

    function setExecuteAddress(address a) public onlyOwner {
        executeAddress = a;
    }
}