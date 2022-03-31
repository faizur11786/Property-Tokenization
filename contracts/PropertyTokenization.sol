// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "hardhat/console.sol";


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


interface IPropertyNFT {
   function setBalanceFor(address, address) external ;
}


contract PropertyTokenization is Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => uint256) private _cBalance;

    mapping(address => mapping(address => uint256)) private _allowances;

    string public propetyName;
    string public propetySymbol;
    uint256 public tokenId;
    uint256 public propetyTotalSupply;
    uint256 public saleTimer;
    bool public saleState = false;
    address[] public holders;
    address public propertiesNFT;


    event TokenTransfer(address indexed _from, address indexed _to, uint256 _value);
    event TokenApproval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor(
        string memory _name, 
        string memory _symbol, 
        uint256 _totalSupply, 
        uint256 _tokenId,
        bool _saleState
    ) Ownable() {
        propetyName = _name;
        propetySymbol = _symbol;
        propetyTotalSupply = _totalSupply;
        _cBalance[address(this)] = _totalSupply;
        tokenId = _tokenId;
        saleState = _saleState;
        propertiesNFT = _msgSender();
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

    function buyToken(uint256 _amount, address _to, address _buyWithToken ) external virtual returns (bool success){
        // require(saleTimer > block.timestamp,"Crowdsale is ended");
        require(_amount > 0 && _amount <= propetyTotalSupply, "Invalid amount");
        IPropertyNFT propertyToken = IPropertyNFT(propertiesNFT);
        propertyToken.setBalanceFor(_to, address(this));
        _cBalance[address(this)] -= _amount;
        _cBalance[_to] += _amount;
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
}