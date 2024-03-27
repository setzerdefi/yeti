// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IDistributor} from "../src/IDistributor.sol";
import {Yeti} from "../src/Yeti.sol";

import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {IUniversalRouter} from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";

contract ERC20TaxRewardsTest is Test {
    IUniversalRouter universalRouter = IUniversalRouter(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD);

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

        token.initialize();
    }

    function bo(uint256 i) internal view returns (uint256) {
        return token.balanceOf(vm.addr(i));
    }

    function pr(uint256 i) internal view returns (uint256) {
        return distributor.pendingRewards(vm.addr(i));
    }

    function rbo(uint256 i) internal view returns (uint256) {
        return rewardToken.balanceOf(vm.addr(i));
    }

    function claim(uint256 i) internal {
        vm.prank(vm.addr(i));

        distributor.claim(vm.addr(i));
    }

    function compound(uint256 i) internal {
        vm.prank(vm.addr(i));

        distributor.compound(vm.addr(i), 0);
    }

    function emptyRewards(uint256 i) internal {
        uint256 balance = rewardToken.balanceOf(vm.addr(i));

        vm.prank(vm.addr(i));

        rewardToken.transfer(vm.addr(100), balance);
    }

    function donate(uint256 amount) internal {
        uint256 balance = rewardToken.balanceOf(address(distributor));

        deal(address(rewardToken), address(distributor), balance + amount);
    }

    function distribute(uint256 amount) internal {
        donate(amount);

        distributor.distribute(0);
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
        deal(address(rewardToken), addr, amountIn);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        address[] memory path = new address[](2);
        path[0] = address(rewardToken);
        path[1] = address(token);
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(addr, amountIn, 0, path, true);

        vm.startPrank(addr);
        rewardToken.approve(address(router), amountIn);
        universalRouter.execute(commands, inputs, block.timestamp);
        vm.stopPrank();
    }

    function sellToken(address addr, uint256 amountIn) internal {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(rewardToken);
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(addr, amountIn, 0, path, true);

        vm.startPrank(addr);
        token.approve(address(router), amountIn);
        universalRouter.execute(commands, inputs, block.timestamp);
        vm.stopPrank();
    }
}
