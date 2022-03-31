// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PropertyTokenization.sol";

interface IPropertyToken {
    function buyToken(
        uint256,
        address,
        address
    ) external returns (bool);
}

contract PropertyNFT is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public tokenIds;

    mapping(address => address) public balanceFor;

    mapping(address => uint256) public idOf;

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

    mapping(uint256 => Properties) public properties;

    event CreateProperty(
        address indexed _propertyAddress,
        uint256 _propTotalSupply
    );

    event BuyShares(
        address indexed _token,
        address indexed _to,
        address indexed __buyWithToken,
        uint256 _value
    );

    constructor() Ownable() {}

    function listProperty(
        uint256 _totalSupply,
        string memory _propId,
        string memory _propName,
        string memory _propSymbol,
        bytes memory _propURI,
        address _propOwner,
        bool _saleState
    ) external onlyOwner returns (bool success) {
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
            propId: _propId,
            propName: _propName,
            propSymbol: _propSymbol,
            propertyURI: _propURI,
            propTotalSupply: _totalSupply,
            propOwner: _propOwner,
            propertyAddress: address(propToken_)
        });
        idOf[address(propToken_)] = newTokenId_;
        emit CreateProperty(address(propToken_), _totalSupply);
        return true;
    }

    function burn(uint256 _tokenId) external onlyOwner returns (bool) {
        require(_exists(_tokenId), "Token does not exist");
        properties[_tokenId] = Properties({
            propId: "",
            propName: "",
            propSymbol: "",
            propertyURI: "",
            propTotalSupply: 0,
            propOwner: address(0),
            propertyAddress: address(0)
        });
        return true;
    }

    function buyShares(
        address _token,
        uint256 _amount,
        address _buyWithToken
    ) public virtual returns (bool success) {
        uint256 tokenId = idOf[_token];
        require(_exists(tokenId), "Token does not exist");
        IPropertyToken propertyToken = IPropertyToken(_token);
        propertyToken.buyToken(_amount, _msgSender(), _buyWithToken);
        balanceFor[_msgSender()] = _token;
        emit BuyShares(_token, _msgSender(), _buyWithToken, _amount);
        return true;
    }

    function setBalanceFor(address _to, address _with) external {
        balanceFor[_to] = _with;
    }

    function paymentMethodLength() public view virtual returns (uint256) {
        return paymentMethods.length;
    }

    function addPaymentMethod(address[] memory newPaymentMethod)
        public
        virtual
        onlyOwner
        returns (bool success)
    {
        for (uint256 i = 0; i < newPaymentMethod.length; i++) {
            require(newPaymentMethod[i] != address(0), "Invalid address");
            _addPaymentMethod(newPaymentMethod[i]);
        }
        return true;
    }

    function _addPaymentMethod(address newPaymentMethod)
        internal
        returns (bool success)
    {
        if (paymentMethods.length == 0) {
            paymentMethods.push(newPaymentMethod);
        } else {
            for (uint256 i = 0; i < paymentMethods.length; i++) {
                if (paymentMethods[i] != newPaymentMethod) {
                    paymentMethods.push(newPaymentMethod);
                    return true;
                }
            }
        }
    }

    function getTokenURI(uint256 _tokenId)
        public
        view
        virtual
        returns (string memory)
    {
        require(_exists(_tokenId), "URI query for nonexistent token");
        return string(properties[_tokenId].propertyURI);
    }

    function setTokenURI(uint256 _tokenId, bytes memory _data)
        public
        view
        onlyOwner
        returns (bool)
    {
        require(_exists(_tokenId), "URI query for nonexistent token");
        Properties memory property = properties[_tokenId];
        property.propertyURI = _data;
        return true;
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return properties[tokenId].propertyAddress != address(0);
    }
}
