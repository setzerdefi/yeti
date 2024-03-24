// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IDistributor} from "../src/IDistributor.sol";
import {Yeti} from "../src/Yeti.sol";

contract ERC20TaxRewardsTest is Test {
    Yeti internal token;
    IUniswapV2Pair internal pair;
    IUniswapV2Router02 internal router;
    IERC20 internal rewardToken;
    IDistributor internal distributor;

    function setUp() public {
        token = new Yeti();

        pair = token.pair();
        router = token.router();
        rewardToken = token.rewardToken();
        distributor = token.distributor();
    }

    function startTrading(uint256 rewardTokenAmount) internal {
        deal(address(rewardToken), address(this), rewardTokenAmount);

        rewardToken.approve(address(token), rewardTokenAmount);

        token.startTrading(rewardTokenAmount);
    }

    function addLiquidity(address addr, uint256 amountTokenDesired, uint256 amountRewardTokenDesired) internal {
        deal(address(rewardToken), addr, amountRewardTokenDesired);

        vm.startPrank(addr);
        token.approve(address(router), amountTokenDesired);
        rewardToken.approve(address(router), amountRewardTokenDesired);
        router.addLiquidity(
            address(token),
            address(rewardToken),
            amountTokenDesired,
            amountRewardTokenDesired,
            0,
            0,
            addr,
            block.timestamp
        );
        vm.stopPrank();
    }

    function removeLiquidity(address addr) internal {
        uint256 liquidity = pair.balanceOf(addr);

        vm.startPrank(addr);
        pair.approve(address(router), liquidity);
        router.removeLiquidity(address(token), address(rewardToken), liquidity, 0, 0, addr, block.timestamp);
        vm.stopPrank();
    }

    function buyToken(address addr, uint256 amountIn) internal {
        address[] memory path = new address[](2);
        path[0] = address(rewardToken);
        path[1] = address(token);

        deal(address(rewardToken), addr, amountIn);

        vm.startPrank(addr);
        rewardToken.approve(address(router), amountIn);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, 0, path, addr, block.timestamp);
        vm.stopPrank();
    }

    function sellToken(address addr, uint256 amountIn) internal {
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(rewardToken);

        vm.startPrank(addr);
        token.approve(address(router), amountIn);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, 0, path, addr, block.timestamp);
        vm.stopPrank();
    }
}
