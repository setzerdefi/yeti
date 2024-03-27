// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Yeti} from "../src/Yeti.sol";

contract InitializeTest is Test {
    function testInitialize() public {
        Yeti token = new Yeti();

        // initial total supply is 100M.
        assertEq(token.INITIAL_TOTAL_SUPPLY(), 100_000_000 ether);

        // theres 0 supply before initialize.
        assertEq(token.totalSupply(), 0);

        // owner cant call allocate.
        vm.expectRevert("!initialized");

        token.allocate(vm.addr(1), 1_000_000 ether);

        // owner cant startTrading.
        vm.expectRevert("!initialized");

        token.startTrading(1000 ether);

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

        // owner can now allocate.
        token.allocate(vm.addr(1), 1_000_000 ether);

        // owner can now startTrading.
        IERC20 rewardToken = IERC20(token.rewardToken());

        deal(address(rewardToken), address(this), 1000 ether);
        rewardToken.approve(address(token), 1000 ether);

        token.startTrading(1000 ether);
    }
}
