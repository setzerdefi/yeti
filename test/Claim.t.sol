// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract ClaimTest is ERC20TaxRewardsTest {
    event Claim(address indexed addr, address indexed to, uint256 amount);

    function testTotalRewardClaimedIncreases() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), allocation);
        token.allocate(vm.addr(2), allocation);

        distribute(2 ether);

        claim(1);

        assertEq(distributor.totalRewardClaimed(), 1 ether);

        claim(2);

        assertEq(distributor.totalRewardClaimed(), 2 ether);
    }

    function testClaimSameShareSameRewards() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), allocation);
        token.allocate(vm.addr(2), allocation);

        distribute(2 ether);

        assertEq(pr(1), 1 ether);
        assertEq(pr(2), 1 ether);

        claim(1);
        claim(2);

        assertEq(rbo(1), 1 ether);
        assertEq(rbo(2), 1 ether);
    }

    function testClaimTwiceShareTwiceRewards() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), 1 * allocation);
        token.allocate(vm.addr(2), 2 * allocation);

        distribute(3 ether);

        assertEq(pr(1), 1 ether);
        assertEq(pr(2), 2 ether);

        claim(1);
        claim(2);

        assertEq(rbo(1), 1 ether);
        assertEq(rbo(2), 2 ether);
    }

    function testClaimEmits() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), allocation);
        token.allocate(vm.addr(2), allocation);

        distribute(2 ether);

        vm.expectEmit(true, true, true, true, address(distributor));

        emit Claim(vm.addr(1), vm.addr(1), 1 ether);

        claim(1);

        vm.expectEmit(true, true, true, true, address(distributor));

        emit Claim(vm.addr(2), vm.addr(2), 1 ether);

        claim(2);
    }
}
