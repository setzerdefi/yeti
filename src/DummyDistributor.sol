// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IDistributor} from "./IDistributor.sol";

contract DummyDistributor is IDistributor {
    function distribute(uint256 amountOutMin) external {}
    function updateShare(address addr) external {}
}
