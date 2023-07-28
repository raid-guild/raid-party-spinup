// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

enum Roles {
  Client, // 0 with mask 0x0001, 0b0000000000000001
  Cleric, // 1 with mask 0x0002, 0b0000000000000010
  Monk, // 2 with mask 0x0004, 0b0000000000000100
  Warrior, // 3 with mask 0x0008, 0b0000000000001000
  Wizard, // 4 with mask 0x0010, 0b0000000000010000
  Archer, // 5 with mask 0x0020, 0b0000000000100000
  Scribe, // 6 with mask 0x0040, 0b0000000001000000
  Hunter, // 7 with mask 0x0080, 0b0000000010000000
  Ranger, // 8 with mask 0x0100, 0b0000000100000000
  Bard, // 9 with mask 0x0200, 0b0000001000000000
  Paladin, // 10 with mask 0x0400, 0b0000010000000000
  Alchemist, // 11 with mask 0x0800, 0b0000100000000000
  Necromancer, // 12 with mask 0x1000, 0b0001000000000000
  Druid, // 13 with mask 0x2000, 0b0010000000000000
  AngryDwarf, // 14 with mask 0x4000, 0b0100000000000000
  Rogue // 15 with mask 0x8000, 0b1000000000000000
}

struct RaidData {
  uint16 roles; // bitmap of roles
  bool active;
  address signerGate; // can retrieve the Safe from here
  address smartInvoiceSplitEscrow; // can retrieve invoice address from wrappedInvoice
}

error InvalidArrayLength();
error NotCleric();
error NotRaidParty();
error MissingCleric();
error ClosedRaid();

library LibRaidRoles {
  function mask(Roles _role) internal pure returns (uint16 _mask) {
    _mask = uint16(1 << uint8(_role));
  }

  function isIn(Roles _role, uint16 _roles) internal pure returns (bool hasRole) {
    hasRole = _roles & mask(_role) != 0;
  }

  function addTo(Roles _role, uint16 _roles) internal pure returns (uint16 _newRoles) {
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
    else revert();
  }
}

library RSEvents {
  // ============================================================
  // EVENTS
  // ============================================================

  event RaidCreated(uint256 raidId, address avatar, address signerGate, address wrappedInvoice);
  event HatsSignerGateFactorySet(address factory);
  event SmartInvoiceFactorySet(address factory);
  event InvoiceArbitratorSet(address arbitrator);
  event CommitmentContractSet(address commitment);
  event RaidManagerHatSet(uint256 hatId);
  event GuildClericHatSet(uint256 hatId);
  event RaidImageUriSet(string image);
  event RoleImageUriSet(Roles role, string imageUri);
  event RaidClosed(uint256 raidId, string comments);
}
