// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./PropertyTokenization.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


interface IPropertyToken {
    function buyToken(
        uint256,
        address,
        address
    ) external payable returns (bool);

    function tokenPrice() external view returns (uint256);
}

interface IOracle {
    function getRate(
        IERC20 srcToken,
        IERC20 dstToken,
        bool useWrappers
    ) external view returns (uint256 weightedRate);
}

contract PropertyNFT is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public tokenIds;
    using SafeMath for uint256;
    
    mapping(address => address[]) public balanceFor;
    mapping(address => uint256) public balanceForCountOf;
    mapping(address => address) public priceFeedOf;

    mapping(address => uint256) public idOf;

    address[] public paymentMethods;
    
    uint256 platformFee;
    address private aQRAddress;

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
        uint256 value
    );
    AggregatorV3Interface internal maticPriceFeed;

    constructor() Ownable() {
        platformFee = 200;
        maticPriceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
    }

    function setAQRAddress(address _aQRAddress) external onlyOwner {
        aQRAddress = _aQRAddress;
    }

    function getMaticPrice() public view returns(uint256){
        (,int256 answer,,,) = maticPriceFeed.latestRoundData();
         return uint256(answer * 10000000000);
    }

    function getMaticConversionRate(uint256 maticAmount) public view returns (uint256){
        uint256 ethPrice = getMaticPrice(); // 262784346 ;
        uint256 maticAmountInUsd = (ethPrice * maticAmount) / 1000000000000000000;
        return maticAmountInUsd;
    }

    function listProperty(
        uint256 _totalSupply,
        uint256 _listPrice,
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
            _listPrice,
            _propOwner,
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
        address _propertyAddress,
        uint256 _amount,
        address _buyWithToken
    )
        public
        payable
        virtual 
        returns (bool success)
    {
        require(_propertyAddress != address(0), "Property address cannot be 0");
        require(_exists(idOf[_propertyAddress]), "Property does not exist");
        require(_amount % 1 == 0, "Amount must be a whole number");
        
        IPropertyToken propertyToken = IPropertyToken(_propertyAddress);

        uint256 totalUSD = _amount * propertyToken.tokenPrice();

        AggregatorV3Interface aggregator = AggregatorV3Interface(priceFeedOf[_buyWithToken]);
        (,int256 answer,,,) = aggregator.latestRoundData();
        uint256 ethPrice = uint256(answer * 10000000000);

        if( msg.value != 0 ) {
            // THIS MEANS WE ARE BUYING WITH ETH/MATIC
            uint256 inMatic = totalUSD.div(ethPrice);
            require (inMatic <= msg.value && (ethPrice * msg.value).div(1e18) >= totalUSD, "Inadequate MATIC sent");

            propertyToken.buyToken{value:msg.value}(_amount, _msgSender(), _buyWithToken);
            
            balanceFor[_msgSender()].push(_propertyAddress);
            balanceForCountOf[_msgSender()]++;
            
            success = true;

            emit BuyShares(_propertyAddress, _msgSender(), _buyWithToken, _amount);
        }
        // THIS MEANS WE ARE BUYING WITH A OTHER PAYMENT METHODS (ERC20)
        for(uint256 i = 0; i < paymentMethods.length; i++) {
            if(paymentMethods[i] == _buyWithToken) {
                if(paymentMethods[i] == address(aQRAddress)){
                    uint256 rate = IOracle(priceFeedOf[_buyWithToken]).getRate(
                        IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063),
                        IERC20(aQRAddress),
                        true
                    );

                    require(IERC20(_buyWithToken).allowance(_msgSender(), address(this)) >= rate * totalUSD, "Inadequate AQR allowance");
                    require(IERC20(_buyWithToken).balanceOf(_msgSender()) >= rate * totalUSD, "Not enough balance");

                    IERC20(_buyWithToken).transferFrom(_msgSender(), _propertyAddress, rate * totalUSD);

                    success = true;
                    emit BuyShares(_propertyAddress, _msgSender(), _buyWithToken, _amount);
                }

                uint256 token = totalUSD.div(ethPrice);
                require(token <= IERC20(_buyWithToken).allowance(_msgSender(), address(this)), "Tokens not approved enough");
                require(token <= IERC20(_buyWithToken).balanceOf(_msgSender()), "Not enough balance");
                
                success = true;
                emit BuyShares(_propertyAddress, _msgSender(), _buyWithToken, _amount);
            }
        }
    }

    function paymentMethodLength() public view virtual returns (uint256) {
        return paymentMethods.length;
    }


    function addPaymentMethod(address[] memory newPaymentMethod, address[] memory priceFeeds)
        public
        virtual
        onlyOwner
        returns (bool success)
    {
        require(
            newPaymentMethod.length == priceFeeds.length,
            "Length of payment methods and price feeds must be equal"
        );
        for (uint256 i = 0; i < newPaymentMethod.length; i++) {
            require(newPaymentMethod[i] != address(0), "Invalid address");
            priceFeedOf[newPaymentMethod[i]] = priceFeeds[i];
            _addPaymentMethod(newPaymentMethod[i]);
        }
        return true;
    }

    function removePaymentMethod(uint256 _index)
        public
        virtual
        onlyOwner
        returns (bool success)
    {
        require(_index < paymentMethods.length, "Index out of bounds");
        priceFeedOf[paymentMethods[_index]] = address(0);
        for (uint256 i = _index; i < paymentMethods.length - 1; i++) {
            paymentMethods[i] = paymentMethods[i + 1];
        }
        paymentMethods.pop();
        success = true;
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
