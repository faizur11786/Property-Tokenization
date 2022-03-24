// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract PropertyTokenization is Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => uint256) private _cBalance;

    mapping(address => mapping(address => uint256)) private _allowances;

    string public propetyName;
    string public propetySymbol;
    uint256 public propetyTotalSupply;
    uint256 public saleTimer;
    bool public saleState = false;
    address[] public holders;
    address[] public paymentMethods;


    event TokenTransfer(address indexed _from, address indexed _to, uint256 _value);
    event TokenApproval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor(string memory name_, string memory symbol_, uint256 totalSupply_) Ownable() {
        propetyName = name_;
        propetySymbol = symbol_;
        propetyTotalSupply = totalSupply_;
        _cBalance[address(this)] = totalSupply_;
        saleState = true;
    }

    function holdersLength() public view virtual returns (uint256){
        return holders.length;
    }

    function addPaymentMethod(address newPaymentMethod) public onlyOwner returns (bool success){
        require(newPaymentMethod != address(0), "Invalid address");
        for(uint256 i = 0; i < paymentMethodLength(); i++){
            require(paymentMethods[i] != newPaymentMethod, "Duplicate Payment Method");
        }
        paymentMethods.push(newPaymentMethod);
        return true;
    }

    function paymentMethodLength() public view virtual returns (uint256){
        return paymentMethods.length;
    }

    function updateSaleTimer(uint256 time) external onlyOwner{
        require(time > block.timestamp,"Time should be greater than now time");
        saleTimer = time;
    }

    function flipSaleState() external onlyOwner{
        saleState = !saleState;
    }

    function buyToken(uint256 _amount, address _buyWithToken ) public virtual returns (bool success){
        // require(saleTimer > block.timestamp,"Crowdsale is ended");
        require(_amount > 0 && _amount <= propetyTotalSupply, "Invalid amount");
        for(uint256 i = 0; i < paymentMethodLength(); i++){
            if(paymentMethods[i] == _buyWithToken){
                _transfercBalance(address(this), _msgSender(), _amount);
                return true;
            }
        }
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function cBalanceOf(address account) public view virtual returns (uint256) {
        return _cBalance[account];
    }


    function claimToken(uint256 _value) external {
        require(cBalanceOf(_msgSender()) > 0,"Nothing to claim");
        // require(saleTimer < block.timestamp,"Time not finished yet");
        _transfer(address(this), _msgSender(), _value);
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

    function _transfercBalance(address from, address to, uint256 value) internal {
        _cBalance[from] -= value;
        _cBalance[to] += value;
        emit TokenTransfer(from, to, value);
    }

    function _transfer(address from, address to, uint256 value) internal {
        _balances[from] -= value;
        _balances[to] += value;
        holders.push(to);
        emit TokenTransfer(from, to, value);
    }
}