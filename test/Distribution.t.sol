// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract DistributionTest is ERC20TaxRewardsTest {
    event Claim(address indexed addr, address indexed to, uint256 amount);
    event Compound(address indexed addr, address indexed to, uint256 amount);
    event Distribute(address indexed addr, uint256 amount);

    function bo(uint256 i) private view returns (uint256) {
        return token.balanceOf(vm.addr(i));
    }

    function pr(uint256 i) private view returns (uint256) {
        return distributor.pendingRewards(vm.addr(i));
    }

    function rbo(uint256 i) private view returns (uint256) {
        return rewardToken.balanceOf(vm.addr(i));
    }

    function claim(uint256 i) private {
        vm.prank(vm.addr(i));

        distributor.claim(vm.addr(i));
    }

    function compound(uint256 i) private {
        vm.prank(vm.addr(i));

        distributor.compound(vm.addr(i), 0);
    }

    function emptyRewards(uint256 i) private {
        uint256 balance = rewardToken.balanceOf(vm.addr(i));

        vm.prank(vm.addr(i));

        rewardToken.transfer(vm.addr(100), balance);
    }

    function distribute(uint256 amount) private {
        uint256 balance = rewardToken.balanceOf(address(distributor));

        deal(address(rewardToken), address(distributor), balance + amount);

        distributor.distribute(0);
    }

    function testTotalRewardDistributedIncreases() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), allocation);
        token.allocate(vm.addr(2), allocation);

        assertEq(distributor.totalRewardDistributed(), 0);

        distribute(1 ether);

        assertEq(distributor.totalRewardDistributed(), 1 ether);

        distribute(2 ether);

        assertEq(distributor.totalRewardDistributed(), 3 ether);
    }

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

    function testTokenDonations() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), allocation);
        token.allocate(vm.addr(2), allocation);
        token.allocate(vm.addr(3), allocation);

        startTrading(1000 ether);

        vm.prank(vm.addr(3));

        token.transfer(address(distributor), allocation);

        distribute(0);

        uint256 rewardsAmount = rewardToken.balanceOf(address(distributor));

        assertGt(pr(1), 0);
        assertGt(pr(2), 0);
        assertGt(rewardsAmount, 0);

        claim(1);
        claim(2);

        assertGt(rbo(1), 0);
        assertGt(rbo(2), 0);
        assertApproxEqRel(rbo(1) + rbo(2), rewardsAmount, 0.01e18);
    }

    function testRewardTokenDonations() public {
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

    function testBothTokenDonations() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), allocation);
        token.allocate(vm.addr(2), allocation);
        token.allocate(vm.addr(3), allocation);

        startTrading(1000 ether);

        vm.prank(vm.addr(3));

        token.transfer(address(distributor), allocation);

        distribute(1 ether);

        uint256 rewardsAmount = rewardToken.balanceOf(address(distributor));

        assertGt(pr(1), 0);
        assertGt(pr(2), 0);
        assertGt(rewardsAmount, 1 ether);

        claim(1);
        claim(2);

        assertGt(rbo(1), 0);
        assertGt(rbo(2), 0);
        assertApproxEqRel(rbo(1) + rbo(2), rewardsAmount, 0.01e18);
    }

    function testDistributeEmits() public {
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), allocation);
        token.allocate(vm.addr(2), allocation);

        vm.expectEmit(true, true, true, true, address(distributor));

        emit Distribute(address(this), 1 ether);

        distribute(1 ether);
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

    function testDistributionIntegration1() public {
        // allocation shares are accounted.
        uint256 allocation = 1_000_000 ether;

        token.allocate(vm.addr(1), 1 * allocation);

        assertEq(distributor.totalShares(), bo(1));

        token.allocate(vm.addr(2), 2 * allocation);

        assertEq(distributor.totalShares(), bo(1) + bo(2));

        token.allocate(vm.addr(3), 3 * allocation);

        assertEq(distributor.totalShares(), bo(1) + bo(2) + bo(3));

        // start trading.
        startTrading(1000 ether);

        // remove max wallet.
        token.removeMaxWallet();

        // buy some tokens.
        buyToken(vm.addr(4), 1 ether);

        assertEq(distributor.totalShares(), bo(1) + bo(2) + bo(3) + bo(4));

        buyToken(vm.addr(5), 2 ether);

        assertEq(distributor.totalShares(), bo(1) + bo(2) + bo(3) + bo(4) + bo(5));

        buyToken(vm.addr(6), 3 ether);

        assertEq(distributor.totalShares(), bo(1) + bo(2) + bo(3) + bo(4) + bo(5) + bo(6));

        // tokens are collected during buy but not swapped yet.
        assertGt(token.balanceOf(address(distributor)), 0);
        assertEq(rewardToken.balanceOf(address(distributor)), 0);
        assertEq(distributor.totalRewardClaimed(), 0);
        assertEq(distributor.totalRewardDistributed(), 0);
        assertEq(pr(1), 0);
        assertEq(pr(2), 0);
        assertEq(pr(3), 0);
        assertEq(pr(4), 0);
        assertEq(pr(5), 0);
        assertEq(pr(6), 0);

        // transfer do not change total shares.
        uint256 userBalance6 = bo(6);
        uint256 originalTotalShares = distributor.totalShares();

        vm.prank(vm.addr(6));

        token.transfer(vm.addr(1), userBalance6);

        assertEq(distributor.totalShares(), originalTotalShares);
        assertEq(distributor.totalShares(), bo(1) + bo(2) + bo(3) + bo(4) + bo(5));

        // first sell triggers the tax sell.
        sellToken(vm.addr(5), bo(5));

        assertEq(distributor.totalShares(), bo(1) + bo(2) + bo(3) + bo(4));

        assertEq(token.balanceOf(address(distributor)), 0);
        assertEq(rewardToken.balanceOf(address(distributor)), distributor.totalRewardDistributed());
        assertEq(distributor.totalRewardClaimed(), 0);
        assertApproxEqRel(distributor.totalRewardDistributed(), pr(1) + pr(2) + pr(3) + pr(4) + pr(5), 0.01e18);
        assertGt(pr(1), 0);
        assertGt(pr(2), 0);
        assertGt(pr(3), 0);
        assertGt(pr(4), 0);
        assertGt(pr(5), 0);
        assertEq(pr(6), 0);

        // sell everything.
        sellToken(vm.addr(4), bo(4));

        assertEq(distributor.totalShares(), bo(1) + bo(2) + bo(3));

        sellToken(vm.addr(3), bo(3));

        assertEq(distributor.totalShares(), bo(1) + bo(2));

        sellToken(vm.addr(2), bo(2));

        assertEq(distributor.totalShares(), bo(1));

        sellToken(vm.addr(1), bo(1));

        assertEq(distributor.totalShares(), 0);

        // record the pending rewards.
        uint256 pr1 = pr(1);
        uint256 pr2 = pr(2);
        uint256 pr3 = pr(3);
        uint256 pr4 = pr(4);
        uint256 pr5 = pr(5);
        uint256 pr6 = pr(6);

        // empty all the current reward token balances.
        emptyRewards(1);
        emptyRewards(2);
        emptyRewards(3);
        emptyRewards(4);
        emptyRewards(5);
        emptyRewards(6);

        // claim everything.
        claim(1);
        claim(2);
        claim(3);
        claim(4);
        claim(5);
        claim(6);

        // check claimed amount.
        assertEq(rbo(1), pr1);
        assertEq(rbo(2), pr2);
        assertEq(rbo(3), pr3);
        assertEq(rbo(4), pr4);
        assertEq(rbo(5), pr5);
        assertEq(rbo(6), pr6);

        // check distributor final state.
        assertEq(token.balanceOf(address(distributor)), 0);
        assertEq(
            rewardToken.balanceOf(address(distributor)),
            distributor.totalRewardDistributed() - distributor.totalRewardClaimed()
        );
        assertEq(distributor.totalRewardClaimed(), pr1 + pr2 + pr3 + pr4 + pr5 + pr6);
        assertApproxEqRel(distributor.totalRewardDistributed(), pr1 + pr2 + pr3 + pr4 + pr5 + pr6, 0.01e18);
        assertEq(pr(1), 0);
        assertEq(pr(2), 0);
        assertEq(pr(3), 0);
        assertEq(pr(4), 0);
        assertEq(pr(5), 0);
        assertEq(pr(6), 0);
    }
}
