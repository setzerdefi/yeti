// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Yeti} from "../src/Yeti.sol";

contract InitializeTest is Test {
    function testInitialize() public {
        Yeti token = new Yeti();

        assertEq(token.totalSupply(), 0);
        assertEq(token.maxWallet(), type(uint256).max);
        assertEq(token.INITIAL_TOTAL_SUPPLY(), 100_000_000 ether);

        // non owner cant initialize.
        vm.prank(vm.addr(1));

        vm.expectRevert();

        token.initialize();

        // non owner can initialize.
        token.initialize();

        // owner cant initialize twice.
        vm.expectRevert("!initialized");

        token.initialize();

        assertEq(token.totalSupply(), token.INITIAL_TOTAL_SUPPLY());
        assertEq(token.maxWallet(), token.totalSupply() / 100);
        assertEq(token.balanceOf(address(this)), token.totalSupply());
    }
}
