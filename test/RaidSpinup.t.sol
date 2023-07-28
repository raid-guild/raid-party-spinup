// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Test, console2 } from "forge-std/Test.sol";
import {
  RSTestSetup, RSTestSetupWithDeploy, RSTestSetupWithFork, MultiHatsSignerGate, SmartInvoiceSplitEscrow
} from "./RSTest.t.sol";
import { IGnosisSafe } from "hats-zodiac/Interfaces/IGnosisSafe.sol";
import { RaidSpinup } from "../src/RaidSpinup.sol";
import {
  LibRaidRoles as Lib,
  RSEvents,
  Roles,
  RaidData,
  InvalidArrayLength,
  NotCleric,
  NotRaidParty,
  MissingCleric,
  ClosedRaid
} from "../src/LibRaidSpinup.sol";

contract DeployTest is RSTestSetup {
  // function setUp() public override { }

  function test_deploy() public {
    rs = new RaidSpinup(
            DAO,
            address(_hats),
            address(_hsgFactory),
            address(_siFactory),
            COMMITMENT,
            ARBITRATOR,
            topHat,
            _raidManagerHat,
            clericHat,
            RAID_IMAGE,
            ROLE_KEYS
        );
    assertEq(rs.dao(), DAO);
    assertEq(address(rs.hsgFactory()), address(_hsgFactory));
    assertEq(address(rs.siFactory()), address(_siFactory));
    assertEq(rs.invoiceArbitrator(), ARBITRATOR);
    assertEq(rs.commitmentContract(), COMMITMENT);
    assertEq(rs.raidImageUri(), RAID_IMAGE);
    assertEq(rs.getHatsContract(), address(_hats));
    assertEq(rs.roleImageUris(Roles(0)), ROLE_KEYS[0]);
    assertEq(rs.roleImageUris(Roles(NUM_ROLES - 1)), ROLE_KEYS[NUM_ROLES - 1]);
    assertEq(rs.raidManagerHat(), _raidManagerHat);
    assertEq(rs.guildClericHat(), clericHat);
  }

  function test_deploy_invalidArrayLength() public {
    tooManyImages = ROLE_KEYS;
    tooManyImages.push("extra");

    vm.expectRevert(InvalidArrayLength.selector);
    new RaidSpinup(
            DAO,
            _HATS,
            address(_hsgFactory),
            WI_FACTORY,
            COMMITMENT,
            ARBITRATOR,
            topHat,
            _raidManagerHat,
            clericHat,
            RAID_IMAGE,
            tooManyImages
        );
  }
}

contract CreateRaidTest is RSTestSetupWithDeploy {
  function setUp() public override {
    super.setUp();

    invoiceAmounts = [100, 200];
    invoiceTerminationTime = block.timestamp + 1 days;
    invoiceDetails = "invoiceDetails";
    raiders = [
      address(0), // 0 -- cleric
      address(0), // 1 -- monk
      address(0), // 2 -- warrior
      address(0), // 3 -- wizard
      address(0), // 4 -- archer
      address(0), // 5 -- scribe
      address(0), // 6 -- hunter
      address(0), // 7 -- ranger
      address(0), // 8 -- bard
      address(0), // 9 -- paladin
      address(0), // 10 -- alchemist
      address(0), // 11 -- necromancer
      address(0), // 12 -- druid
      address(0), // 13 -- angry dwarf
      address(0) // 14 -- rogue
    ];
  }

  function test_createRaid_clericOnly() public {
    roles = 0x2;
    raiders[0] = cleric;

    vm.prank(cleric);
    uint256 raidId =
      rs.createRaid(roles, raiders, client, WXDAI, invoiceAmounts, invoiceTerminationTime, invoiceDetails);

    // Raid assertions ----------------
    (uint16 retroles, bool retactive, address retsignerGate, address retsmartInvoice) = rs.raids(raidId);
    assertEq(retroles, roles);
    assertTrue(retactive);

    // SignerGate assertions ----------------
    MultiHatsSignerGate mhsg = MultiHatsSignerGate(retsignerGate);
    assertEq(mhsg.minThreshold(), _MIN_THRESHOLD);
    assertEq(mhsg.targetThreshold(), _TARGET_THRESHOLD);
    assertEq(mhsg.maxSigners(), _MAX_SIGNERS);

    // Safe assertions ----------------
    address safe = address(mhsg.safe());
    assertEq(IGnosisSafe(safe).getThreshold(), 1);

    // Hats assertions ----------------
    uint256 clericRaidHat = _hats.buildHatId(raidId, 2 /* cleric */ );
    assertEq(_hats.buildHatId(_raidManagerHat, 1), raidId);
    assertTrue(_hats.isWearerOfHat(cleric, clericRaidHat));

    (string memory details,,,,,, uint16 lastHatId,,) = _hats.viewHat(raidId);
    assertEq(lastHatId, NUM_ROLES);
    assertEq(details, string.concat("Raid ", vm.toString(raidId)));

    (details,,,,,,,,) = _hats.viewHat(clericRaidHat);
    assertEq(details, string.concat("Raid ", vm.toString(raidId), " Cleric"));

    // SmartInvoiceSplitEscrow assertions ----------------
    SmartInvoiceSplitEscrow si = SmartInvoiceSplitEscrow(payable(retsmartInvoice));
    smartInvoiceAssertions(si, safe);
  }

  function test_createRaid_allRoles_allRaiders() public {
    roles = 0xFFFF; // 0b1111111111111111
    raiders[0] = cleric;
    raiders[1] = monk;
    raiders[2] = warrior;
    raiders[3] = wizard;
    raiders[4] = archer;
    raiders[5] = scribe;
    raiders[6] = hunter;
    raiders[7] = ranger;
    raiders[8] = bard;
    raiders[9] = paladin;
    raiders[10] = alchemist;
    raiders[11] = necromancer;
    raiders[12] = druid;
    raiders[13] = angryDwarf;
    raiders[14] = rogue;

    vm.prank(cleric);
    uint256 raidId =
      rs.createRaid(roles, raiders, client, WXDAI, invoiceAmounts, invoiceTerminationTime, invoiceDetails);

    // Raid assertions ----------------
    (uint16 retroles, bool retactive, address retsignerGate, address retsmartInvoice) = rs.raids(raidId);
    assertEq(retroles, roles);
    assertTrue(retactive);

    // SignerGate assertions ----------------
    MultiHatsSignerGate mhsg = MultiHatsSignerGate(retsignerGate);
    assertEq(mhsg.minThreshold(), _MIN_THRESHOLD);
    assertEq(mhsg.targetThreshold(), _TARGET_THRESHOLD);
    assertEq(mhsg.maxSigners(), _MAX_SIGNERS);

    // Safe assertions ----------------
    address safe = address(mhsg.safe());
    assertEq(IGnosisSafe(safe).getThreshold(), 1);

    // Hats assertions ----------------
    uint256 clericRaidHat = _hats.buildHatId(raidId, 2 /* cleric */ );
    assertEq(_hats.buildHatId(_raidManagerHat, 1), raidId);
    assertTrue(_hats.isWearerOfHat(cleric, clericRaidHat));

    (string memory details,,,,,, uint16 lastHatId,,) = _hats.viewHat(raidId);
    assertEq(lastHatId, NUM_ROLES);
    assertEq(details, string.concat("Raid ", vm.toString(raidId)));

    (details,,,,,,,,) = _hats.viewHat(clericRaidHat);
    assertEq(details, string.concat("Raid ", vm.toString(raidId), " Cleric"));

    // SmartInvoiceSplitEscrow assertions ----------------
    SmartInvoiceSplitEscrow si = SmartInvoiceSplitEscrow(payable(retsmartInvoice));
    smartInvoiceAssertions(si, safe);
  }

  function smartInvoiceAssertions(SmartInvoiceSplitEscrow _si, address _safe) internal {
    assertEq(_si.provider(), _safe);
    assertEq(_si.client(), client);
    assertEq(uint(_si.resolverType()), 1); // TODO change if not hardcoded in RaidSpinup.sol
    assertEq(_si.resolver(), rs.invoiceArbitrator());
    assertEq(_si.token(), WXDAI);
    assertEq(_si.terminationTime(), invoiceTerminationTime);
    assertEq(_si.resolutionRate(), 20); // 20 = default value TODO test further
    assertEq(_si.details(), invoiceDetails);
    assertEq(_si.wrappedNativeToken(), _siFactory.wrappedNativeToken());
    assertEq(_si.dao(), DAO);
    assertEq(_si.daoFee(), 1000); // TODO change if not hardcoded in RaidSpinup.sol
    assertEq(_si.wrappedNativeToken(), _siFactory.wrappedNativeToken());
  } 
}

contract InternalNonRaidFunctionsTest is RaidSpinup, RSTestSetup {
  uint256 internal constant TOP_HAT = 0x00000001 << (16 * 14);
  uint256 internal constant RAID_MANAGER_HAT = 0x000000010001 << (16 * 13);
  uint256 internal constant CLERIC_HAT = 0x000000010002 << (16 * 13);
  address internal constant DAO_ = 0x952687863142ce6f9cFE7D264C5AF405642F6AA8; // makeAddr("dao");
  address internal constant COMMITMENT_ = 0x2552325dB3228c9E2C8FeD9e915fE58Bd895D4d0; // makeAddr("commitment")
  address internal constant ARBITRATOR_ = 0xA2DE859fC0d8B01241993d48A78B4e0742B068c9; // makeAddr("arbitrator")

  uint256 counter;

  constructor()
    RaidSpinup(
      DAO_,
      _HATS,
      address(_hsgFactory),
      WI_FACTORY,
      COMMITMENT_,
      ARBITRATOR_,
      TOP_HAT,
      RAID_MANAGER_HAT,
      CLERIC_HAT,
      RAID_IMAGE,
      ROLE_KEYS
    )
  { }

  function setUp() public override {
    super.setUp();
    clericHat = CLERIC_HAT;
  }

  function test_internal_generateRaidHatDetails() public {
    string memory details = _generateRaidHatDetails(1);
    assertEq(details, "Raid 1");
  }

  function test_internal_generateRoleHatDetails() public {
    string memory raidDetails = "Details From Raid X";
    string memory details = _generateRoleHatDetails(Roles.Cleric, raidDetails);
    assertEq(details, string.concat(raidDetails, " Cleric"));
  }

  function test_internal_newRaidData() public {
    RaidData memory rd = _newRaidData(2, address(0x3), address(0x4));
    assertEq(rd.roles, 2);
    assertEq(rd.smartInvoiceSplitEscrow, address(0x3));
    assertEq(rd.signerGate, address(0x4));
    assertTrue(rd.active);
  }

  // function mockClericFunction(address account) public {
  //     _checkValidCleric(account);
  //     ++counter;
  // }

  // function test_internal_checkValidCleric_valid() public {
  //     // FIXME
  //     assertEq(clericHat, this.guildClericHat());
  //     mockIsWearerCall(cleric, clericHat, true);
  //     mockClericFunction(cleric);
  //     assertEq(counter, 1);
  // }

  // function test_internal_checkValidCleric_invalid() public {
  //     // FIXME
  //     assertEq(clericHat, this.guildClericHat());
  //     assertEq(_HATS, this.getHatsContract());
  //     assertFalse(_hats.isWearerOfHat(other, clericHat));
  //     mockIsWearerCall(other, CLERIC_HAT, false);
  //     vm.expectRevert(NotCleric.selector);
  //     mockClericFunction(other);
  // }
}

contract InternalCreateRaidFunctionsTest is RaidSpinup, RSTestSetup {
  uint256 internal constant TOP_HAT = 0x00000001 << (16 * 14);
  uint256 internal constant RAID_MANAGER_HAT = 0x000000010001 << (16 * 13);
  uint256 internal constant CLERIC_HAT = 0x000000010002 << (16 * 13);
  address internal constant DAO_ = 0x952687863142ce6f9cFE7D264C5AF405642F6AA8; // makeAddr("dao");
  address internal constant COMMITMENT_ = 0x2552325dB3228c9E2C8FeD9e915fE58Bd895D4d0; // makeAddr("commitment")
  address internal constant ARBITRATOR_ = 0xA2DE859fC0d8B01241993d48A78B4e0742B068c9; // makeAddr("arbitrator")

  constructor()
    RaidSpinup(
      DAO_,
      _HATS,
      address(_hsgFactory),
      WI_FACTORY,
      COMMITMENT_,
      ARBITRATOR_,
      TOP_HAT,
      RAID_MANAGER_HAT,
      CLERIC_HAT,
      RAID_IMAGE,
      ROLE_KEYS
    )
  {
    // console2.log("DAO", DAO);
    // console2.log("_HATS", _HATS);
    // console2.log("TOP_HAT", TOP_HAT);
    // console2.log("RAID_MANAGER_HAT", RAID_MANAGER_HAT);
    // console2.log("CLERIC_HAT", CLERIC_HAT);
    // console2.log("WI_FACTORY", WI_FACTORY);
    // console2.log("COMMITMENT", COMMITMENT);
    // console2.log("ARBITRATOR", ARBITRATOR);
    // console2.log("RAID_IMAGE", RAID_IMAGE);
  }

  function setUp() public override {
    super.setUp();
    vm.selectFork(gnosisFork);
    topHat = _hats.mintTopHat(DAO, "Raid Guild", "");
    vm.startPrank(DAO);
    _raidManagerHat = _hats.createHat(topHat, "Raid Manager", 1, DAO, DAO, true, "");
    clericHat = _hats.createHat(topHat, "Guild Cleric", 500, DAO, DAO, true, "");
    _hats.mintHat(clericHat, cleric);
    _hats.mintHat(_raidManagerHat, address(this));
    vm.stopPrank();

    roles = 0x2;
    raiders = [
      cleric, // cleric
      address(0), // monk
      address(0), // warrior
      address(0), // wizard
      address(0), // archer
      address(0), // scribe
      address(0), // hunter
      address(0), // ranger
      address(0), // bard
      address(0), // paladin
      address(0), // alchemist
      address(0), // necromancer
      address(0), // druid
      address(0), // angry dwarf
      address(0) // rogue
    ];
  }

  // FIXME
  function _internal_checkActiveRaid_succeeds_activeRaid() public {
    assertTrue(_hats.isWearerOfHat(cleric, this.guildClericHat()));
    assertEq(this.guildClericHat(), clericHat);
    assertTrue(_hats.isWearerOfHat(address(this), _raidManagerHat));
    assertTrue(_hats.isAdminOfHat(address(this), 0x0000000100010001000000000000000000000000000000000000000000000000));
    vm.prank(cleric);

    // call createRaid on self to treat it as an external call, so it handles storage pointer inputs as calldata arrays
    // correctly
    uint256 raidId =
      this.createRaid(roles, raiders, client, WXDAI, invoiceAmounts, invoiceTerminationTime, invoiceDetails);

    console2.log(raids[raidId].signerGate);
    console2.log(getRaidPartySignerGate(raidId));
    console2.log(raids[raidId].active);
    console2.log(getRaidStatus(raidId));
    // assertTrue(raids[raidId].active);
    // _checkActiveRaid(raidId);
  }
}

contract RaidPartyFunctionsTest is RSTestSetup {
  // function setUp() public override { }
  // TODO with fork test

  function test_validRole_revertsForInvalidRole() public { }
}

contract GettersTest is RSTestSetup {
// TODO with fork test
}

contract OwnerSettersTest is RSTestSetupWithDeploy {
  // function setUp() public override { }

  function test_onlyOwner_revertsForNonOwner() public {
    address newHsgFactory = makeAddr("newHsgFactory");
    vm.expectRevert();
    rs.setHatsSignerGateFactory(newHsgFactory);
  }

  function test_setHatsSignerGateFactory() public {
    address newHsgFactory = makeAddr("newHsgFactory");
    mockIsWearerCall(DAO, topHat, true);
    vm.expectEmit(false, false, false, true);
    emit RSEvents.HatsSignerGateFactorySet(newHsgFactory);
    vm.prank(DAO);
    rs.setHatsSignerGateFactory(newHsgFactory);
    assertEq(address(rs.hsgFactory()), newHsgFactory);
  }

  function test_setSmartInvoiceFactory() public {
    address newSiFactory = makeAddr("newSiFactory");
    mockIsWearerCall(DAO, topHat, true);
    vm.expectEmit(false, false, false, true);
    emit RSEvents.SmartInvoiceFactorySet(newSiFactory);
    vm.prank(DAO);
    rs.setSmartInvoiceFactory(newSiFactory);
    assertEq(address(rs.siFactory()), newSiFactory);
  }

  function test_setInvoiceArbitratory() public {
    address newArbitrator = makeAddr("newArbitrator");
    mockIsWearerCall(DAO, topHat, true);
    vm.expectEmit(false, false, false, true);
    emit RSEvents.InvoiceArbitratorSet(newArbitrator);
    vm.prank(DAO);
    rs.setInvoiceArbitrator(newArbitrator);
    assertEq(rs.invoiceArbitrator(), newArbitrator);
  }

  function test_setCommitmentContract() public {
    address newCommitment = makeAddr("newCommitment");
    mockIsWearerCall(DAO, topHat, true);
    vm.expectEmit(false, false, false, true);
    emit RSEvents.CommitmentContractSet(newCommitment);
    vm.prank(DAO);
    rs.setCommitmentContract(newCommitment);
    assertEq(rs.commitmentContract(), newCommitment);
  }

  function test_setRaidManagerHat() public {
    uint256 newHat = 123;
    mockIsWearerCall(DAO, topHat, true);
    vm.expectEmit(false, false, false, true);
    emit RSEvents.RaidManagerHatSet(newHat);
    vm.prank(DAO);
    rs.setRaidManagerHat(newHat);
    assertEq(rs.raidManagerHat(), newHat);
  }

  function test_setGuildClericHat() public {
    uint256 newHat = 123;
    mockIsWearerCall(DAO, topHat, true);
    vm.expectEmit(false, false, false, true);
    emit RSEvents.GuildClericHatSet(newHat);
    vm.prank(DAO);
    rs.setGuildClericHat(newHat);
    assertEq(rs.guildClericHat(), newHat);
  }

  function test_setRaidImageUri() public {
    string memory newUri = "newUri";
    mockIsWearerCall(DAO, topHat, true);
    vm.expectEmit(false, false, false, true);
    emit RSEvents.RaidImageUriSet(newUri);
    vm.prank(DAO);
    rs.setRaidImageUri(newUri);
    assertEq(rs.raidImageUri(), newUri);
  }

  function test_setRoleImageUri() public {
    string memory newUri = "newUri";
    mockIsWearerCall(DAO, topHat, true);
    vm.startPrank(DAO);
    for (uint256 i; i < NUM_ROLES; i++) {
      vm.expectEmit(false, false, false, true);
      emit RSEvents.RoleImageUriSet(Roles(i), newUri);
      rs.setRoleImageUri(Roles(i), newUri);
      assertEq(rs.roleImageUris(Roles(i)), newUri);
    }
    vm.stopPrank();
  }

  function test_setMinThresholdOnRaidSafe() public {
    // TODO with fork test
  }

  function test_setMaxThresholdOnRaidSafe() public {
    // TODO with fork test
  }
}
