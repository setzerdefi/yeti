// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract ERC20TaxRewards is Ownable, ERC20, ERC20Burnable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    // =========================================================================
    // starting total supply (can be burned).
    // =========================================================================

    uint256 public constant TOTAL_SUPPLY = 100_000_000 ether;

    // =========================================================================
    // dependencies.
    // =========================================================================

    IUniswapV2Router02 public constant router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IERC20Metadata public constant rewardToken = IERC20Metadata(0x77E06c9eCCf2E797fd462A92B6D7642EF85b0A44);

    // =========================================================================
    // trading.
    // =========================================================================

    uint256 public startBlock;

    IUniswapV2Pair public immutable pair;

    // =========================================================================
    // rewards management.
    // =========================================================================

    struct Share {
        uint256 amount;
        uint256 earned;
        uint256 tokenPerShareLast;
    }

    uint256 private constant PRECISION = 1e18;
    uint256 private immutable SCALE_FACTOR;

    uint256 public totalShares;

    mapping(address => Share) private shareholders;

    uint256 private tokenPerShare;
    uint256 public totalRewardClaimed;
    uint256 public totalRewardCompounded;
    uint256 public totalRewardDistributed;

    // =========================================================================
    // operator values.
    // =========================================================================

    address public operator;

    uint256 public maxWallet = type(uint256).max;

    uint24 public constant maxSwapFee = 500;
    uint24 public constant feeDenominator = 10000;

    uint24 public buyFee = 500;
    uint24 public sellFee = 500;

    // =========================================================================
    // events.
    // =========================================================================

    event Claim(address indexed addr, address indexed to, uint256 amount);
    event Compound(address indexed addr, address indexed to, uint256 amount);
    event Distribute(address indexed addr, uint256 amount);
    event Sweep(address indexed addr, address indexed token, uint256 amount);

    // =========================================================================
    // modifiers.
    // =========================================================================

    modifier onlyOperator() {
        require(msg.sender == operator, "!operator");
        _;
    }

    // =========================================================================
    // constructor.
    // =========================================================================

    constructor(string memory name, string memory symbol) Ownable(msg.sender) ERC20(name, symbol) {
        operator = msg.sender;

        uint8 rewardTokenDecimals = rewardToken.decimals();

        require(rewardTokenDecimals <= 18, "!decimals");

        SCALE_FACTOR = 10 ** (18 - rewardTokenDecimals);

        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());

        pair = IUniswapV2Pair(factory.createPair(address(rewardToken), address(this)));

        _mint(address(this), TOTAL_SUPPLY);
    }

    // =========================================================================
    // exposed contract values.
    // =========================================================================

    function pendingRewards(address addr) external view returns (uint256) {
        return _pendingRewards(shareholders[addr]);
    }

    // =========================================================================
    // exposed user functions.
    // =========================================================================

    function claim(address to) external nonReentrant {
        Share storage share = shareholders[msg.sender];

        uint256 amountToClaim = _earn(share);

        share.earned = 0;

        if (amountToClaim == 0) return;

        totalRewardClaimed += amountToClaim;

        rewardToken.safeTransfer(to, amountToClaim);

        emit Claim(msg.sender, to, amountToClaim);
    }

    function compound(address to, uint256 amountOutMin) external nonReentrant {
        Share storage share = shareholders[msg.sender];

        uint256 amountToCompound = _earn(share);

        share.earned = 0;

        if (amountToCompound == 0) return;

        totalRewardCompounded += amountToCompound;

        _swapRewardTokenForToken(to, amountToCompound, amountOutMin);

        emit Compound(msg.sender, to, amountToCompound);
    }

    function distribute(uint256 amountOutMin) public {
        if (totalShares == 0) return;

        uint256 collectedTaxAmount = balanceOf(address(this));

        if (collectedTaxAmount == 0) return;

        _swapTokenForRewardToken(address(this), collectedTaxAmount, amountOutMin);

        uint256 amountToDistribute = balanceOf(address(rewardToken));

        if (amountToDistribute == 0) return;

        tokenPerShare += (amountToDistribute * SCALE_FACTOR * PRECISION) / totalShares;

        totalRewardDistributed += amountToDistribute;

        emit Distribute(msg.sender, amountToDistribute);
    }

    function sweep(IERC20Metadata otherToken) external {
        require(address(otherToken) != address(this), "!sweep");
        require(address(otherToken) != address(rewardToken), "!sweep");

        uint256 amount = otherToken.balanceOf(address(this));

        otherToken.safeTransfer(msg.sender, amount);

        emit Sweep(msg.sender, address(otherToken), amount);
    }

    // =========================================================================
    // exposed admin functions.
    // =========================================================================

    function allocate(address to, uint256 amount) external onlyOwner {
        require(startBlock == 0, "!initialized");

        this.transfer(to, amount);
    }

    function initialize(uint256 rewardTokenAmount) external onlyOwner {
        require(startBlock == 0, "!initialized");
        require(rewardTokenAmount > 0, "!liquidity");

        startBlock = block.number;

        maxWallet = totalSupply() / 100;

        uint256 tokenAmount = balanceOf(address(this));

        rewardToken.safeTransferFrom(msg.sender, address(this), rewardTokenAmount);

        _approve(address(this), address(router), tokenAmount);
        _approve(address(rewardToken), address(router), rewardTokenAmount);

        router.addLiquidity(
            address(this), address(rewardToken), tokenAmount, rewardTokenAmount, 0, 0, msg.sender, block.timestamp
        );
    }

    // =========================================================================
    // exposed operator functions.
    // =========================================================================

    function setOperator(address _operator) external onlyOperator {
        require(address(0) != _operator, "!address");
        operator = _operator;
    }

    function setFee(uint24 _buyFee, uint24 _sellFee) external onlyOperator {
        require(_buyFee <= maxSwapFee, "!buyFee");
        require(_sellFee <= maxSwapFee, "!sellFee");

        buyFee = _buyFee;
        sellFee = _sellFee;
    }

    function removeMaxWallet() external onlyOperator {
        maxWallet = type(uint256).max;
    }

    // =========================================================================
    // internal functions.
    // =========================================================================

    function _isExcludedFromTaxes(address addr) private view returns (bool) {
        return address(this) == addr || address(router) == addr;
    }

    function _isExcludedFromMaxWallet(address addr) private view returns (bool) {
        return address(this) == addr || address(router) == addr || address(pair) == addr;
    }

    function _isExcludedFromRewards(address addr) private view returns (bool) {
        return address(this) == addr || address(router) == addr || address(pair) == addr || address(0) == addr
            || 0x000000000000000000000000000000000000dEaD == addr;
    }

    function _pendingRewards(Share memory share) private view returns (uint256) {
        uint256 RDiff = tokenPerShare - share.tokenPerShareLast;
        uint256 earned = (share.amount * RDiff) / (SCALE_FACTOR * PRECISION);

        return share.earned + earned;
    }

    function _earn(Share storage share) private returns (uint256) {
        uint256 pending = _pendingRewards(share);

        share.earned = pending;
        share.tokenPerShareLast = tokenPerShare;

        return pending;
    }

    function _update(address from, address to, uint256 amount) internal override {
        bool isTaxedBuy = address(pair) == from && !_isExcludedFromTaxes(to);
        bool isTaxedSell = !_isExcludedFromTaxes(from) && address(pair) == to;

        uint256 fee = (isTaxedBuy ? buyFee : 0) + (isTaxedSell ? sellFee : 0);
        uint256 taxAmount = (amount * fee) / feeDenominator;
        uint256 actualTransferAmount = amount - taxAmount;

        if (taxAmount > 0) {
            super._update(from, address(this), taxAmount);
        }

        if (isTaxedSell) {
            distribute(0);
        }

        super._update(from, to, actualTransferAmount);

        _updateShare(to);
        _updateShare(from);

        if (!_isExcludedFromMaxWallet(to)) {
            require(balanceOf(to) <= maxWallet, "!maxWallet");
        }
    }

    function _updateShare(address addr) private {
        if (_isExcludedFromRewards(addr)) return;

        uint256 balance = balanceOf(addr);

        Share storage share = shareholders[addr];

        totalShares = totalShares + balance - share.amount;

        _earn(share);

        share.amount = balance;
    }

    function _swapTokenForRewardToken(address to, uint256 amountIn, uint256 amountOutMin) private {
        if (amountIn == 0) return;

        _approve(address(this), address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(rewardToken);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, block.timestamp);
    }

    function _swapRewardTokenForToken(address to, uint256 amountIn, uint256 amountOutMin) private {
        if (amountIn == 0) return;

        _approve(address(this), address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(rewardToken);
        path[1] = address(this);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, block.timestamp);
    }
}
