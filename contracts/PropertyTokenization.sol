// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "hardhat/console.sol";


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IPropertyFactory {
   function setBalanceFor(address, address) external ;
}


contract PropertyTokenization is Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => uint256) private _cBalance;
    mapping (address => mapping(address => uint256)) private _allowances;

    uint256 public referralCount;
    mapping (address => uint256) public referrals;
    mapping (uint256 => address) public referraredBy;

    string public name;
    string public symbol;
    uint256 public tokenId;
    uint256 public propetyTotalSupply;
    uint256 public availableSupply;
    uint256 public saleTimer;
    uint256 public listPrice;
    bool public saleState = false;
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
        uint256 _tokenId, /* uint256 _saleTimer */
        uint256 _listPrice, /* in $ */
        address _propOwner, /* if you want to make someone owner of that property || _msgSender() */
        bool _saleState /* true = sale, false = not sale */
    ) Ownable() {
        name = _name;
        symbol = _symbol;
        propetyTotalSupply = _totalSupply;
        _cBalance[address(this)] = _totalSupply;
        tokenId = _tokenId;
        saleState = _saleState;
        propertyFactory = _msgSender();
        availableSupply = _totalSupply;
        listPrice = _listPrice;
        transferOwnership(_propOwner);
    }
    
    function tokenPrice() public view returns (uint256) {
        return listPrice.mul(1e18).div(propetyTotalSupply);
    }

    function updateTokenPrice(uint256 _listPrice) public {
        listPrice = _listPrice;
    }

    function holdersLength() public view returns (uint256){
        return holders.length;
    }

    function updateSaleTimer(uint256 time) external onlyOwner{
        require(time > block.timestamp, "Time should be greater than now time");
        saleTimer = time;
    }

    function flipSaleState() external onlyOwner{
        saleState = !saleState;
    }

    function buyToken(uint256 _amount, address _to) external payable returns (bool success){
        require(saleTimer > block.timestamp && saleState,"Crowdsale is ended");
        require(_msgSender() == propertyFactory, "Only owner can buy tokens");
        require(_amount > 0 && _amount <= availableSupply, "Invalid amount");
        require(_to != address(0), "Invalid address");
        _cBalance[address(this)] -= _amount;
        _cBalance[_to] += _amount;
        availableSupply = availableSupply.sub(_amount);
        addReferral(_to, _amount * tokenPrice());
        success = true;
    }

    function addReferral(address _referrer, uint256 _amount) internal returns(bool success) {
        if(referrals[_referrer] == 0 ){
            referralCount++;
            referraredBy[referralCount] = _referrer;
            referrals[_referrer] = _amount;
            return true;
        } 
        referrals[_referrer] += _amount;
        return true;
    }

    function claimReferral() external {
        require(referrals[_msgSender()] > 0, "Nothing to claim");
        if(referrals[_msgSender()] < 50000){
            uSDT.transfer(_msgSender(), (referrals[_msgSender()]).div(100));
            aQR.transfer(_msgSender(), (referrals[_msgSender()]).mul(5).div(1000));
        }
        else if(referrals[_msgSender()] > 50000 && referrals[_msgSender()] <= 100000){
            uSDT.transfer(_msgSender(), (referrals[_msgSender()]).mul(2).div(100));
            aQR.transfer(_msgSender(), (referrals[_msgSender()]).div(100));
        }
        else if(referrals[_msgSender()] >= 100001 && referrals[_msgSender()] < 250000){
            uSDT.transfer(_msgSender(), (referrals[_msgSender()]).mul(25).div(1000));
            aQR.transfer(_msgSender(), (referrals[_msgSender()]).mul(15).div(1000));
        }
        else if(referrals[_msgSender()] >= 250000 ){
            uSDT.transfer(_msgSender(), (referrals[_msgSender()]).mul(3).div(100));
            aQR.transfer(_msgSender(), (referrals[_msgSender()]).mul(2).div(100));
        }
        referrals[msg.sender] = 0;
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


    function claimToken() external {
        require(cBalanceOf(_msgSender()) > 0,"Nothing to claim");
        // require(saleTimer < block.timestamp,"Time not finished yet");
        _balances[ _msgSender()] += _cBalance[_msgSender()];
        _cBalance[_msgSender()] = 0;
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
        IPropertyFactory propertyToken = IPropertyFactory(propertyFactory);
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