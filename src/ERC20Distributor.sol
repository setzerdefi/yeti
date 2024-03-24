// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ERC20TaxRewards} from "./ERC20TaxRewards.sol";
import {IDistributor} from "./IDistributor.sol";

contract ERC20Distributor is IDistributor {
    using SafeERC20 for IERC20Metadata;

    // =========================================================================
    // dependencies.
    // =========================================================================

    ERC20TaxRewards public immutable token;
    IUniswapV2Router02 public immutable router;
    IERC20Metadata public immutable rewardToken;

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
    // constructor.
    // =========================================================================

    constructor(ERC20TaxRewards _token, IUniswapV2Router02 _router, IERC20Metadata _rewardToken) {
        token = _token;
        router = _router;
        rewardToken = _rewardToken;

        uint8 rewardTokenDecimals = _rewardToken.decimals();

        require(rewardTokenDecimals <= 18, "!decimals");

        SCALE_FACTOR = 10 ** (18 - rewardTokenDecimals);
    }

    // =========================================================================
    // exposed user functions.
    // =========================================================================

    function pendingRewards(address addr) external view returns (uint256) {
        return _pendingRewards(shareholders[addr]);
    }

    function claim(address to) external {
        Share storage share = shareholders[msg.sender];

        uint256 amountToClaim = _earn(share);

        share.earned = 0;

        if (amountToClaim == 0) return;

        totalRewardClaimed += amountToClaim;

        rewardToken.safeTransfer(to, amountToClaim);

        emit Claim(msg.sender, to, amountToClaim);
    }

    function compound(address to, uint256 amountOutMin) external {
        Share storage share = shareholders[msg.sender];

        uint256 amountToCompound = _earn(share);

        share.earned = 0;

        if (amountToCompound == 0) return;

        totalRewardCompounded += amountToCompound;

        _swapRewardTokenForToken(to, amountToCompound, amountOutMin);

        emit Compound(msg.sender, to, amountToCompound);
    }

    function distribute(uint256 amountOutMin) external {
        if (totalShares == 0) return;

        uint256 collectedTaxAmount = token.balanceOf(address(this));
        uint256 originalRewardBalance = rewardToken.balanceOf(address(this));

        // take the donation to the contract into account.
        // balance - amount to claim is the amount of donations to the contract.
        uint256 amountToClaim = totalRewardDistributed - totalRewardClaimed - totalRewardCompounded;
        uint256 amountToDistribute = originalRewardBalance - amountToClaim;

        if (collectedTaxAmount > 0) {
            _swapTokenForRewardToken(address(this), collectedTaxAmount, amountOutMin);

            amountToDistribute += (rewardToken.balanceOf(address(this)) - originalRewardBalance);
        }

        if (amountToDistribute == 0) return;

        tokenPerShare += (amountToDistribute * SCALE_FACTOR * PRECISION) / totalShares;

        totalRewardDistributed += amountToDistribute;

        emit Distribute(msg.sender, amountToDistribute);
    }

    function updateShare(address addr) external {
        if (token.isExcludedFromRewards(addr)) return;

        Share storage share = shareholders[addr];

        _earn(share);

        uint256 balance = token.balanceOf(addr);

        totalShares = totalShares + balance - share.amount;
        share.amount = balance;
    }

    // =========================================================================
    // internal functions.
    // =========================================================================

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

    function _swapTokenForRewardToken(address to, uint256 amountIn, uint256 amountOutMin) private {
        _swap(address(token), address(rewardToken), to, amountIn, amountOutMin);
    }

    function _swapRewardTokenForToken(address to, uint256 amountIn, uint256 amountOutMin) private {
        _swap(address(rewardToken), address(token), to, amountIn, amountOutMin);
    }

    function _swap(address tokenA, address tokenB, address to, uint256 amountIn, uint256 amountOutMin) private {
        if (amountIn == 0) return;

        IERC20Metadata(tokenA).approve(address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, block.timestamp);
    }
}
