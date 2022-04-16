// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PropertyTokenization.sol";

interface IOracle {
    function getRate(
        IERC20 srcToken,
        IERC20 dstToken,
        bool useWrappers
    ) external view returns (uint256 weightedRate);
}

contract PropertyFactory is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter public tokenIds;
    using SafeMath for uint256;

    mapping(address => address[]) public balanceFor;
    mapping(address => uint256) public balanceForCountOf;
    mapping(address => address) public priceFeedOf;

    mapping(address => uint256) public idOf;

    address public aQRAddress;

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
        address indexed propertyAddress,
        uint256 propTotalSupply
    );

    event BuyShares(
        address indexed token,
        address indexed to,
        address indexed buyWithToken,
        uint256 value,
        uint256 tokenAmount
    );
    event BuySharesWithMatic(
        address indexed token,
        address indexed to,
        uint256 value,
        uint256 amount
    );

    constructor() Ownable() ReentrancyGuard() {}

    function setBalanceFor(address _owner, address _propertyAddress) external nonReentrant returns(bool){
        require(_msgSender() == _propertyAddress, "Only owner can Call");
        balanceFor[_owner].push(_propertyAddress);
        balanceForCountOf[_msgSender()]++;
        return true;
    }


    function isPaymentMethod(address _token)  public view returns(bool) {
        return priceFeedOf[_token] != address(0);
    }

    function setAQRAddress(address _aQRAddress) external onlyOwner {
        aQRAddress = _aQRAddress;
    }

    function listProperty(
        uint256 _totalSupply,
        uint256 _listPrice,
        string memory _propId,
        string memory _propName,
        string memory _propSymbol,
        bytes memory _propURI
    ) external onlyOwner returns (bool success) {
        tokenIds.increment();
        uint256 newTokenId_ = tokenIds.current();
        PropertyTokenization propToken_ = new PropertyTokenization(
            _propName,
            _propSymbol,
            _totalSupply,
            newTokenId_,
            _listPrice,
            owner()
        );
        properties[newTokenId_] = Properties({
            propId: _propId,
            propName: _propName,
            propSymbol: _propSymbol,
            propertyURI: _propURI,
            propTotalSupply: _totalSupply,
            propOwner: owner(),
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

    function getPriceOf(address _priceFeed) public view returns (uint256) {
        AggregatorV3Interface aggregator = AggregatorV3Interface(_priceFeed);
        (,int256 answer,,,) = aggregator.latestRoundData();
        uint256 ethPrice = uint256(answer) * 10 ** (18 - aggregator.decimals());
        return ethPrice;
    }

    function getMatic(address _propertyAddress, uint256 _amount) public view returns (uint256){
        PropertyTokenization propertyToken = PropertyTokenization(_propertyAddress);
        uint256 totalUSD = _amount * propertyToken.tokenPrice();
        uint256 ethPrice = getPriceOf(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
        return (totalUSD * 1e18 / ethPrice * 1e18) / 1e18;
    }

    function buySharesWithMatic( 
        address _propertyAddress,
        uint256 _amount
    ) external payable nonReentrant returns(bool){
        require(_propertyAddress != address(0), "Property address cannot be 0");
        require(_exists(idOf[_propertyAddress]), "Property does not exist");
        require(_amount % 1 == 0, "Amount must be a whole number");

        uint256 inMatic = getMatic(_propertyAddress, _amount);
        require (inMatic <= msg.value, "Inadequate MATIC sent");

        PropertyTokenization propertyToken = PropertyTokenization(_propertyAddress);
        require(propertyToken.isEligibleToBuy(_msgSender()), "Not eligible to buy");

        propertyToken.buyToken{value:msg.value}(_amount, _msgSender());

        balanceFor[_msgSender()].push(_propertyAddress);
        balanceForCountOf[_msgSender()]++;

        emit BuySharesWithMatic(_propertyAddress, _msgSender(), msg.value, _amount);
        return true;
    }

    function buyShares(
        address _propertyAddress,
        uint256 _amount,
        address _buyWithToken
    )
        public
        nonReentrant
        returns (bool)
    {
        require(_propertyAddress != address(0), "Property address cannot be 0");
        require(_exists(idOf[_propertyAddress]), "Property does not exist");
        require(_amount % 1 == 0, "Amount must be a whole number");
        require(isPaymentMethod(_buyWithToken), "Payment Method not found");

        PropertyTokenization propertyToken = PropertyTokenization(_propertyAddress);
        require(propertyToken.isEligibleToBuy(_msgSender()), "Not eligible to buy");
        
        ERC20 token = ERC20(_buyWithToken);

        uint256 totalUSD = _amount * propertyToken.tokenPrice();
        uint256 ethPrice = getPriceOf(priceFeedOf[_buyWithToken]);

        if(_buyWithToken == address(aQRAddress)){
            uint256 rate = IOracle(priceFeedOf[_buyWithToken]).getRate(
                IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063),
                IERC20(aQRAddress),
                true
            );
            uint256 totalAQR = (totalUSD * rate ) / 1e18;
            require(token.allowance(_msgSender(), address(this)) >= totalAQR, "Inadequate AQR allowance");
            require(token.balanceOf(_msgSender()) >= totalAQR, "Not enough balance");

            require(token.transferFrom(_msgSender(), _propertyAddress, totalAQR), "Transfer failed");
            propertyToken.buyToken(_amount, _msgSender());

            balanceFor[_msgSender()].push(_propertyAddress);
            balanceForCountOf[_msgSender()]++;

            emit BuyShares(_propertyAddress, _msgSender(), _buyWithToken, _amount, totalAQR);
            return true;
        }
        
        uint256 tokens = (totalUSD * 1e18 / ethPrice * 1e18) / 1e18;
        require(tokens <= token.allowance(_msgSender(), address(this)), "Tokens not approved enough");
        require(tokens <= token.balanceOf(_msgSender()), "Not enough balance");
        
        require(token.transferFrom(_msgSender(), _propertyAddress, tokens), "Transfer failed");
        propertyToken.buyToken(_amount, _msgSender());

        balanceFor[_msgSender()].push(_propertyAddress);
        balanceForCountOf[_msgSender()]++;
        
        emit BuyShares(_propertyAddress, _msgSender(), _buyWithToken, _amount, tokens);
        return true;
    }

    function addPaymentMethod(address paymentMethod, address priceFeeds)
        external
        onlyOwner
        returns (bool success)
    {
        require(paymentMethod != address(0), "Invalid address");
        priceFeedOf[paymentMethod] = priceFeeds;
        return true;
    }

    function removePaymentMethod(address paymentMethod)
        external
        onlyOwner
        returns (bool success)
    {
        priceFeedOf[paymentMethod] = address(0);
        success = true;
    }


    function getTokenURI(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        require(_exists(_tokenId), "URI query for nonexistent token");
        return string(properties[_tokenId].propertyURI);
    }

    function setTokenURI(uint256 _tokenId, bytes memory _data)
        external
        view
        onlyOwner
        returns (bool)
    {
        require(_exists(_tokenId), "URI query for nonexistent token");
        Properties memory property = properties[_tokenId];
        property.propertyURI = _data;
        return true;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return properties[tokenId].propertyAddress != address(0);
    }

    function withdrawFunds(address _token) external onlyOwner nonReentrant {
        require(IERC20(_token).balanceOf(address(this)) > 0, "No funds to withdraw");
        IERC20(_token).transfer(_msgSender(), IERC20(_token).balanceOf(address(this)));
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        payable(_msgSender()).transfer(balance);
    }
}