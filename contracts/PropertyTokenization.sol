// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "hardhat/console.sol";


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IPropertyNFT {
   function setBalanceFor(address, address) external ;
}


contract PropertyTokenization is Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => uint256) private _cBalance;

    uint256 public referralCount;


    AggregatorV3Interface internal maticPriceFeed;


    struct Referral {
        address referrer;
        uint256 amount;
    }

    mapping (address => mapping(address => uint256)) private _allowances;
    mapping (address => Referral[]) public referrals;
    mapping (address => uint256) public referralCountOf;
    mapping (address => uint256) public referralAmountOf;

    string public propetyName;
    string public propetySymbol;
    uint256 public tokenId;
    uint256 public propetyTotalSupply;
    uint256 public availableSupply;
    uint256 public saleTimer;
    uint256 public listPrice;
    bool public saleState = false;
    address[] public holders;
    address public propertiesNFT;

    event TokenTransfer(address indexed _from, address indexed _to, uint256 _value);
    event TokenApproval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor(
        string memory _name, /* Property Name */
        string memory _symbol, /* Property Symbol */
        uint256 _totalSupply, 
        uint256 _tokenId, /* uint256 _saleTimer */
        uint256 _listPrice, /* in $ */
        address _propOwner, /* if you want to make someone owner of that property || _msgSender() */
        bool _saleState /* true = sale, false = not sale */
    ) Ownable() {
        maticPriceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
        propetyName = _name;
        propetySymbol = _symbol;
        propetyTotalSupply = _totalSupply;
        _cBalance[address(this)] = _totalSupply;
        tokenId = _tokenId;
        saleState = _saleState;
        propertiesNFT = _msgSender();
        availableSupply = _totalSupply;
        listPrice = _listPrice;
        if(owner() != _propOwner){
            transferOwnership(_propOwner);
        }
    }

    function getPrice() public view returns(uint256){
        (,int256 answer,,,) = maticPriceFeed.latestRoundData();
         return uint256(answer * 10000000000);
    }

    function getConversionRate(uint256 maticAmount) public view returns (uint256){
        uint256 ethPrice = getPrice(); // 262784346 ;
        uint256 maticAmountInUsd = (ethPrice * maticAmount) / 1000000000000000000;
        return maticAmountInUsd;
    }

    function tokenPrice() public view returns (uint256) {
        return listPrice.mul(1e18).div(propetyTotalSupply);
    }

    function updateTokenPrice(uint256 _listPrice) public {
        listPrice = _listPrice;
    }

    function holdersLength() public view virtual returns (uint256){
        return holders.length;
    }

    function updateSaleTimer(uint256 time) external onlyOwner{
        require(time > block.timestamp,"Time should be greater than now time");
        saleTimer = time;
    }

    function flipSaleState() external onlyOwner{
        saleState = !saleState;
    }

    function buyToken(uint256 _amount, address _to) external payable virtual returns (bool success){
        // require(saleTimer > block.timestamp,"Crowdsale is ended");
        require(_msgSender() == propertiesNFT, "Only owner can buy tokens");
        require(_amount > 0 && _amount <= availableSupply, "Invalid amount");
        _cBalance[address(this)] -= _amount;
        _cBalance[_to] += _amount;
        availableSupply = availableSupply.sub(_amount);
        success = true;
    }

    function addReferral(address _referralToken, uint256 _amount) public returns(bool success) {
        referralCount++;
        referralCountOf[_msgSender()] = referralCountOf[_msgSender()] + 1;
        referralAmountOf[_msgSender()] = referralAmountOf[_msgSender()] + _amount;
        referrals[_msgSender()].push(Referral(_referralToken, _amount));
        return true;
    }


    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function cBalanceOf(address account) public view virtual returns (uint256) {
        return _cBalance[account];
    }

    function addUsers(address[] memory usersAddress, uint256[] memory usersBalance) public onlyOwner returns (bool success){
        require(usersAddress.length == usersBalance.length, "Invalid length of array");
        for(uint256 i = 0; i < usersAddress.length; i++){
            require(usersAddress[i] != address(0), "Invalid address");
            require(usersBalance[i] > 0, "Invalid balance");
            _cBalance[usersAddress[i]] = usersBalance[i];
            availableSupply = availableSupply.sub(usersBalance[i]);
            holders.push(usersAddress[i]);
        }
        return true;
    }


    function claimToken(uint256 _value) external {
        require(cBalanceOf(_msgSender()) > 0,"Nothing to claim");
        // require(saleTimer < block.timestamp,"Time not finished yet");
        _balances[ _msgSender()] += _value;
        _cBalance[_msgSender()] -= _value;
    }

    function tokenTransfer(address _to, uint256 _value) public returns (bool success){
        require(_to != address(0), "Invalid address");
        require(_value <= _balances[_msgSender()], "Not enough balance");
        _transfer(_msgSender(), _to, _value);
        return true;
    }

    function tokenTransferFrom(address _from, address _to, uint256 _value) public returns (bool success){
        require(_to != address(0) && _from != address(0) && _to != _from, "Invalid address");
        require(_value <= _allowances[_from][_msgSender()], "Not enough allowance");
        require(_value <= _balances[_from], "Not enough balance");
        _transfer(_from, _to, _value);
        return true;
    }

    function tokenApprove(address _spender, uint256 _value) public returns (bool success){
        require(_spender != address(0), "invalid address");
        _allowances[_msgSender()][_spender] = _value;
        emit TokenApproval(_msgSender(), _spender, _value);
        return true;
    }

    function tokenAllowance(address _owner, address _spender) public view returns (uint256 remaining){
        return _allowances[_owner][_spender];
    }

    function _transfer(address from, address to, uint256 value) internal {
        IPropertyNFT propertyToken = IPropertyNFT(propertiesNFT);
        propertyToken.setBalanceFor(to, address(this));
        _balances[from] -= value;
        _balances[to] += value;
        holders.push(to);
        emit TokenTransfer(from, to, value);
    }

    function withdrawFunds(address _token) external onlyOwner returns(bool success) {
        require(IERC20(_token).balanceOf(address(this)) > 0, "No funds to withdraw");
        IERC20(_token).transfer(_msgSender(), IERC20(_token).balanceOf(address(this)));
        return true;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(_msgSender()).transfer(balance);
    }
}