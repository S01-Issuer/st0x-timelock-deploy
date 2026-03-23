// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract ExecuteRoles is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        address timelockAddr = vm.envAddress("TIMELOCK");
        address guardian = vm.envAddress("GUARDIAN");
        address proposer1 = vm.envAddress("PROPOSER_1");
        address proposer2 = vm.envAddress("PROPOSER_2");

        TimelockController timelock = TimelockController(payable(timelockAddr));

        bytes32 salt = keccak256("grant-guardian-and-revoke-proposers-v1");

        bytes32 role = timelock.CANCELLER_ROLE();

        // --- rebuild same batch ---
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory payloads = new bytes[](3);

        for (uint256 i = 0; i < 3; i++) {
            targets[i] = address(timelock);
            values[i] = 0;
        }

        payloads[0] = abi.encodeCall(
            IAccessControl.grantRole,
            (role, guardian)
        );

        payloads[1] = abi.encodeCall(
            IAccessControl.revokeRole,
            (role, proposer1)
        );

        payloads[2] = abi.encodeCall(
            IAccessControl.revokeRole,
            (role, proposer2)
        );

        vm.startBroadcast(pk);

        // console2.logBytes(
        //     abi.encodeCall(
        //         TimelockController.executeBatch,
        //         (
        //             targets,
        //     values,
        //     payloads,
        //     bytes32(0),
        //     salt
        //         )
        //     )
        // );

        console2.log("PROPOSER_ROLE : ");
        console2.logBytes32(keccak256("PROPOSER_ROLE"));
        console2.log("EXECUTOR_ROLE : ");
        console2.logBytes32(keccak256("EXECUTOR_ROLE"));
        console2.log("CANCELLER_ROLE : ");
        console2.logBytes32(keccak256("CANCELLER_ROLE"));



        vm.stopBroadcast();

        console2.log("Executed batch operation");
    }
}