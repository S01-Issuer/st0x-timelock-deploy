// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract ScheduleRoles is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        address timelockAddr = vm.envAddress("TIMELOCK");
        address guardian = vm.envAddress("GUARDIAN");
        address proposer1 = vm.envAddress("PROPOSER_1");
        address proposer2 = vm.envAddress("PROPOSER_2");

        TimelockController timelock = TimelockController(payable(timelockAddr));

        bytes32 salt = keccak256("grant-guardian-and-revoke-proposers-v1");

        bytes32 role = timelock.CANCELLER_ROLE();

        // --- build batched calls ---
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory payloads = new bytes[](3);

        for (uint256 i = 0; i < 3; i++) {
            targets[i] = timelockAddr;
            values[i] = 0;
        }

        // 1. grant guardian
        payloads[0] = abi.encodeCall(
            IAccessControl.grantRole,
            (role, guardian)
        );

        // 2. revoke proposer1
        payloads[1] = abi.encodeCall(
            IAccessControl.revokeRole,
            (role, proposer1)
        );

        // 3. revoke proposer2
        payloads[2] = abi.encodeCall(
            IAccessControl.revokeRole,
            (role, proposer2)
        );

        console2.logBytes(
            abi.encodeCall(
                TimelockController.scheduleBatch,
                (
                    targets,
                    values,
                    payloads,
                    bytes32(0),
                    salt,
                    timelock.getMinDelay()
                )
            )
        );

        console2.log("Scheduled batch operation");
        console2.log("Timelock:", timelockAddr);
        console2.log("Salt:");
        console2.logBytes32(salt);
    }
}