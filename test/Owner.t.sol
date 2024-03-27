// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IDistributor} from "../src/IDistributor.sol";
import {Yeti} from "../src/Yeti.sol";

contract OwnerTest is Test {
    Yeti internal token;
    IERC20 internal rewardToken;
    IUniswapV2Pair internal pair;
    IDistributor internal distributor;

    function setUp() public {
        token = new Yeti();

        pair = token.pair();
        rewardToken = token.rewardToken();
        distributor = token.distributor();
    }

    function dealAndApprove(address addr, uint256 rewardTokenAmount) private {
        deal(address(rewardToken), addr, rewardTokenAmount);

        vm.prank(addr);

        rewardToken.approve(address(token), rewardTokenAmount);
    }

    function testInitialize() public {
        // initial total supply is 100M.
        assertEq(token.INITIAL_TOTAL_SUPPLY(), 100_000_000 ether);

        // theres 0 supply before initialize.
        assertEq(token.totalSupply(), 0);

        // non owner cant call initialize.
        vm.prank(vm.addr(1));

        vm.expectRevert();

        token.initialize();

        // owner can call initialize.
        token.initialize();

        // Owner cant call initialize twice.
        vm.expectRevert("!initialized");

        token.initialize();

        // total supply is now initial total supply.
        assertEq(token.totalSupply(), token.INITIAL_TOTAL_SUPPLY());
    }

    function testAllocate() public {
        // owner cant allocate before initialize.
        vm.expectRevert("!initialized");

        token.allocate(vm.addr(1), 1);

        // initialize the token.
        token.initialize();

        // non owner cant allocate.
        vm.prank(vm.addr(1));

        vm.expectRevert();

        token.allocate(vm.addr(1), 1);

        // owner can allocate some tokens.
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), 1 * allocation);
        token.allocate(vm.addr(2), 2 * allocation);
        token.allocate(vm.addr(3), 3 * allocation);

        assertEq(token.balanceOf(vm.addr(1)), 1 * allocation);
        assertEq(token.balanceOf(vm.addr(2)), 2 * allocation);
        assertEq(token.balanceOf(vm.addr(3)), 3 * allocation);
        assertEq(distributor.totalShares(), 6 * allocation);

        // start the trading.
        dealAndApprove(address(this), 1000 ether);

        token.startTrading(1000 ether);

        // owner can't allocate anymore.
        vm.expectRevert("!started");

        token.allocate(vm.addr(4), 1);

        // total shares ares still the same as before.
        assertEq(distributor.totalShares(), 6 * allocation);
    }

    function testStartTrading() public {
        // owner cant start trading before initialize.
        dealAndApprove(address(this), 1000 ether);

        vm.expectRevert("!initialized");

        token.startTrading(1000 ether);

        // initialize the token.
        token.initialize();

        // non owner cant start trading.
        dealAndApprove(vm.addr(1), 1000 ether);

        vm.prank(vm.addr(1));

        vm.expectRevert();

        token.startTrading(1000 ether);

        // allocate some to test.
        uint256 allocation = 10_000_000 ether;

        token.allocate(vm.addr(1), allocation);

        assertEq(distributor.totalShares(), allocation);

        // owner can start trading.
        token.startTrading(1000 ether);

        // owner cant start trading twice.
        vm.expectRevert("!started");

        token.startTrading(1000 ether);

        // max wallet is now set to 1% of total supply.
        assertEq(token.maxWallet(), token.totalSupply() / 100);

        // the token has zero tokens.
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(rewardToken.balanceOf(address(token)), 0);

        // the pair have all the tokens minus the allocations.
        assertEq(token.balanceOf(address(pair)), token.totalSupply() - allocation);
        assertEq(rewardToken.balanceOf(address(pair)), 1000 ether);

        // owner have all the lp tokens minus uniswap dust.
        assertApproxEqAbs(pair.balanceOf(address(this)), pair.totalSupply(), 1000);

        // total shares is the same as before.
        assertEq(distributor.totalShares(), allocation);
    }
}
