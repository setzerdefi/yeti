// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {Yeti} from "../src/Yeti.sol";

contract YetiTest is Test {
    Yeti internal token;
    IUniswapV2Pair internal pair;
    IUniswapV2Router02 internal router;
    IERC20Metadata internal rewardToken;

    function setUp() public {
        token = new Yeti();

        pair = token.pair();
        router = token.router();
        rewardToken = token.rewardToken();
    }

    function testInitialize() public {
        // token has all the initial supply.
        assertEq(token.balanceOf(address(token)), token.TOTAL_SUPPLY());

        // tokens can be allocated before.
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), allocation);
        token.allocate(vm.addr(2), allocation);
        token.allocate(vm.addr(3), allocation);

        assertEq(token.balanceOf(vm.addr(1)), allocation);
        assertEq(token.balanceOf(vm.addr(2)), allocation);
        assertEq(token.balanceOf(vm.addr(3)), allocation);

        // initialize liquidity and send lp tokens to owner.
        uint256 rewardTokenAmount = 1000 ether;

        deal(address(rewardToken), address(this), rewardTokenAmount);

        rewardToken.approve(address(token), rewardTokenAmount);

        token.initialize(rewardTokenAmount);

        assertEq(token.maxWallet(), token.TOTAL_SUPPLY() / 100);
        assertEq(token.balanceOf(address(pair)), token.TOTAL_SUPPLY() - (3 * allocation));
        assertEq(rewardToken.balanceOf(address(pair)), rewardTokenAmount);
        assertApproxEqAbs(pair.totalSupply(), pair.balanceOf(address(this)), 1000);

        // can't allocate anymore.
        vm.expectRevert("!initialized");

        token.allocate(vm.addr(4), allocation);
    }
}
