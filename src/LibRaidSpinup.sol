// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

enum Roles {
    Client, // 0
    Cleric, // 1
    Monk, // 2
    Warrior, // 3
    Wizard, // 4
    Archer, // 5
    Scribe, // 6
    Hunter, // 7
    Ranger, // 8
    Bard, // 9
    Paladin, // 10
    Alchemist, // 11
    Necromancer, // 12
    Druid, // 13
    AngryDwarf, // 14
    Rogue // 15
}

struct RaidData {
    uint16 roles; // bitmap of roles
    bool active;
    address avatar; // ie a Safe
    address signerGate;
    address wrappedInvoice; // can retrieve invoice address from wrappedInvoice
}

error InvalidArrayLength();
error NotCleric();
error NotRaidParty();
error MissingCleric();
error InvalidRole();

library LibRaidRoles {
    function mask(Roles _role) internal pure returns (uint16 _mask) {
        _mask = uint16(1 << uint8(_role));
    }

    function isIn(Roles _role, uint16 _roles) internal pure returns (bool hasRole) {
        hasRole = _roles & mask(_role) != 0;
    }

    function addTo(Roles _role, uint256 _roles) internal pure returns (uint256 _newRoles) {
        _newRoles = _roles | mask(_role);
    }

    function key(Roles _role) internal pure returns (string memory) {
        if (_role == Roles.Client) return "Client";
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
        else revert InvalidRole();
    }
}
