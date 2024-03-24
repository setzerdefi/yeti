// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract OperatorTest is ERC20TaxRewardsTest {
    function testSetOperator() public {
        // by default operator is owner.
        assertEq(token.operator(), address(this));

        // set an operator.
        token.setOperator(vm.addr(1));

        assertEq(token.operator(), vm.addr(1));

        // owner now reverts.
        vm.expectRevert("!operator");

        token.setOperator(vm.addr(3));

        // user reverts.
        vm.prank(vm.addr(2));

        vm.expectRevert("!operator");

        token.setOperator(vm.addr(3));

        // zero address reverts.
        vm.prank(vm.addr(1));

        vm.expectRevert("!address");

        token.setOperator(address(0));

        // operator can set operator.
        vm.prank(vm.addr(1));

        token.setOperator(vm.addr(2));

        assertEq(token.operator(), vm.addr(2));
    }

    function testSetFee() public {
        // by default fees are 24%.
        assertEq(token.buyFee(), 2400);
        assertEq(token.sellFee(), 2400);

        // max fees are 5%.
        uint24 maxSwapFee = token.maxSwapFee();

        assertEq(maxSwapFee, 500);

        // set an operator.
        token.setOperator(vm.addr(1));

        assertEq(token.operator(), vm.addr(1));

        // owner cant set fee.
        vm.expectRevert("!operator");

        token.setFee(200, 300);

        // non operator cant set fee.
        vm.prank(vm.addr(2));

        vm.expectRevert("!operator");

        token.setFee(200, 300);

        // operator can set fee.
        vm.prank(vm.addr(1));

        token.setFee(200, 300);

        assertEq(token.buyFee(), 200);
        assertEq(token.sellFee(), 300);

        // operator can set buy fee up to max swap fee.
        vm.prank(vm.addr(1));

        token.setFee(maxSwapFee, 300);

        assertEq(token.buyFee(), maxSwapFee);
        assertEq(token.sellFee(), 300);

        vm.prank(vm.addr(1));

        vm.expectRevert("!buyFee");

        token.setFee(maxSwapFee + 1, 300);

        // operator can set sell fee up to max swap fee.
        vm.prank(vm.addr(1));

        token.setFee(200, maxSwapFee);

        assertEq(token.buyFee(), 200);
        assertEq(token.sellFee(), maxSwapFee);

        vm.prank(vm.addr(1));

        vm.expectRevert("!sellFee");

        token.setFee(200, maxSwapFee + 1);

        // cant sell buy or sell fee after _emergencyDisableRewards has been called.
        vm.prank(vm.addr(1));

        token._emergencyDisableRewards();

        vm.prank(vm.addr(1));

        vm.expectRevert("!rewards");

        token.setFee(200, 0);

        vm.prank(vm.addr(1));

        vm.expectRevert("!rewards");

        token.setFee(0, 300);
    }

    function testRemoveMaxWallet() public {
        // by default max wallet is infinite.
        assertEq(token.maxWallet(), type(uint256).max);

        // initialize the lp.
        startTrading(1000 ether);

        // after initilization, max wallet is 1% of the supply.
        assertEq(token.maxWallet(), token.totalSupply() / 100);

        // set an operator.
        token.setOperator(vm.addr(1));

        assertEq(token.operator(), vm.addr(1));

        // owner cant remove max wallet.
        vm.expectRevert("!operator");

        token.removeMaxWallet();

        // non operator cant remove max wallet.
        vm.prank(vm.addr(2));

        vm.expectRevert("!operator");

        token.removeMaxWallet();

        // operator can remove max wallet.
        vm.prank(vm.addr(1));

        token.removeMaxWallet();

        assertEq(token.maxWallet(), type(uint256).max);
    }

    function testEmergencyDisableRewards() public {
        // by default rewards are enabled.
        assertTrue(token.rewardsEnabled());

        // by default theres fee.
        assertGt(token.buyFee(), 0);
        assertGt(token.sellFee(), 0);

        // set an operator.
        token.setOperator(vm.addr(1));

        assertEq(token.operator(), vm.addr(1));

        // owner cant disable rewards.
        vm.expectRevert("!operator");

        token._emergencyDisableRewards();

        // user cant disable rewards.
        vm.prank(vm.addr(2));

        vm.expectRevert("!operator");

        token._emergencyDisableRewards();

        // operator can disable rewards.
        vm.prank(vm.addr(1));

        token._emergencyDisableRewards();

        // now rewards are disabled.
        assertFalse(token.rewardsEnabled());

        // theres no more fees.
        assertEq(token.buyFee(), 0);
        assertEq(token.sellFee(), 0);
    }
}
