// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Roles } from "./LibRaidSpinup.sol";

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
