// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {S01Timelock} from "../src/S01Timelock.sol";
import {LibProdDeploy} from "../src/LibProdDeploy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @dev Deploys S01Timelock in-memory with the exact same constructor arguments
/// the real deploy would use, then asserts every post-deploy invariant. No
/// broadcast — this is a dry-run gate meant to run before the real deploy.
contract SimulateDeploy is Script {
    function run() external {
        // Defaults so the script is runnable with zero env vars for a pure local smoke check.
        address proposer1 = vm.envOr("PROPOSER_1", address(0xA11CE));
        address proposer2 = vm.envOr("PROPOSER_2", address(0xB0B));

        // Mirror DeployTimelock.s.sol line-for-line so any param-order drift is caught.
        address[] memory proposers = new address[](2);
        proposers[0] = proposer1;
        proposers[1] = proposer2;

        address[] memory executors = new address[](1);
        executors[0] = address(0); // open execution

        // No vm.startBroadcast — in-memory simulation only.
        S01Timelock timelock = new S01Timelock(
            LibProdDeploy.MIN_DELAY,
            proposers,
            executors,
            address(0)
        );

        console2.log("SimulateDeploy: timelock simulated at:", address(timelock));
        console2.log("SimulateDeploy: msg.sender (deployer):", msg.sender);
        console2.log("SimulateDeploy: proposer1:", proposer1);
        console2.log("SimulateDeploy: proposer2:", proposer2);
        console2.log("SimulateDeploy: minDelay (s):", timelock.getMinDelay());

        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 CANCELLER_ROLE = timelock.CANCELLER_ROLE();
        bytes32 DEFAULT_ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();

        console2.log("PROPOSER_ROLE  ", vm.toString(PROPOSER_ROLE));
        console2.log("EXECUTOR_ROLE  ", vm.toString(EXECUTOR_ROLE));
        console2.log("CANCELLER_ROLE ", vm.toString(CANCELLER_ROLE));
        console2.log("DEFAULT_ADMIN  ", vm.toString(DEFAULT_ADMIN_ROLE));

        console2.log("hasRole(PROPOSER_ROLE, proposer1)      ", timelock.hasRole(PROPOSER_ROLE, proposer1));
        console2.log("hasRole(PROPOSER_ROLE, proposer2)      ", timelock.hasRole(PROPOSER_ROLE, proposer2));
        console2.log("hasRole(CANCELLER_ROLE, proposer1)     ", timelock.hasRole(CANCELLER_ROLE, proposer1));
        console2.log("hasRole(CANCELLER_ROLE, proposer2)     ", timelock.hasRole(CANCELLER_ROLE, proposer2));
        console2.log("hasRole(EXECUTOR_ROLE, address(0))     ", timelock.hasRole(EXECUTOR_ROLE, address(0)));
        console2.log("hasRole(DEFAULT_ADMIN, msg.sender)     ", timelock.hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        console2.log("hasRole(DEFAULT_ADMIN, proposer1)      ", timelock.hasRole(DEFAULT_ADMIN_ROLE, proposer1));
        console2.log("hasRole(DEFAULT_ADMIN, proposer2)      ", timelock.hasRole(DEFAULT_ADMIN_ROLE, proposer2));
        console2.log("hasRole(DEFAULT_ADMIN, timelock)       ", timelock.hasRole(DEFAULT_ADMIN_ROLE, address(timelock)));

        // --- Invariant checks ---
        require(timelock.getMinDelay() == LibProdDeploy.MIN_DELAY, "minDelay mismatch");
        require(timelock.getMinDelay() == 48 hours, "minDelay != 48h");

        require(timelock.hasRole(PROPOSER_ROLE, proposer1), "proposer1 missing PROPOSER_ROLE");
        require(timelock.hasRole(PROPOSER_ROLE, proposer2), "proposer2 missing PROPOSER_ROLE");

        require(timelock.hasRole(CANCELLER_ROLE, proposer1), "proposer1 missing CANCELLER_ROLE");
        require(timelock.hasRole(CANCELLER_ROLE, proposer2), "proposer2 missing CANCELLER_ROLE");

        require(timelock.hasRole(EXECUTOR_ROLE, address(0)), "EXECUTOR_ROLE not open (address(0))");

        require(!timelock.hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "deployer holds DEFAULT_ADMIN_ROLE");
        require(!timelock.hasRole(DEFAULT_ADMIN_ROLE, proposer1), "proposer1 holds DEFAULT_ADMIN_ROLE");
        require(!timelock.hasRole(DEFAULT_ADMIN_ROLE, proposer2), "proposer2 holds DEFAULT_ADMIN_ROLE");

        require(timelock.hasRole(DEFAULT_ADMIN_ROLE, address(timelock)), "timelock missing self-admin");

        // Bytecode-drift sanity check: the runtime code at the deployed address must
        // match the compiled artifact. Catches local tree corruption before broadcast.
        require(
            keccak256(address(timelock).code)
                == keccak256(vm.getDeployedCode("S01Timelock.sol:S01Timelock")),
            "bytecode drift"
        );

        console2.log("SimulateDeploy: all invariants OK");
    }
}
