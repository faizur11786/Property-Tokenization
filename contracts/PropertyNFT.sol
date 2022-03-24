// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is Ownable{
    using Counters for Counters.Counter;
    Counters.Counter public tokenIds;
    
    //Token Name
    string public name;

    //Token Symbol
    string public symbol;

    mapping (uint256 => address) private _tokenOwner;
    mapping (address => uint256) private _balances;
    mapping (uint256 => bytes) private _tokenURI;
    mapping (uint256 => address) private _tokenApprovals;
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    constructor () Ownable(){
        name = "Aqarchain Properties";
        _symbol = "APRO";
    }

    function balanceOf(address owner) public view override returns (uint256){
        return _balances[owner];
    }
    
    function ownerOf(uint256 tokenId) public view override returns (address){
        return _tokenOwner[tokenId];
    }

    function mintNFT(bytes memory data) public onlyOwner returns (uint256){
        tokenIds.increment();
        uint256 newTokenId = tokenIds.current();
        _mint(_msgSender(), newTokenId, data);
        return newTokenId;
    }

    function propertyTokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory){
        require(_exists(tokenId), "URI query for nonexistent token");
        return string(_tokenURI[tokenId]);       
    }

    function setPropertyTokenURI(uint256 tokenId, bytes memory data) public onlyOwner returns (bool){
        _tokenURI[tokenId] = data;
        return true;
    }

    function approveNFT(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        require(to != owner, "approval to current owner");
        require(
            _msgSender() == owner ,
            "approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

     /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAllNFTs(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function setApprovalForAllNFTs(address operator,  bool approved) public override {
        require(_msgSender() == operator, "Caller is not the operator");
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function getApprovedForNFTs(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function transferNFTs(address to, uint256 tokenId) public {
        require(to != address(0), "Transfer to 0 address");
        require(_exists(tokenId), "Transfer nonexistent token");
        require(ownerOf(tokenId) == _msgSender(), "Transfer not own token");
        _transfer(to, _msgSender(), tokenId);
    }


    function transferFromNFTs(address from, address to, uint256 tokenId) public virtual override{
        require(_exists(tokenId), "Transfer nonexistent token");
        require(ownerOf(tokenId) == from, "Transfer not own token");
        require(_tokenApprovals[tokenId] == _msgSender(), "Transfer not approved");
        _transfer(to, from, tokenId);
    }
    

    function _transfer(address to, address from, uint256 tokenId) override internal {
        _tokenOwner[tokenId] = to;
        _balances[from] -= 1;
        _balances[to] += 1;
        emit Transfer(from, to, tokenId);
    }

    function _mint(address to, uint256 tokenId, bytes memory data) internal {
        require(to != address(0), "Mint to the zero address");
        _balances[to] = tokenId;
        _tokenOwner[tokenId] = to;
        _tokenURI[tokenId] = data;
        emit TransferNFTs(address(0), to, tokenId);
    }

    function _exists(uint256 tokenId) internal view virtual override returns (bool) {
        return _tokenOwner[tokenId] != address(0);
    }

    function _approve(address to, uint256 tokenId) internal override virtual {
        _tokenApprovals[tokenId] = to;
        emit ApprovalNFTs(ownerOf(tokenId), to, tokenId);
    }
}
