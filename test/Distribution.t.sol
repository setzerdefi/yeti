// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract DistributionTest is ERC20TaxRewardsTest {
    event Distribute(address indexed addr, uint256 amount);

    function testTotalRewardDistributedIncreases() public {
        uint256 allocation = 100_000 ether;

        allocate(vm.addr(1), allocation);
        allocate(vm.addr(2), allocation);

        assertEq(distributor.totalRewardDistributed(), 0);

        distribute(1 ether);

        assertEq(distributor.totalRewardDistributed(), 1 ether);

        distribute(2 ether);

        assertEq(distributor.totalRewardDistributed(), 3 ether);
    }

    function testTokenDonations() public {
        uint256 allocation = 100_000 ether;

        allocate(vm.addr(1), allocation);
        allocate(vm.addr(2), allocation);
        allocate(vm.addr(3), allocation);

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
        uint256 allocation = 100_000 ether;

        allocate(vm.addr(1), allocation);
        allocate(vm.addr(2), allocation);

        distribute(2 ether);

        assertEq(pr(1), 1 ether);
        assertEq(pr(2), 1 ether);

        claim(1);
        claim(2);

        assertEq(rbo(1), 1 ether);
        assertEq(rbo(2), 1 ether);
    }

    function testBothTokenDonations() public {
        uint256 allocation = 100_000 ether;

        allocate(vm.addr(1), allocation);
        allocate(vm.addr(2), allocation);
        allocate(vm.addr(3), allocation);

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
        uint256 allocation = 100_000 ether;

        allocate(vm.addr(1), allocation);
        allocate(vm.addr(2), allocation);

        vm.expectEmit(true, true, true, true, address(distributor));

        emit Distribute(address(this), 1 ether);

        distribute(1 ether);
    }

    function testDistributionIntegration1() public {
        // allocation shares are accounted.
        uint256 allocation = 100_000 ether;

        allocate(vm.addr(1), 1 * allocation);

        assertEq(distributor.totalShares(), bo(1));

        allocate(vm.addr(2), 2 * allocation);

        assertEq(distributor.totalShares(), bo(1) + bo(2));

        allocate(vm.addr(3), 3 * allocation);

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

    function testDistributionIntegration2() public {
        // start trading.
        startTrading(1000 ether);

        // remove max wallet.
        token.removeMaxWallet();

        // buy some tokens.
        buyToken(vm.addr(1), 1 ether);
        buyToken(vm.addr(2), 2 ether);
        buyToken(vm.addr(3), 3 ether);
        buyToken(vm.addr(4), 4 ether);

        // distribute the rewards once.
        distributor.distribute(0);

        // two claims and two compounds.
        claim(1);
        claim(3);
        compound(2);
        compound(4);

        // buy more.
        buyToken(vm.addr(1), 1 ether);
        buyToken(vm.addr(2), 2 ether);
        buyToken(vm.addr(3), 3 ether);
        buyToken(vm.addr(4), 4 ether);

        // make some token donation to the contract.
        uint256 bo1 = bo(1);

        vm.prank(vm.addr(1));

        token.transfer(address(distributor), bo1 / 2);

        // make some reward token donation to the contract.
        donate(1 ether);

        // distribute another time.
        distributor.distribute(0);

        // two claims and two compounds.
        compound(1);
        compound(3);
        claim(2);
        claim(4);

        // another time?
        buyToken(vm.addr(1), 1 ether);
        buyToken(vm.addr(2), 2 ether);
        buyToken(vm.addr(3), 3 ether);
        buyToken(vm.addr(4), 4 ether);

        // make some token donation to the contract.
        uint256 bo2 = bo(2);

        vm.prank(vm.addr(2));

        token.transfer(address(distributor), bo2 / 2);

        // make some reward token donation to the contract.
        donate(1 ether);

        // distribute another time.
        distributor.distribute(0);

        // lets go again.
        buyToken(vm.addr(1), 1 ether);
        buyToken(vm.addr(2), 2 ether);
        buyToken(vm.addr(3), 3 ether);
        buyToken(vm.addr(4), 4 ether);

        // make some token donation to the contract.
        uint256 bo3 = bo(3);

        vm.prank(vm.addr(3));

        token.transfer(address(distributor), bo3 / 2);

        // make some reward token donation to the contract.
        donate(1 ether);

        // distribute another time.
        distributor.distribute(0);

        // everyone should be able to claim everything.
        claim(1);
        claim(2);
        claim(3);
        claim(4);

        // distributor should be empty.
        assertEq(token.balanceOf(address(distributor)), 0);
        assertApproxEqAbs(rewardToken.balanceOf(address(distributor)), 0, 5_000_000);

        // the assertion should hold.
        assertEq(
            rewardToken.balanceOf(address(distributor)),
            distributor.totalRewardDistributed() - distributor.totalRewardClaimed()
                - distributor.totalRewardCompounded()
        );
    }

    function testDisableRewards() public {
        // start trading.
        startTrading(1000 ether);

        // remove max wallet.
        token.removeMaxWallet();

        // buy some tokens.
        buyToken(vm.addr(1), 1 ether);
        buyToken(vm.addr(2), 2 ether);
        buyToken(vm.addr(3), 3 ether);
        buyToken(vm.addr(4), 4 ether);

        // distribute.
        distributor.distribute(0);

        // claim all.
        claim(1);
        claim(2);
        claim(3);
        claim(4);

        // distributor should be empty.
        assertEq(token.balanceOf(address(distributor)), 0);
        assertApproxEqAbs(rewardToken.balanceOf(address(distributor)), 0, 5_000_000);

        // record the current shares and current reward balance.
        uint256 originalTotalShares = distributor.totalShares();
        uint256 originalRewardBalance = rewardToken.balanceOf(address(distributor));

        // stop the rewards.
        token._emergencyDisableRewards();

        // people can still buy and sell but without tax/rewards.
        buyToken(vm.addr(1), 1 ether);
        buyToken(vm.addr(2), 2 ether);
        buyToken(vm.addr(3), 3 ether);
        buyToken(vm.addr(4), 4 ether);
        sellToken(vm.addr(1), bo(1) / 2);
        sellToken(vm.addr(2), bo(2) / 2);
        sellToken(vm.addr(3), bo(3) / 2);
        sellToken(vm.addr(4), bo(4) / 2);

        // distributor should have collected no tax.
        assertEq(token.balanceOf(address(distributor)), 0);

        // total shares should be the same.
        assertEq(distributor.totalShares(), originalTotalShares);

        // reward token balance should be the same.
        assertEq(rewardToken.balanceOf(address(distributor)), originalRewardBalance);

        // nobody should have rewards.
        assertEq(pr(1), 0);
        assertEq(pr(2), 0);
        assertEq(pr(3), 0);
        assertEq(pr(4), 0);
    }
}
