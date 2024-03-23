// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract SwapTest is ERC20TaxRewardsTest {
    function testSwapDefault() public {
        address user = vm.addr(1);

        // initialize the lp.
        initialize(1000 ether);

        // buy 1 ether of tokens.
        buyToken(user, 1 ether);

        // we must have received ~ 76k tokens and ~ 24k should be collected as tax.
        assertApproxEqRel(token.balanceOf(user), 76_000 ether, 0.01e18);
        assertApproxEqRel(token.balanceOf(address(distributor)), 24_000 ether, 0.01e18);
        assertEq(rewardToken.balanceOf(address(distributor)), 0);

        // sell everything, should swap taxes to rewardToken.
        uint256 balance = token.balanceOf(user);

        sellToken(user, balance);

        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(distributor)), 0);
        assertApproxEqRel(rewardToken.balanceOf(address(distributor)), 0.4224 ether, 0.01e18);

        // (total tax is 100k - (100k * 0.76 * 0.76) = 42240 tokens)
        // (1eth = 100k tokens, so 0.4224 eth swapped back as tax)
    }

    function testSwapBuyAndSellTax() public {
        address user = vm.addr(1);

        // set the tax to 5%.
        token.setFee(500, 500);

        initialize(1000 ether);

        buyToken(user, 1 ether);

        assertApproxEqRel(token.balanceOf(user), 95_000 ether, 0.01e18);
        assertApproxEqRel(token.balanceOf(address(distributor)), 5_000 ether, 0.01e18);
        assertEq(rewardToken.balanceOf(address(distributor)), 0);

        uint256 balance = token.balanceOf(user);

        sellToken(user, balance);

        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(distributor)), 0);
        assertApproxEqRel(rewardToken.balanceOf(address(distributor)), 0.0975 ether, 0.01e18);
    }

    function testSwapBuyTaxOnly() public {
        address user = vm.addr(1);

        // set the tax to 5%/0%.
        token.setFee(500, 0);

        initialize(1000 ether);

        buyToken(user, 1 ether);

        assertApproxEqRel(token.balanceOf(user), 95_000 ether, 0.01e18);
        assertApproxEqRel(token.balanceOf(address(distributor)), 5_000 ether, 0.01e18);
        assertEq(rewardToken.balanceOf(address(distributor)), 0);

        uint256 balance = token.balanceOf(user);

        sellToken(user, balance);

        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(distributor)), 0);
        assertApproxEqRel(rewardToken.balanceOf(address(distributor)), 0.05 ether, 0.01e18);
    }

    function testSwapSellTaxOnly() public {
        address user = vm.addr(1);

        // set the tax to 0%/5%.
        token.setFee(0, 500);

        initialize(1000 ether);

        buyToken(user, 1 ether);

        assertApproxEqRel(token.balanceOf(user), 100_000 ether, 0.01e18);
        assertEq(token.balanceOf(address(distributor)), 0);
        assertEq(rewardToken.balanceOf(address(distributor)), 0);

        uint256 balance = token.balanceOf(user);

        sellToken(user, balance);

        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(distributor)), 0);
        assertApproxEqRel(rewardToken.balanceOf(address(distributor)), 0.05 ether, 0.01e18);
    }
}
