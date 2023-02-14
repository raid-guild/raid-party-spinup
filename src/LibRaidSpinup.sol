// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

enum Roles {
    Cleric,
    Monk,
    Warrior,
    Wizard,
    Archer,
    Scribe,
    Hunter,
    Ranger,
    Bard,
    Paladin,
    Alchemist,
    Necromancer,
    Druid,
    AngryDwarf,
    Rogue
}

struct RaidData {
    uint16 roles;
    // TODO track uint16 hat ids for each role
    address raidPartyAvatar;
    // address signerGate // can retrieve from safe storage
    address invoice;
    bool active;
}

error NotCleric();
error NotRaidParty();
error MissingCleric();

library LibRaidRoles {
    function mask(Roles _role) internal pure returns (uint16 _mask) {
        _mask = uint16(1 << uint8(_role));
    }

    function isIn(Roles _role, uint16 _roles) internal pure returns (bool hasRole) {
        hasRole = _roles & mask(_role) != 0;
    }

    function key(Roles _role) internal pure returns (string memory) {
        if (_role == Roles.Cleric) return "Cleric";
        if (_role == Roles.Monk) return "Monk";
        if (_role == Roles.Warrior) return "Warrior";
        if (_role == Roles.Wizard) return "Wizard";
        if (_role == Roles.Archer) return "Archer";
        if (_role == Roles.Scribe) return "Scribe";
        if (_role == Roles.Hunter) return "Hunter";
        if (_role == Roles.Ranger) return "Ranger";
        if (_role == Roles.Bard) return "Bard";
        if (_role == Roles.Paladin) return "Paladin";
        if (_role == Roles.Alchemist) return "Alchemist";
        if (_role == Roles.Necromancer) return "Necromancer";
        if (_role == Roles.Druid) return "Druid";
        if (_role == Roles.AngryDwarf) return "Angry Dwarf";
        if (_role == Roles.Rogue) return "Rogue";
    }
}
