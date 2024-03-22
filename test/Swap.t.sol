// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract SwapTest is ERC20TaxRewardsTest {
    function testSwap() public {
        address user = vm.addr(1);

        // buy 1 ether of tokens.
        buyToken(user, 1 ether);

        // we must have received ~ 76k tokens and ~ 24k should be collected as tax.
        assertApproxEqRel(token.balanceOf(user), withDecimals(76_000), 0.01e18);
        assertApproxEqRel(token.balanceOf(address(distributor)), withDecimals(24_000), 0.01e18);

        // sell everything, should swap taxes to rewardToken.
        uint256 balance = token.balanceOf(user);

        sellToken(user, balance);

        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(distributor)), 0);
        assertApproxEqRel(rewardToken.balanceOf(address(distributor)), 0.4224 ether, 0.01e18);

        // (total tax is 24k + (76k * 0.24) = 18240 tokens)
        // (1eth = 100k tokens, so 0.4224 eth swapped back as tax)
    }
}
