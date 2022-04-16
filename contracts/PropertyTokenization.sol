// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "hardhat/console.sol";


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IPropertyFactory {
   function setBalanceFor(address, address) external ;
}


contract PropertyTokenization is Ownable, ReentrancyGuard {
    using SafeMath for uint256;


    bytes private pROSTATE = "ACTIVE";

    modifier onlyActive{
        require(keccak256(pROSTATE) == keccak256("ACTIVE"), "onlyActive: Not allowed");
        _;
    }
    modifier onlyClosed{
        require(keccak256(pROSTATE) == keccak256("CLOSED"), "onlyClosed: Not allowed");
        _;
    }
    
    struct Whitelist{
        uint256 requested;
        uint256 boughted;
    }

    mapping(address=> Whitelist) public whitelist;

    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _cBalance;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => uint256) public referrals;
    mapping(uint256 => address) public referraredBy;
    
    uint256 public referralCount;

    string public name;
    string public symbol;
    uint256 public tokenId;
    uint256 public propetyTotalSupply;
    uint256 public availableSupply;
    uint256 public saleTimer;
    uint256 public listPrice;
    address[] public holders;
    address public propertyFactory;


    IERC20 private aQR =  IERC20(0xaE204EE82E60829A5850FE291C10bF657AF1CF02);
    IERC20 private uSDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);


    event TokenTransfer(address indexed _from, address indexed _to, uint256 _value);
    event TokenApproval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor(
        string memory _name, /* Property Name */
        string memory _symbol, /* Property Symbol */
        uint256 _totalSupply, 
        uint256 _tokenId, /* uint256 _tokenId */
        uint256 _listPrice, /* in $ */
        address _propOwner /* if you want to make someone owner of that property || _msgSender() */
    ) Ownable() ReentrancyGuard() {
        name = _name;
        symbol = _symbol;
        propetyTotalSupply = _totalSupply;
        _cBalance[address(this)] = _totalSupply;
        tokenId = _tokenId;
        propertyFactory = _msgSender();
        availableSupply = _totalSupply;
        listPrice = _listPrice;
        transferOwnership(_propOwner);
    }

    function updateProState(string memory _state) public onlyOwner returns(bool) {
        pROSTATE = bytes(_state);
        return true;
    }

    function isEligibleToBuy(address _address, uint256 _amount) public view returns(bool) {
        return whitelist[_address].requested >= _amount;
    }

    function eligibleToBuy(address _address, uint256 _amount) public returns(bool){
        whitelist[_address].requested = _amount;
        return true;
    }
    
    function tokenPrice() public view returns (uint256) {
        return listPrice.mul(1e18).div(propetyTotalSupply);
    }

    function updateTokenPrice(uint256 _listPrice) public onlyOwner {
        listPrice = _listPrice;
    }

    function holdersLength() public view returns (uint256){
        return holders.length;
    }

    function updateSaleTimer(uint256 time) external onlyOwner{
        require(time > block.timestamp, "Invalid Time");
        saleTimer = time;
    }

    function buyToken(uint256 _amount, address _to) external onlyActive payable returns (bool success){
        require(_msgSender() == propertyFactory, "Only owner can buy tokens");
        require(_amount > 0 && _amount <= availableSupply, "Invalid amount");
        _cBalance[address(this)] -= _amount;
        _cBalance[_to] += _amount;
        availableSupply = availableSupply.sub(_amount);
        eligibleToBuy(_to, _amount);
        _addReferral(_to, _amount * tokenPrice());
        success = true;
    }

    function _addReferral(address _referrer, uint256 _amount) internal returns(bool success) {
        if(referrals[_referrer] == 0 ){
            referralCount++;
            referraredBy[referralCount] = _referrer;
            referrals[_referrer] = _amount;
            return true;
        }
        referrals[_referrer] += _amount;
        return true;
    }


    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function cBalanceOf(address account) public view returns (uint256) {
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


    function claimToken() external onlyClosed nonReentrant {
        require(cBalanceOf(_msgSender()) > 0,"Nothing to claim");
        _balances[ _msgSender()] += _cBalance[_msgSender()];
        _cBalance[_msgSender()] = 0;
    }

    function tokenTransfer(address _to, uint256 _value) public onlyClosed returns (bool success){
        require(_to != address(0), "Invalid address");
        require(_value <= _balances[_msgSender()], "Not enough balance");
        _transfer(_msgSender(), _to, _value);
        return true;
    }

    function tokenTransferFrom(address _from, address _to, uint256 _value) public onlyClosed returns (bool success){
        require(_to != address(0) && _from != address(0) && _to != _from, "Invalid address");
        require(_value <= _allowances[_from][_msgSender()], "Not enough allowance");
        require(_value <= _balances[_from], "Not enough balance");
        _transfer(_from, _to, _value);
        return true;
    }

    function tokenApprove(address _spender, uint256 _value) public onlyClosed returns (bool success){
        require(_spender != address(0), "invalid address");
        _allowances[_msgSender()][_spender] = _value;
        emit TokenApproval(_msgSender(), _spender, _value);
        return true;
    }

    function tokenAllowance(address _owner, address _spender) public view onlyClosed returns (uint256 remaining){
        return _allowances[_owner][_spender];
    }

    function _transfer(address from, address to, uint256 value) internal {
        IPropertyFactory propertyToken = IPropertyFactory(propertyFactory);
        propertyToken.setBalanceFor(to, address(this));
        _balances[from] -= value;
        _balances[to] += value;
        holders.push(to);
        emit TokenTransfer(from, to, value);
    }

    function withdrawFunds(address _token) external onlyOwner nonReentrant {
        require(IERC20(_token).balanceOf(address(this)) > 0, "No funds to withdraw");
        IERC20(_token).transfer(_msgSender(), IERC20(_token).balanceOf(address(this)));
    }

    function withdraw() public onlyOwner nonReentrant{
        uint256 balance = address(this).balance;
        payable(_msgSender()).transfer(balance);
    }
}