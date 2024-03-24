// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface IDistributor {
    event Claim(address indexed addr, address indexed to, uint256 amount);
    event Compound(address indexed addr, address indexed to, uint256 amount);
    event Distribute(address indexed addr, uint256 amount);

    function totalShares() external view returns (uint256);
    function totalRewardClaimed() external view returns (uint256);
    function totalRewardCompounded() external view returns (uint256);
    function totalRewardDistributed() external view returns (uint256);
    function pendingRewards(address) external view returns (uint256);
    function claim(address) external;
    function compound(address, uint256) external;
    function distribute(uint256 amountOutMin) external;
    function updateShare(address addr) external;
}
