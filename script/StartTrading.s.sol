// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Yeti} from "../src/Yeti.sol";

contract StartTradingScript is Script {
    function run() public {
        uint256 rewardTokenAmount = 1 ether;
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address yetiContractAddress = vm.envAddress("YETI_CONTRACT_ADDRESS");

        Yeti yeti = Yeti(yetiContractAddress);
        IERC20 rewardToken = yeti.rewardToken();

        vm.startBroadcast(deployerPrivateKey);
        rewardToken.approve(address(yeti), rewardTokenAmount);
        yeti.startTrading(rewardTokenAmount);
        vm.stopBroadcast();
    }
}
