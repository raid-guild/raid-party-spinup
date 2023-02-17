// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Test, console2 } from "forge-std/Test.sol";
import { RSTest } from "./RSTest.t.sol";
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

contract MaskTest is RSTest {
    // function setUp() public override { }

    function test_mask() public {
        Roles role;
        uint16 m;
        for (uint256 i; i < NUM_ROLES; ++i) {
            role = Roles(i);
            m = Lib.mask(role);
            assertEq(m, 1 << i);
            // console2.logBytes(abi.encode(m));
        }
    }

    function test_mask_Client() public {
        uint16 m = Lib.mask(Roles.Client);
        assertEq(m, 1);
    }

    function test_mask_Rogue() public {
        uint16 m = Lib.mask(Roles.Rogue);
        assertEq(m, 32_768); // 1 << 15
    }

    function testFail_mask_invalidRole() public pure {
        Lib.mask(Roles(NUM_ROLES));
    }

    function test_gas_mask() public pure {
        Lib.mask(Roles.Rogue);
    }
}

contract IsInTest is RSTest {
    function test_isIn() public {
        uint16 roles = 0x3; // 0b0000000000000011
        assertTrue(Lib.isIn(Roles.Client, roles));
        assertTrue(Lib.isIn(Roles.Cleric, roles));
        assertFalse(Lib.isIn(Roles.Monk, roles));
        assertFalse(Lib.isIn(Roles.Rogue, roles));

        roles = 0x7; // 0b0000000000000111
        assertTrue(Lib.isIn(Roles.Client, roles));
        assertTrue(Lib.isIn(Roles.Cleric, roles));
        assertTrue(Lib.isIn(Roles.Monk, roles));
        assertFalse(Lib.isIn(Roles.Warrior, roles));
        assertFalse(Lib.isIn(Roles.Rogue, roles));

        roles = 0xAAAA; // 0b1010101010101010
        assertFalse(Lib.isIn(Roles.Client, roles));
        assertTrue(Lib.isIn(Roles.Cleric, roles));
        assertFalse(Lib.isIn(Roles.Monk, roles));
        assertTrue(Lib.isIn(Roles.Warrior, roles));
        assertFalse(Lib.isIn(Roles.Wizard, roles));
        assertTrue(Lib.isIn(Roles.Archer, roles));
        assertFalse(Lib.isIn(Roles.Scribe, roles));
        assertTrue(Lib.isIn(Roles.Hunter, roles));
        assertFalse(Lib.isIn(Roles.Ranger, roles));
        assertTrue(Lib.isIn(Roles.Bard, roles));
        assertFalse(Lib.isIn(Roles.Paladin, roles));
        assertTrue(Lib.isIn(Roles.Alchemist, roles));
        assertFalse(Lib.isIn(Roles.Necromancer, roles));
        assertTrue(Lib.isIn(Roles.Druid, roles));
        assertFalse(Lib.isIn(Roles.AngryDwarf, roles));
        assertTrue(Lib.isIn(Roles.Rogue, roles));

        roles = 0x8000; // 0b1000000000000000
        assertTrue(Lib.isIn(Roles.Rogue, roles));
        assertFalse(Lib.isIn(Roles.Client, roles));
        assertFalse(Lib.isIn(Roles.AngryDwarf, roles));
    }

    function testFail_isIn_invalidRole() public pure {
        Lib.isIn(Roles(NUM_ROLES), 0x8000);
    }

    function test_gas_IsIn() public pure {
        Lib.isIn(Roles.Rogue, 0x8000);
    }
}

contract AddToTest is RSTest {
    function test_addTo() public {
        Roles role;
        uint16 roles;
        for (uint256 i; i < NUM_ROLES; ++i) {
            role = Roles(i);
            roles = Lib.addTo(role, roles);
            assertTrue(Lib.isIn(role, roles));
        }
    }

    function testFail_addTo_invalidRole() public pure {
        Lib.addTo(Roles(NUM_ROLES), 0x8000);
    }

    function test_gas_addTo() public pure {
        Lib.addTo(Roles.Rogue, 0x0);
    }

    function test_gas_addTo_existing() public pure {
        Lib.addTo(Roles.Rogue, 0x8000);
    }
}

contract KeyTest is RSTest {
    function test_key() public {
        for (uint256 i; i < NUM_ROLES; ++i) {
            assertEq(Lib.key(Roles(i)), ROLE_KEYS[i]);
        }
    }

    function testFail_key_invalidRole() public pure {
        Lib.key(Roles(NUM_ROLES));
    }

    function test_gas_key() public pure {
        Lib.key(Roles.Necromancer);
    }
}
