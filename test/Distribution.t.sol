// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract DistributionTest is ERC20TaxRewardsTest {
    function bo(uint256 i) private view returns (uint256) {
        return token.balanceOf(vm.addr(i));
    }

    function pr(uint256 i) private view returns (uint256) {
        return distributor.pendingRewards(vm.addr(i));
    }

    function claim(uint256 i) private {
        vm.prank(vm.addr(i));

        distributor.claim(vm.addr(i));
    }

    function emptyRewards(uint256 i) private {
        uint256 balance = rewardToken.balanceOf(vm.addr(i));

        vm.prank(vm.addr(i));

        rewardToken.transfer(vm.addr(100), balance);
    }

    function testDistribution() public {
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
        assertEq(rewardToken.balanceOf(vm.addr(1)), pr1);
        assertEq(rewardToken.balanceOf(vm.addr(2)), pr2);
        assertEq(rewardToken.balanceOf(vm.addr(3)), pr3);
        assertEq(rewardToken.balanceOf(vm.addr(4)), pr4);
        assertEq(rewardToken.balanceOf(vm.addr(5)), pr5);
        assertEq(rewardToken.balanceOf(vm.addr(6)), pr6);

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
