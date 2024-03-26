// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract CompoundTest is ERC20TaxRewardsTest {
    event Compound(address indexed addr, address indexed to, uint256 amount);

    function testTotalRewardCompoundedIncreases() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), allocation);
        token.allocate(vm.addr(2), allocation);

        startTrading(1000 ether);

        token.removeMaxWallet();

        distribute(2 ether);

        compound(1);

        assertEq(distributor.totalRewardCompounded(), 1 ether);

        compound(2);

        assertEq(distributor.totalRewardCompounded(), 2 ether);
    }

    function testCompoundSameShareSameTokens() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), allocation);
        token.allocate(vm.addr(2), allocation);

        startTrading(1000 ether);

        token.removeMaxWallet();

        distribute(2 ether);

        assertEq(pr(1), 1 ether);
        assertEq(pr(2), 1 ether);

        compound(1);
        compound(2);

        assertGt(bo(1), allocation);
        assertGt(bo(2), allocation);
        assertApproxEqRel(bo(1), bo(2), 0.01e18);
    }

    function testCompoundTwiceShareTwiceTokens() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), 1 * allocation);
        token.allocate(vm.addr(2), 2 * allocation);

        startTrading(1000 ether);

        token.removeMaxWallet();

        distribute(3 ether);

        assertEq(pr(1), 1 ether);
        assertEq(pr(2), 2 ether);

        compound(1);
        compound(2);

        assertGt(bo(1), allocation);
        assertGt(bo(2), allocation);
        assertApproxEqRel(2 * (bo(1) - allocation), bo(2) - (2 * allocation), 0.01e18);
    }

    function testCompoundEmits() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), allocation);
        token.allocate(vm.addr(2), allocation);

        startTrading(1000 ether);

        token.removeMaxWallet();

        distribute(2 ether);

        vm.expectEmit(true, true, true, true, address(distributor));

        emit Compound(vm.addr(1), vm.addr(1), 1 ether);

        compound(1);

        vm.expectEmit(true, true, true, true, address(distributor));

        emit Compound(vm.addr(2), vm.addr(2), 1 ether);

        compound(2);
    }
}
