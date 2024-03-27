// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IDistributor} from "./IDistributor.sol";
import {ERC20Distributor} from "./ERC20Distributor.sol";

contract ERC20TaxRewards is Ownable, ERC20, ERC20Burnable {
    using SafeERC20 for IERC20Metadata;

    // =========================================================================
    // dependencies.
    // =========================================================================

    IUniswapV2Factory public constant factory = IUniswapV2Factory(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6);
    IUniswapV2Router02 public constant router = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
    IERC20Metadata public constant rewardToken = IERC20Metadata(0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22); // cbETH
    IDistributor public distributor;

    // =========================================================================
    // trading.
    // =========================================================================

    uint256 public startBlock;
    uint256 public initializeBlock;

    IUniswapV2Pair public immutable pair;

    // =========================================================================
    // operator values.
    // =========================================================================

    address public operator;

    uint256 public maxWallet = type(uint256).max;

    uint24 public constant maxSwapFee = 500;
    uint24 public constant feeDenominator = 10000;

    // fee above the maxSwapFee for the launch.
    // once below maxSwap fee you cant go back above.
    uint24 public buyFee = 2400;
    uint24 public sellFee = 2400;

    // can disable rewards mechanism in case of a problem.
    // can't be reenabled after operator calling _emergencyDisableRewards().
    bool public rewardsEnabled = true;

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

        pair = IUniswapV2Pair(factory.createPair(address(rewardToken), address(this)));

        distributor = new ERC20Distributor(this, rewardToken);
    }

    // =========================================================================
    // exposed admin functions.
    // =========================================================================

    function allocate(address to, uint256 amount) external onlyOwner {
        require(startBlock == 0, "!started");
        require(initializeBlock > 0, "!initialized");

        this.transfer(to, amount);
    }

    function startTrading(uint256 rewardTokenAmount) external onlyOwner {
        require(startBlock == 0, "!started");
        require(initializeBlock > 0, "!initialized");
        require(rewardTokenAmount > 0, "!liquidity");

        startBlock = block.number;

        maxWallet = totalSupply() / 100;

        uint256 tokenAmount = balanceOf(address(this));

        rewardToken.safeTransferFrom(msg.sender, address(this), rewardTokenAmount);

        this.approve(address(router), tokenAmount);
        rewardToken.approve(address(router), rewardTokenAmount);

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
        require(rewardsEnabled, "!rewards");
        require(_buyFee <= maxSwapFee, "!buyFee");
        require(_sellFee <= maxSwapFee, "!sellFee");

        buyFee = _buyFee;
        sellFee = _sellFee;
    }

    function removeMaxWallet() external onlyOperator {
        maxWallet = type(uint256).max;
    }

    function _emergencyDisableRewards() external onlyOperator {
        buyFee = 0;
        sellFee = 0;
        rewardsEnabled = false;
    }

    // =========================================================================
    // public functions.
    // =========================================================================

    function isExcludedFromTaxes(address addr) public view returns (bool) {
        return address(this) == addr || address(distributor) == addr;
    }

    function isExcludedFromMaxWallet(address addr) public view returns (bool) {
        return isExcludedFromTaxes(addr) || address(pair) == addr;
    }

    function isExcludedFromRewards(address addr) public view returns (bool) {
        return isExcludedFromMaxWallet(addr) || address(0) == addr || 0x000000000000000000000000000000000000dEaD == addr;
    }

    // =========================================================================
    // implement taxes.
    // =========================================================================

    function _update(address from, address to, uint256 amount) internal override {
        bool isTaxedBuy = address(pair) == from && !isExcludedFromTaxes(to);
        bool isTaxedSell = !isExcludedFromTaxes(from) && address(pair) == to;

        uint256 fee = (isTaxedBuy ? buyFee : 0) + (isTaxedSell ? sellFee : 0);
        uint256 taxAmount = (amount * fee) / feeDenominator;
        uint256 actualTransferAmount = amount - taxAmount;

        if (taxAmount > 0) {
            super._update(from, address(distributor), taxAmount);
        }

        if (rewardsEnabled && isTaxedSell) {
            distributor.distribute(0);
        }

        super._update(from, to, actualTransferAmount);

        if (rewardsEnabled) {
            distributor.updateShare(to);
            distributor.updateShare(from);
        }

        if (!isExcludedFromMaxWallet(to)) {
            require(balanceOf(to) <= maxWallet, "!maxWallet");
        }
    }
}
