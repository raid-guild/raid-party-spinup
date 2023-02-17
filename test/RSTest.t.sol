// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Test, console2 } from "forge-std/Test.sol";
import { RaidSpinup } from "../src/RaidSpinup.sol";
import {
    LibRaidRoles,
    Roles,
    RaidData,
    InvalidArrayLength,
    NotCleric,
    NotRaidParty,
    MissingCleric,
    InvalidRole,
    ClosedRaid
} from "../src/LibRaidSpinup.sol";

contract RSTest is Test {
    // ============================================================
    // CONSTANTS
    // ============================================================

    uint8 internal constant NUM_ROLES = uint8(type(Roles).max) + 1;

    string internal constant CLIENT = "Client";
    string internal constant CLERIC = "Cleric";
    string internal constant MONK = "Monk";
    string internal constant WARRIOR = "Warrior";
    string internal constant WIZARD = "Wizard";
    string internal constant ARCHER = "Archer";
    string internal constant SCRIBE = "Scribe";
    string internal constant HUNTER = "Hunter";
    string internal constant RANGER = "Ranger";
    string internal constant BARD = "Bard";
    string internal constant PALADIN = "Paladin";
    string internal constant ALCHEMIST = "Alchemist";
    string internal constant NECROMANCER = "Necromancer";
    string internal constant DRUID = "Druid";
    string internal constant ANGRYDWARF = "Angry Dwarf";
    string internal constant ROGUE = "Rogue";

    string[] internal ROLE_KEYS = [
        CLIENT,
        CLERIC,
        MONK,
        WARRIOR,
        WIZARD,
        ARCHER,
        SCRIBE,
        HUNTER,
        RANGER,
        BARD,
        PALADIN,
        ALCHEMIST,
        NECROMANCER,
        DRUID,
        ANGRYDWARF,
        ROGUE
    ];

    // ============================================================
    // STATE VARIABLES
    // ============================================================

    function setUp() public virtual { }
}
