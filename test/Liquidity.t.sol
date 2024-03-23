// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract LiquidityTest is ERC20TaxRewardsTest {
    function testRemoveAllLiquidity() public {
        initialize(1000 ether);

        token.removeMaxWallet();

        removeLiquidity(address(this));

        assertApproxEqRel(token.balanceOf(address(this)), (token.TOTAL_SUPPLY() * 76) / 100, 0.01e18);
        assertApproxEqRel(rewardToken.balanceOf(address(this)), 1000 ether, 0.01e18);
    }

    function testProvideLiquidityDefault() public {
        address provider = vm.addr(1);

        // initialize the lp.
        initialize(1000 ether);

        // buy some tokens and put them as liquidity.
        buyToken(provider, 1 ether);

        uint256 balance = token.balanceOf(provider);

        // ~ 76k tokens has been received.
        assertApproxEqRel(balance, withDecimals(76_000), 0.01e18);

        // So we send the 76k tokens with 0.76 eth. (1eth = 100k tokens)
        addLiquidity(provider, balance, 0.76 ether);

        // all should be sent to the LP, only a few eth dust is send back.
        assertEq(token.balanceOf(provider), 0);
        assertApproxEqAbs(rewardToken.balanceOf(provider), 0, 0.01 ether);

        // adding liquidity is like a sell so the tax should have been sold.
        // 24% tax by default: 100k tokens * 0.76 (buy) * 0.76 (add liquidity) ~= 57760.
        // 100k - 57760 = 42240 tokens were collected as tax ~= 0.4224 eth.
        assertEq(token.balanceOf(address(distributor)), 0);
        assertApproxEqRel(rewardToken.balanceOf(address(distributor)), 0.4224 ether, 0.01e18);

        uint256 originalCollectedRewardToken = rewardToken.balanceOf(address(distributor));

        // removing liquidity.
        removeLiquidity(provider);

        // tax on removing liquidity so provider should get back 57760 * 0.76 = 43898
        assertApproxEqRel(token.balanceOf(provider), withDecimals(43898), 0.01e18);
        assertApproxEqRel(rewardToken.balanceOf(provider), 0.577 ether, 0.01e18);

        // 57760 - 43898 = 13862 was collected on removing liquidity.
        assertEq(rewardToken.balanceOf(address(distributor)), originalCollectedRewardToken);
        assertApproxEqRel(token.balanceOf(address(distributor)), withDecimals(13862), 0.01e18);
    }
}
