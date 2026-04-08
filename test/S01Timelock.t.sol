// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {S01Timelock} from "../src/S01Timelock.sol";
import {LibProdDeploy} from "../src/LibProdDeploy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract MockTarget {
    uint256 public value;

    function setValue(uint256 v) external {
        value = v;
    }
}

contract S01TimelockTest is Test {
    S01Timelock internal timelock;
    MockTarget internal target;

    address internal proposer1 = address(0xA11CE);
    address internal proposer2 = address(0xB0B);
    address internal stranger = address(0xBADD1E);
    address internal newCanceller = address(0xCAFE);

    bytes32 internal PROPOSER_ROLE;
    bytes32 internal EXECUTOR_ROLE;
    bytes32 internal CANCELLER_ROLE;
    bytes32 internal DEFAULT_ADMIN_ROLE;

    function setUp() public {
        address[] memory proposers = new address[](2);
        proposers[0] = proposer1;
        proposers[1] = proposer2;

        address[] memory executors = new address[](1);
        executors[0] = address(0);

        timelock = new S01Timelock(
            LibProdDeploy.MIN_DELAY,
            proposers,
            executors,
            address(0)
        );

        target = new MockTarget();

        PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        CANCELLER_ROLE = timelock.CANCELLER_ROLE();
        DEFAULT_ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();
    }

    // 1
    function test_MinDelay_IsConfigured() public view {
        assertEq(timelock.getMinDelay(), 48 hours);
        assertEq(timelock.getMinDelay(), LibProdDeploy.MIN_DELAY);
    }

    // 2
    function test_Roles_ProposerAssigned() public view {
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer1));
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer2));
        assertFalse(timelock.hasRole(PROPOSER_ROLE, stranger));
    }

    // 3
    function test_Roles_CancellerAutoAssignedToProposers() public view {
        assertTrue(timelock.hasRole(CANCELLER_ROLE, proposer1));
        assertTrue(timelock.hasRole(CANCELLER_ROLE, proposer2));
        assertFalse(timelock.hasRole(CANCELLER_ROLE, stranger));
    }

    // 4
    function test_Roles_ExecutorIsOpenSentinel() public view {
        assertTrue(timelock.hasRole(EXECUTOR_ROLE, address(0)));
    }

    // 5
    function test_Roles_NoExternalAdmin() public view {
        assertFalse(timelock.hasRole(DEFAULT_ADMIN_ROLE, address(this)));
        assertFalse(timelock.hasRole(DEFAULT_ADMIN_ROLE, proposer1));
        assertFalse(timelock.hasRole(DEFAULT_ADMIN_ROLE, proposer2));
        assertFalse(timelock.hasRole(DEFAULT_ADMIN_ROLE, address(0)));
    }

    // 6
    function test_Roles_TimelockSelfAdmin() public view {
        assertTrue(timelock.hasRole(DEFAULT_ADMIN_ROLE, address(timelock)));
    }

    // 7
    function test_Schedule_RevertsWhenCallerNotProposer() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (42));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                stranger,
                PROPOSER_ROLE
            )
        );
        timelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0),
            LibProdDeploy.MIN_DELAY
        );
    }

    // 8
    function test_Schedule_SucceedsForProposer() public {
        uint256 start = block.timestamp;
        bytes memory data = abi.encodeCall(MockTarget.setValue, (42));

        vm.prank(proposer1);
        timelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0),
            LibProdDeploy.MIN_DELAY
        );

        bytes32 id = timelock.hashOperation(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0)
        );
        assertTrue(timelock.isOperationPending(id));
        assertEq(timelock.getTimestamp(id), start + LibProdDeploy.MIN_DELAY);
    }

    // 9
    function test_Execute_RevertsBeforeDelay() public {
        uint256 start = block.timestamp;
        bytes memory data = abi.encodeCall(MockTarget.setValue, (42));

        vm.prank(proposer1);
        timelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0),
            LibProdDeploy.MIN_DELAY
        );

        vm.warp(start + LibProdDeploy.MIN_DELAY - 1);
        // Operation is still Waiting, not Ready — bare expectRevert because the
        // selector payload is the expected-state bitmap which is implementation detail.
        vm.expectRevert();
        timelock.execute(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0)
        );
    }

    // 10
    function test_Execute_SucceedsAfterDelay_FromAnyAddress() public {
        uint256 start = block.timestamp;
        bytes memory data = abi.encodeCall(MockTarget.setValue, (42));

        vm.prank(proposer1);
        timelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0),
            LibProdDeploy.MIN_DELAY
        );

        vm.warp(start + LibProdDeploy.MIN_DELAY + 1);
        vm.prank(stranger);
        timelock.execute(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0)
        );

        assertEq(target.value(), 42);
        bytes32 id = timelock.hashOperation(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0)
        );
        assertTrue(timelock.isOperationDone(id));
    }

    // 11
    function test_Cancel_ByProposerWithCancellerRole() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (42));

        vm.prank(proposer1);
        timelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0),
            LibProdDeploy.MIN_DELAY
        );

        bytes32 id = timelock.hashOperation(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0)
        );

        // stranger can't cancel
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                stranger,
                CANCELLER_ROLE
            )
        );
        timelock.cancel(id);

        // proposer2 has CANCELLER_ROLE by construction
        vm.prank(proposer2);
        timelock.cancel(id);
        assertFalse(timelock.isOperation(id));
    }

    // 12
    function test_Schedule_RevertsWhenDelayTooShort() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (42));
        uint256 badDelay = LibProdDeploy.MIN_DELAY - 1;

        vm.prank(proposer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockInsufficientDelay.selector,
                badDelay,
                LibProdDeploy.MIN_DELAY
            )
        );
        timelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0),
            badDelay
        );
    }

    // 13
    function test_GrantRole_RevertsWhenCalledDirectly() public {
        vm.prank(proposer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                proposer1,
                DEFAULT_ADMIN_ROLE
            )
        );
        timelock.grantRole(CANCELLER_ROLE, newCanceller);
    }

    // 14
    function test_UpdateDelay_RevertsWhenCalledDirectly() public {
        // Direct call from an EOA must revert.
        vm.prank(proposer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnauthorizedCaller.selector,
                proposer1
            )
        );
        timelock.updateDelay(24 hours);

        // But scheduling and executing a self-call to updateDelay must succeed.
        uint256 start = block.timestamp;
        bytes memory data = abi.encodeCall(TimelockController.updateDelay, (24 hours));

        vm.prank(proposer1);
        timelock.schedule(
            address(timelock),
            0,
            data,
            bytes32(0),
            bytes32(0),
            LibProdDeploy.MIN_DELAY
        );

        vm.warp(start + LibProdDeploy.MIN_DELAY + 1);
        timelock.execute(
            address(timelock),
            0,
            data,
            bytes32(0),
            bytes32(0)
        );

        assertEq(timelock.getMinDelay(), 24 hours);
    }

    // 15
    function test_BatchFlow_GrantCancellerAndRevokeProposer1() public {
        uint256 start = block.timestamp;

        address[] memory targets = new address[](2);
        targets[0] = address(timelock);
        targets[1] = address(timelock);

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        bytes[] memory payloads = new bytes[](2);
        payloads[0] = abi.encodeCall(IAccessControl.grantRole, (CANCELLER_ROLE, newCanceller));
        payloads[1] = abi.encodeCall(IAccessControl.revokeRole, (CANCELLER_ROLE, proposer1));

        vm.prank(proposer1);
        timelock.scheduleBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            bytes32(0),
            LibProdDeploy.MIN_DELAY
        );

        vm.warp(start + LibProdDeploy.MIN_DELAY + 1);
        timelock.executeBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            bytes32(0)
        );

        assertTrue(timelock.hasRole(CANCELLER_ROLE, newCanceller));
        assertFalse(timelock.hasRole(CANCELLER_ROLE, proposer1));
        // PROPOSER_ROLE must be untouched.
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer1));
    }
}
