// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {S01Timelock} from "../src/S01Timelock.sol";

contract DeployTimelock is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address proposer1 = vm.envAddress("PROPOSER_1");
        address proposer2 = vm.envAddress("PROPOSER_2");
        address guardian = vm.envAddress("GUARDIAN");

        address[] memory proposers = new address[](2);
        proposers[0] = proposer1;
        proposers[1] = proposer2;

        address[] memory executors = new address[](1);
        executors[0] = address(0); // open execution

        vm.startBroadcast(deployerPrivateKey);

        S01Timelock timelock = new S01Timelock(
            48 hours,
            proposers,
            executors,
            address(0) // no admin — timelock self-governs
        );

        // Grant guardian the canceller role
        timelock.grantRole(timelock.CANCELLER_ROLE(), guardian);

        vm.stopBroadcast();

        console2.log("Timelock deployed at:", address(timelock));
    }
}
