// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";
import {IDistributor} from "../src/IDistributor.sol";
import {DummyDistributor} from "../src/DummyDistributor.sol";

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

    function testSetDistributor() public {
        // deploy dummy distributor.
        IDistributor distributor = new DummyDistributor();

        // set an operator.
        token.setOperator(vm.addr(1));

        assertEq(token.operator(), vm.addr(1));

        // owner cant set distributor.
        vm.expectRevert();

        token.setDistributor(distributor);

        // non operator cant set distributor.
        vm.prank(vm.addr(2));

        vm.expectRevert();

        token.setDistributor(distributor);

        // zero address reverts.
        vm.prank(vm.addr(1));

        vm.expectRevert("!address");

        token.setDistributor(IDistributor(address(0)));

        // operator can set distributor.
        vm.prank(vm.addr(1));

        token.setDistributor(distributor);

        assertEq(address(token.distributor()), address(distributor));
    }

    function testRemoveMaxWallet() public {
        // at first max wallet is infinite.
        assertEq(token.maxWallet(), type(uint256).max);

        // initialize the pool.
        initialize(1000 ether);

        // after initilization, max wallet is 1% of the supply.
        assertEq(token.maxWallet(), token.totalSupply() / 100);

        // set an operator.
        token.setOperator(vm.addr(1));

        assertEq(token.operator(), vm.addr(1));

        // owner cant remove max wallet.
        vm.expectRevert();

        token.removeMaxWallet();

        // non operator cant remove max wallet.
        vm.prank(vm.addr(2));

        vm.expectRevert();

        token.removeMaxWallet();

        // operator can remove max wallet.
        vm.prank(vm.addr(1));

        token.removeMaxWallet();

        assertEq(token.maxWallet(), type(uint256).max);
    }
}
