// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract OwnerTest is ERC20TaxRewardsTest {
    function testSetFee() public {
        // by default fees are 24%.
        assertEq(token.buyFee(), 2400);
        assertEq(token.sellFee(), 2400);

        // max fees are 5%.
        uint24 maxSwapFee = token.maxSwapFee();

        assertEq(maxSwapFee, 500);

        // non operator cant set fee.
        vm.prank(vm.addr(1));

        vm.expectRevert();

        token.setFee(200, 300);

        // owner can set fee.
        token.setFee(200, 300);

        assertEq(token.buyFee(), 200);
        assertEq(token.sellFee(), 300);

        // owner can set buy fee up to max swap fee.
        token.setFee(maxSwapFee, 300);

        assertEq(token.buyFee(), maxSwapFee);
        assertEq(token.sellFee(), 300);

        vm.expectRevert("!buyFee");

        token.setFee(maxSwapFee + 1, 300);

        // owner can set sell fee up to max swap fee.
        token.setFee(200, maxSwapFee);

        assertEq(token.buyFee(), 200);
        assertEq(token.sellFee(), maxSwapFee);

        vm.expectRevert("!sellFee");

        token.setFee(200, maxSwapFee + 1);
    }

    function testRemoveMaxWallet() public {
        // after initialization max wallet is 1% of the supply.
        assertEq(token.maxWallet(), token.totalSupply() / 100);

        // non owner cant remove max wallet.
        vm.prank(vm.addr(1));

        vm.expectRevert();

        token.removeMaxWallet();

        // owner can remove max wallet.
        token.removeMaxWallet();

        assertEq(token.maxWallet(), type(uint256).max);
    }

    function testEmergencyDisableRewards() public {
        // after initialization rewards are enabled.
        assertTrue(token.rewardsEnabled());

        // user cant disable rewards.
        vm.prank(vm.addr(1));

        vm.expectRevert();

        token._emergencyDisableRewards();

        // owner can disable rewards.
        token._emergencyDisableRewards();

        // now rewards are disabled.
        assertFalse(token.rewardsEnabled());

        // theres no more fees.
        assertEq(token.buyFee(), 0);
        assertEq(token.sellFee(), 0);

        // fees cant be set anymore.
        vm.expectRevert("!rewards");

        token.setFee(200, 0);

        vm.expectRevert("!rewards");

        token.setFee(0, 300);
    }
}
