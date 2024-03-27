// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract LiquidityTest is ERC20TaxRewardsTest {
    function testRemoveAllLiquidity() public {
        startTrading(1000 ether);

        removeLiquidity(address(this));

        assertApproxEqRel(token.balanceOf(address(this)), token.totalSupply(), 0.01e18);
        assertApproxEqRel(rewardToken.balanceOf(address(this)), 1000 ether, 0.01e18);
    }

    function testProvideLiquidityDefault() public {
        address provider = vm.addr(1);

        // allocate some tokens to the provider.
        uint256 allocation = 1_000_000 ether;

        allocate(provider, allocation);

        assertEq(token.balanceOf(provider), allocation);

        // initialize the lp.
        startTrading(990 ether);

        // So we send the 1M tokens with 10 eth. (1eth = 100k tokens)
        addLiquidity(provider, allocation, 10 ether);

        // all is taken from the provider.
        assertEq(token.balanceOf(provider), 0);
        assertEq(rewardToken.balanceOf(provider), 0);

        // adding liquidity is like a sell so the tax is collected then sold.
        // 24% tax by default: 240000 tokens collected as tax and sold for ~ 2.4 eth.
        // the lp should contain all the tokens and ~ 1000 - 2.4 eth reward tokens.
        assertEq(token.balanceOf(address(pair)), token.totalSupply());
        assertApproxEqRel(rewardToken.balanceOf(address(pair)), 997.6 ether, 0.01e18);

        // the distributor should have 0 tokens (they have been sold) and 2.4 eth reward tokens.
        uint256 originalCollectedRewardToken = rewardToken.balanceOf(address(distributor));

        assertEq(token.balanceOf(address(distributor)), 0);
        assertApproxEqRel(originalCollectedRewardToken, 2.4 ether, 0.01e18);

        // removing liquidity.
        removeLiquidity(provider);

        // 760k tokens and ~7.6 ethers are removed.
        // removing liquidity is like a buy so the tax is collected but not sold.
        // 24% tax by default: 760k * 0.24 = 577600 tokens collected as tax.
        assertApproxEqRel(token.balanceOf(provider), 577_600 ether, 0.01e18);
        assertApproxEqRel(rewardToken.balanceOf(provider), 7.6 ether, 0.01e18);

        // 760k - 577600 = 182400 was collected on removing liquidity and kept in the distributor.
        // the tax is not sold so the amount of reward tokens should be the same.
        assertApproxEqRel(token.balanceOf(address(distributor)), 182_400 ether, 0.01e18);
        assertEq(rewardToken.balanceOf(address(distributor)), originalCollectedRewardToken);
    }

    function testProvideLiquidityBuyAndSellTax() public {
        address provider = vm.addr(1);

        // set the tax to 5%.
        token.setFee(500, 500);

        uint256 allocation = 1_000_000 ether;

        allocate(provider, allocation);

        assertEq(token.balanceOf(provider), allocation);

        startTrading(990 ether);

        addLiquidity(provider, allocation, 10 ether);

        assertEq(token.balanceOf(provider), 0);
        assertEq(rewardToken.balanceOf(provider), 0);
        assertEq(token.balanceOf(address(pair)), token.totalSupply());
        assertApproxEqRel(rewardToken.balanceOf(address(pair)), 999.5 ether, 0.01e18);

        uint256 originalCollectedRewardToken = rewardToken.balanceOf(address(distributor));

        assertEq(token.balanceOf(address(distributor)), 0);
        assertApproxEqRel(originalCollectedRewardToken, 0.5 ether, 0.01e18);

        removeLiquidity(provider);

        assertApproxEqRel(token.balanceOf(provider), 902_500 ether, 0.01e18);
        assertApproxEqRel(rewardToken.balanceOf(provider), 9.5 ether, 0.01e18);

        assertApproxEqRel(token.balanceOf(address(distributor)), 47_500 ether, 0.01e18);
        assertEq(rewardToken.balanceOf(address(distributor)), originalCollectedRewardToken);
    }

    function testProvideLiquidityBuyTaxOnly() public {
        address provider = vm.addr(1);

        // set the tax to 5%/0%.
        token.setFee(500, 0);

        uint256 allocation = 1_000_000 ether;

        allocate(provider, allocation);

        assertEq(token.balanceOf(provider), allocation);

        startTrading(990 ether);

        addLiquidity(provider, allocation, 10 ether);

        assertEq(token.balanceOf(provider), 0);
        assertEq(rewardToken.balanceOf(provider), 0);
        assertEq(token.balanceOf(address(pair)), token.totalSupply());
        assertEq(rewardToken.balanceOf(address(pair)), 1000 ether);

        assertEq(token.balanceOf(address(distributor)), 0);
        assertEq(rewardToken.balanceOf(address(distributor)), 0);

        removeLiquidity(provider);

        assertApproxEqRel(token.balanceOf(provider), 950_000 ether, 0.01e18);
        assertApproxEqRel(rewardToken.balanceOf(provider), 10 ether, 0.01e18);

        assertApproxEqRel(token.balanceOf(address(distributor)), 50_000 ether, 0.01e18);
        assertEq(rewardToken.balanceOf(address(distributor)), 0);
    }

    function testProvideLiquiditySellTaxOnly() public {
        address provider = vm.addr(1);

        // set the tax to 0%/5%.
        token.setFee(0, 500);

        uint256 allocation = 1_000_000 ether;

        allocate(provider, allocation);

        assertEq(token.balanceOf(provider), allocation);

        startTrading(990 ether);

        addLiquidity(provider, allocation, 10 ether);

        assertEq(token.balanceOf(provider), 0);
        assertEq(rewardToken.balanceOf(provider), 0);
        assertEq(token.balanceOf(address(pair)), token.totalSupply());
        assertApproxEqRel(rewardToken.balanceOf(address(pair)), 999.5 ether, 0.01e18);

        uint256 originalCollectedRewardToken = rewardToken.balanceOf(address(distributor));

        assertEq(token.balanceOf(address(distributor)), 0);
        assertApproxEqRel(originalCollectedRewardToken, 0.5 ether, 0.01e18);

        removeLiquidity(provider);

        assertApproxEqRel(token.balanceOf(provider), 950_000 ether, 0.01e18);
        assertApproxEqRel(rewardToken.balanceOf(provider), 9.5 ether, 0.01e18);

        assertEq(token.balanceOf(address(distributor)), 0);
        assertEq(rewardToken.balanceOf(address(distributor)), originalCollectedRewardToken);
    }
}
