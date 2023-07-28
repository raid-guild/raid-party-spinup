// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Test, console2 } from "forge-std/Test.sol";
import { RaidSpinup } from "../src/RaidSpinup.sol";
import { Roles } from "../src/LibRaidSpinup.sol";
import { Hats } from "hats-protocol/Hats.sol";
// import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { HatsSignerGateFactory } from "hats-zodiac/HatsSignerGateFactory.sol";
import { HatsSignerGate } from "hats-zodiac/HatsSignerGate.sol";
import { MultiHatsSignerGate } from "hats-zodiac/MultiHatsSignerGate.sol";
// import { SmartInvoiceFactory } from "smart-invoice/SmartInvoiceFactory.sol";
// import { SmartInvoice } from "smart-invoice/SmartInvoice.sol";
// import { WrappedInvoiceFactory } from "smart-escrow/WrappedInvoiceFactory.sol";
// import { WrappedInvoice } from "smart-escrow/WrappedInvoice.sol";
import { SmartInvoiceSplitEscrow } from "smart-invoice/SmartInvoiceSplitEscrow.sol";
import { SmartInvoiceFactory } from "smart-invoice/SmartInvoiceFactory.sol"; 

import "../lib/hats-zodiac/test/HSGFactoryTestSetup.t.sol";

contract RSTestSetup is Test {
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

  string internal constant RAID_IMAGE = "https://raid-image.com";
  bytes32 internal constant INVOICE_TYPE = "split-escrow";
  uint256 internal constant _MIN_THRESHOLD = 2;
  uint256 internal constant _TARGET_THRESHOLD = 4;
  uint256 internal constant _MAX_SIGNERS = 9;
  

  // Gnosis Chain deployments for fork testing

  address internal constant _HATS = 0x96bD657Fcc04c71B47f896a829E5728415cbcAa1;
  address internal constant WI_FACTORY = 0x6e769470F6F8D99794e53C87Fd8254E5D4FeDb8B;
  address internal constant HSG_FACTORY = 0x2869CdFB9B33f84B60020826bD83F0bA01a1c0F0;
  address internal constant WXDAI = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d;

  // ============================================================
  // STATE VARIABLES
  // ============================================================

  RaidSpinup internal rs;
  Hats internal _hats;
  HatsSignerGateFactory internal _hsgFactory;
  SmartInvoiceFactory internal _siFactory;

  address internal DAO;
  address internal COMMITMENT;
  address internal ARBITRATOR;
  address internal client;
  address internal cleric;
  address internal monk;
  address internal warrior;
  address internal wizard;
  address internal archer;
  address internal scribe;
  address internal hunter;
  address internal ranger;
  address internal bard;
  address internal paladin;
  address internal alchemist;
  address internal necromancer;
  address internal druid;
  address internal angryDwarf;
  address internal rogue;
  address internal other;

  uint256 internal topHat = 1;
  uint256 internal _raidManagerHat = 2;
  uint256 internal clericHat = 3;

  uint256 gnosisFork;

  string[] tooManyImages;

  uint16 internal roles;
  address[] internal raiders;
  uint256[] internal invoiceAmounts;
  uint256 internal invoiceTerminationTime;
  bytes32 internal invoiceDetails;

  function setUp() public virtual {
    DAO = makeAddr("dao");
    COMMITMENT = makeAddr("commitment");
    ARBITRATOR = makeAddr("arbitrator");
    client = makeAddr("client");
    cleric = makeAddr("cleric");
    monk = makeAddr("monk");
    warrior = makeAddr("warrior");
    wizard = makeAddr("wizard");
    archer = makeAddr("archer");
    scribe = makeAddr("scribe");
    hunter = makeAddr("hunter");
    ranger = makeAddr("ranger");
    bard = makeAddr("bard");
    paladin = makeAddr("paladin");
    alchemist = makeAddr("alchemist");
    necromancer = makeAddr("necromancer");
    druid = makeAddr("druid");
    angryDwarf = makeAddr("angryDwarf");
    rogue = makeAddr("rogue");
    other = makeAddr("other");

    // _hats = IHats(_HATS);
    // _wiFactory = WrappedInvoiceFactory(WI_FACTORY);
    // _hsgFactory = HatsSignerGateFactory(HSG_FACTORY);
    _hats = deployHats();
    _siFactory = deploySIFactoryAndDeps();
    _hsgFactory = deployHSGFactoryAndDeps();

    gnosisFork = vm.createFork(vm.envString("GC_RPC"), 26_545_541);
  }

  function deployHats() public returns (Hats hats) {
    hats = new Hats("Test Hats Protocol", "xyz.hatsprotocol.image");
  }

  function deploySIFactoryAndDeps() public returns (SmartInvoiceFactory siFactory) {
    address si = address(new SmartInvoiceSplitEscrow());
    siFactory = new SmartInvoiceFactory(WXDAI);

    siFactory.addImplementation(INVOICE_TYPE, si);
  }

  function deployHSGFactoryAndDeps() public returns (HatsSignerGateFactory hsgFactory) {
    address gnosisFallbackLibrary = address(bytes20("fallback"));
    address gnosisMultisendLibrary = address(new MultiSend());
    address singletonSafe = address(new GnosisSafe());
    address safeFactory = address(new GnosisSafeProxyFactory());
    address moduleProxyFactory = address(new ModuleProxyFactory());
    address singletonHatsSignerGate = address(new HatsSignerGate());
    address singletonMultiHatsSignerGate = address(new MultiHatsSignerGate());
    hsgFactory = new HatsSignerGateFactory(
            singletonHatsSignerGate,
            singletonMultiHatsSignerGate,
            address(_hats),
            singletonSafe,
            gnosisFallbackLibrary,
            gnosisMultisendLibrary,
            safeFactory,
            moduleProxyFactory,
            "Test HSG_FACTORY"
        );
  }

  function mockIsWearerCall(address wearer, uint256 hat, bool result) public {
    bytes memory data = abi.encodeWithSignature("isWearerOfHat(address,uint256)", wearer, hat);
    vm.mockCall(address(_hats), data, abi.encode(result));
  }
}

contract RSTestSetupWithDeploy is RSTestSetup {
  function setUp() public virtual override {
    super.setUp();

    topHat = _hats.mintTopHat(DAO, "Raid Guild", "");
    vm.startPrank(DAO);
    _raidManagerHat = _hats.createHat(topHat, "Raid Manager", 1, DAO, DAO, true, "");
    clericHat = _hats.createHat(topHat, "Guild Cleric", 500, DAO, DAO, true, "");
    _hats.mintHat(clericHat, cleric);

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

    _hats.mintHat(_raidManagerHat, address(rs));
    vm.stopPrank();
  }
}

contract RSTestSetupWithFork is RSTestSetup {
  function setUp() public virtual override {
    super.setUp();
    vm.selectFork(gnosisFork);

    topHat = _hats.mintTopHat(DAO, "Raid Guild", "");
    vm.startPrank(DAO);
    _raidManagerHat = _hats.createHat(topHat, "Raid Manager", 1, DAO, DAO, true, "");
    clericHat = _hats.createHat(topHat, "Guild Cleric", 500, DAO, DAO, true, "");
    _hats.mintHat(clericHat, cleric);

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

    _hats.mintHat(_raidManagerHat, address(rs));
    vm.stopPrank();
  }
}
