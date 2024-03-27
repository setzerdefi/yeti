// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {IUniversalRouter} from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ERC20TaxRewardsSetup} from "./ERC20TaxRewardsSetup.sol";

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

contract ERC20TaxRewardsTest is ERC20TaxRewardsSetup {
    IPermit2 private constant permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IUniversalRouter private constant universalRouter = IUniversalRouter(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD);
    IUniswapV2Router02 private constant routerV2 = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);

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

    function allocate(address addr, uint256 amount) internal {
        token.transfer(addr, amount);
    }

    function startTrading(uint256 rewardTokenAmount) internal {
        addLiquidity(address(this), token.balanceOf(address(this)), rewardTokenAmount);
    }

    function addLiquidity(address addr, uint256 amountTokenDesired, uint256 amountRewardTokenDesired) internal {
        deal(address(rewardToken), addr, amountRewardTokenDesired);

        vm.startPrank(addr);
        token.approve(address(routerV2), amountTokenDesired);
        rewardToken.approve(address(routerV2), amountRewardTokenDesired);
        routerV2.addLiquidity(
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
        pair.approve(address(routerV2), liquidity);
        routerV2.removeLiquidity(address(token), address(rewardToken), liquidity, 0, 0, addr, block.timestamp);
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
        rewardToken.approve(address(permit2), amountIn);
        permit2.approve(address(rewardToken), address(universalRouter), uint160(amountIn), type(uint48).max);
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
        token.approve(address(permit2), amountIn);
        permit2.approve(address(token), address(universalRouter), uint160(amountIn), type(uint48).max);
        universalRouter.execute(commands, inputs, block.timestamp);
        vm.stopPrank();
    }
}
