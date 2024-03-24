// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20TaxRewards} from "./ERC20TaxRewards.sol";

contract Yeti is ERC20TaxRewards {
    uint256 public constant INITIAL_TOTAL_SUPPLY = 100_000_000 ether;

    constructor() ERC20TaxRewards("Yeti", "YTI", INITIAL_TOTAL_SUPPLY) {}
}
