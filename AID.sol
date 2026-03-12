// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

//USD3
contract AID is ERC20, Ownable2Step, ReentrancyGuard {
    mapping(address => bool) public feeExempt;
    mapping(address => bool) public swapPairs;
    mapping(address => bool) public whitelist;

    bool public pancakeTradingPaused;
    address public pancakePauseOperator;

    event OperatorRoleRevoked(address indexed operator, address indexed account, uint256 timestamp);
    event OperatorRoleGranted(address indexed operator, address indexed account, uint256 timestamp);
    event FeeExemptUpdated(address indexed account, bool status);
    event SwapPairUpdated(address indexed pair, bool status);
    event RTInitialized(address indexed owner, uint256 initialSupply, uint256 timestamp);
    event WhitelistUpdated(address indexed account, bool status);
    event RoleUpdated(address indexed newAdmin, address indexed oldAdmin);
    event PancakeTradingPaused(bool status);
    event PancakePauseOperatorUpdated(address indexed oldOperator, address indexed newOperator);

    constructor(uint256 initialSupply, address _feeWallet) ERC20("AID Token", "AID") Ownable(msg.sender) {
        uint256 mintAmount = initialSupply * 10 ** decimals();
        _mint(msg.sender, mintAmount);
        feeExempt[msg.sender] = true;
        feeExempt[_feeWallet] = true;

        emit RTInitialized(msg.sender, mintAmount, block.timestamp);
    }

    function setFeeExempt(address a, bool s) external onlyOwner {
        require(feeExempt[a] != s, "Value unchanged");
        feeExempt[a] = s;
        emit FeeExemptUpdated(a, s);
    }

    function setSwapPair(address pair, bool status) external onlyOwner {
        require(swapPairs[pair] != status, "Value unchanged");
        swapPairs[pair] = status;
        emit SwapPairUpdated(pair, status);
    }

    function addToWhitelist(address account, bool status) external onlyOwner {
        require(account != address(0), "Cannot whitelist zero address");
        require(whitelist[account] != status, "Value unchanged");

        whitelist[account] = status;
        emit WhitelistUpdated(account, status);
    }

    function setPancakePauseOperator(address operator) external onlyOwner {
        require(pancakePauseOperator != operator, "Value unchanged");
        address oldOperator = pancakePauseOperator;
        pancakePauseOperator = operator;
        emit PancakePauseOperatorUpdated(oldOperator, operator);
    }

    function setPancakeTradingPaused(bool status) external {
        require(_msgSender() == owner() || _msgSender() == pancakePauseOperator, "unauthorized");
        require(pancakeTradingPaused != status, "Value unchanged");
        pancakeTradingPaused = status;
        emit PancakeTradingPaused(status);
    }

    function transfer(address to, uint256 amount) public override nonReentrant returns (bool) {
        return _transferWithFee(_msgSender(), to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override nonReentrant returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        return _transferWithFee(from, to, amount);
    }

    function _transferWithFee(address from, address to, uint256 amount) internal returns (bool) {
        require(from != address(0) && to != address(0), "zero addr");
        uint256 fee = 0;
        bool sell = is_sell(to);
        bool buy = is_buy(from);

        if (pancakeTradingPaused && (sell || buy)) {
            revert("pancake trading paused");
        }

        if (sell && !isFeeExempt(from, to)) {
            require(whitelist[from], "not whitelisted");
        } else if (buy && !isFeeExempt(from, to)) {
            require(whitelist[to], "not whitelisted");
        }

        super._transfer(from, to, amount);

        return true;
    }

    function is_sell(address to) public view returns (bool) {
        return swapPairs[to];
    }

    function is_buy(address from) public view returns (bool) {
        return swapPairs[from];
    }

    function isFeeExempt(address from, address to) public view returns (bool) {
        return feeExempt[from] || feeExempt[to];
    }

    function burn(uint256 amount) external nonReentrant {
        require(amount > 0, "zero amount");
        _burn(_msgSender(), amount);
    }
}
