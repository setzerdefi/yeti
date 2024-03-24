// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract OwnerTest is ERC20TaxRewardsTest {
    function testInitialSupply() public view {
        assertEq(token.totalSupply(), token.INITIAL_TOTAL_SUPPLY());
        assertEq(token.balanceOf(address(token)), token.INITIAL_TOTAL_SUPPLY());
    }

    function testAllocate() public {
        // non owner cant allocate.
        vm.prank(vm.addr(1));

        vm.expectRevert();

        token.allocate(vm.addr(1), 1);

        // tokens can be allocated before trading started.
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), 1 * allocation);
        token.allocate(vm.addr(2), 2 * allocation);
        token.allocate(vm.addr(3), 3 * allocation);

        assertEq(token.balanceOf(vm.addr(1)), 1 * allocation);
        assertEq(token.balanceOf(vm.addr(2)), 2 * allocation);
        assertEq(token.balanceOf(vm.addr(3)), 3 * allocation);
        assertEq(distributor.totalShares(), 6 * allocation);

        // initialize the lp.
        startTrading(1000 ether);

        // can't allocate anymore.
        vm.expectRevert("!started");

        token.allocate(vm.addr(4), 1);
    }

    function testStartTrading() public {
        // allocate tokens.
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), 1 * allocation);
        token.allocate(vm.addr(2), 2 * allocation);
        token.allocate(vm.addr(3), 3 * allocation);

        assertEq(token.balanceOf(vm.addr(1)), 1 * allocation);
        assertEq(token.balanceOf(vm.addr(2)), 2 * allocation);
        assertEq(token.balanceOf(vm.addr(3)), 3 * allocation);
        assertEq(distributor.totalShares(), 6 * allocation);

        // non owner cant start trading.
        vm.prank(vm.addr(1));

        vm.expectRevert();

        token.startTrading(1000 ether);

        // start trading.
        startTrading(1000 ether);

        // max wallet is set to 1% of total supply.
        assertEq(token.maxWallet(), token.totalSupply() / 100);

        // the pair have all the tokens minus the allocations.
        assertEq(token.balanceOf(address(pair)), token.totalSupply() - (6 * allocation));

        // the pair have all the send ethers.
        assertEq(rewardToken.balanceOf(address(pair)), 1000 ether);

        // owner have all the lp tokens minus uniswap dust.
        assertApproxEqAbs(pair.balanceOf(address(this)), pair.totalSupply(), 1000);

        // total shares is the same as before.
        assertEq(distributor.totalShares(), 6 * allocation);

        // cant start trading a second time.
        vm.expectRevert("!started");

        token.startTrading(1000 ether);
    }
}
