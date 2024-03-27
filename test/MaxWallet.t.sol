// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewardsTest} from "./ERC20TaxRewards.t.sol";

contract MaxWalletTest is ERC20TaxRewardsTest {
    function testMaxWallet() public {
        assertEq(token.maxWallet(), token.totalSupply() / 100);

        allocate(vm.addr(1), token.maxWallet());

        vm.expectRevert("!maxWallet");

        token.transfer(vm.addr(1), 1);

        token.removeMaxWallet();

        token.transfer(vm.addr(1), 1);

        assertEq(token.balanceOf(vm.addr(1)), (token.totalSupply() / 100) + 1);
    }
}
