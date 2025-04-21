// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Unchained is ERC1155, Ownable {
    
    event Mint(address indexed to, uint256[] indexed tokenId);
    event Revoke(address indexed to, uint256[] indexed tokenId);

    bytes32 public whitelistMerkleRoot = 0x2839eddc1b8fac73603098dc4088d8b4cba36391ee82c27d1cfed1c33a57841f;
    string private tokenURI = "https://gateway.pinata.cloud/ipfs/QmQb1Av1eM6SQvCTtT7mFr5wdqtPkVuKEYm645fT85PGqt";
    uint256 public PRICE = 0.5 ether;
    
    bool public wlMintTime = false;
    bool public publicMintTime = false;

    constructor() ERC1155("Unchained Minter") Ownable() {
        _mint(msg.sender, 0, 1, "");
    }

    function mint() public payable {
        require(publicMintTime, "It is not time to mint!");
        require(balanceOf(msg.sender, 0) == 0, "Already Holding Unchained Minting Pass");
        require(msg.value >= PRICE, "Not enough ether");

        _mint(msg.sender, 0, 1, "");
    }

    function whitelistMint(bytes32[] calldata _merkleProof) public payable {
        require(wlMintTime, "It is not time to mint!");
        require(balanceOf(msg.sender, 0) == 0, "Already Holding Unchained Minting Pass");
        require(msg.value >= PRICE, "Not enough ether");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, whitelistMerkleRoot, leaf), "Invalid Merkle Proof");

        _mint(msg.sender, 0, 1, "");
    }

    function ownerMint(address to) public onlyOwner {
        require(balanceOf(to, 0) == 0, "Already Holding Unchained Minting Pass");
        _mint(to, 0, 1, "");    
    }
        function ownerBatchMint(address[] calldata addresses) public onlyOwner {
            for (uint256 i = 0; i < addresses.length; i++) {
                require(balanceOf(addresses[i], 0) == 0, "Address already holds Unchained Minting Pass");
                _mint(addresses[i], 0, 1, "");
            }
        }
    function revoke(address wallet) external onlyOwner {
        _burn(wallet, 0, balanceOf(wallet, 0));
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155)
    {
        require(from == address(0) || to == address(0), "Not allowed to transfer token");
        super._update(from, to, ids, values);

        if (from == address(0)) {
            emit Mint(to, ids);
        } else if (to == address(0)) {
            emit Revoke(from, ids);
        }
    }

    function uri(uint256) public view override returns (string memory) {
        return tokenURI;
    }

    function flipState() public onlyOwner {
        publicMintTime = !publicMintTime;
    }

    function flipStateWL() public onlyOwner {
        wlMintTime = !wlMintTime;
    }

    function setTokenURI(string memory _uri) public onlyOwner {
        tokenURI = _uri;
    }

    function setPrice(uint256 _price) public onlyOwner {
        PRICE = _price;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }
}