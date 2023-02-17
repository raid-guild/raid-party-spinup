// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Test, console2 } from "forge-std/Test.sol";
import { RSTest } from "./RSTest.t.sol";
import { RaidSpinup } from "../src/RaidSpinup.sol";
import {
    LibRaidRoles as Lib,
    Roles,
    RaidData,
    InvalidArrayLength,
    NotCleric,
    NotRaidParty,
    MissingCleric,
    InvalidRole,
    ClosedRaid
} from "../src/LibRaidSpinup.sol";

contract DeployTest is Test {
// function setUp() public override { }

// write a test for deploying a RaidSpinup contract
// function testDeployRaidSpinup() public {
//     RaidSpinup rs = new RaidSpinup();
//     console2.log("RaidSpinup deployed at address: ", address(raidSpinup));
// }
}
