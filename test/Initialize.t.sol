// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract InitializeTest is ERC20TaxRewardsTest {
    function testInitialize() public {
        // max wallet is infinite.
        assertEq(token.maxWallet(), type(uint256).max);

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
        assertEq(distributor.totalShares(), 3 * allocation);

        // initialize liquidity and send lp tokens to owner.
        initialize(1000 ether);

        assertEq(token.maxWallet(), token.TOTAL_SUPPLY() / 100);
        assertEq(token.balanceOf(address(pair)), token.TOTAL_SUPPLY() - (3 * allocation));
        assertEq(rewardToken.balanceOf(address(pair)), 1000 ether);
        assertApproxEqAbs(pair.totalSupply(), pair.balanceOf(address(this)), 1000);
        assertEq(distributor.totalShares(), 3 * allocation);

        // can't allocate anymore.
        vm.expectRevert("!initialized");

        token.allocate(vm.addr(4), allocation);
    }
}
