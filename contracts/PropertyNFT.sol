// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PropertyTokenization.sol";


interface IPropertyToken {
    function buyToken(uint256, address, address) external returns(bool);
}



contract PropertyNFT is Ownable{
    using Counters for Counters.Counter;
    Counters.Counter public tokenIds;

    mapping (address => address) public balanceFor;

    address[] public paymentMethods;

    struct Properties {
        string propId;
        string propName;
        string propSymbol;
        bytes propertyURI;
        uint256 propTotalSupply;
        address propOwner;
        address propertyAddress;
    }

    mapping ( uint256 => Properties ) public properties;

    constructor () Ownable(){}

    function listProperty(
        uint256 _totalSupply,
        string memory _propId,
        string memory _propName,
        string memory _propSymbol,
        bytes memory _propURI,
        address _propOwner,
        bool _saleState
    ) external onlyOwner returns(bool success){
        tokenIds.increment();
        uint256 newTokenId_ = tokenIds.current();
        PropertyTokenization propToken_ = new PropertyTokenization(
            _propName,
            _propSymbol,
            _totalSupply,
            newTokenId_,
            _saleState
        );
        properties[newTokenId_] = Properties({
            propId:_propId,
            propName:_propName,
            propSymbol:_propSymbol,
            propertyURI:_propURI,
            propTotalSupply:_totalSupply,
            propOwner:_propOwner,
            propertyAddress: address(propToken_)
        });
        return true;
    }


    function buyShares(
        address _token, 
        uint256 _amount, 
        address _buyWithToken
    ) public virtual returns(bool success){
        IPropertyToken propertyToken = IPropertyToken(_token);
        propertyToken.buyToken(_amount, _msgSender(), _buyWithToken);
        balanceFor[_msgSender()] = _token;
        return true;
    }

    function setBalanceFor(address _to, address _with) external{
        balanceFor[_to] = _with;
    }

    function paymentMethodLength() public view virtual returns (uint256){
        return paymentMethods.length;
    }

    function addPaymentMethod(address newPaymentMethod) public onlyOwner returns (bool success){
        require(newPaymentMethod != address(0), "Invalid address");
        for(uint256 i = 0; i < paymentMethodLength(); i++){
            require(paymentMethods[i] != newPaymentMethod, "Duplicate Payment Method");
        }
        paymentMethods.push(newPaymentMethod);
        return true;
    }



    function getTokenURI(uint256 _tokenId) public view virtual returns (string memory){
        require(_exists(_tokenId), "URI query for nonexistent token");
        return string(properties[_tokenId].propertyURI);       
    }

    function setTokenURI(uint256 _tokenId, bytes memory _data) public view onlyOwner returns (bool){
        require(_exists(_tokenId), "URI query for nonexistent token");
        Properties memory property = properties[_tokenId];
        property.propertyURI = _data;
        return true;
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return properties[tokenId].propertyAddress != address(0);
    }
}
