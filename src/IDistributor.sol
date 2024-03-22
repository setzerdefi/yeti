// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface IDistributor {
    function distribute(uint256 amountOutMin) external;
    function updateShare(address addr) external;
}
