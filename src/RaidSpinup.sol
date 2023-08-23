// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { HatsOwned } from "hats-auth/HatsOwned.sol";
import { HatsSignerGateFactory } from "hats-zodiac/HatsSignerGateFactory.sol";
import { MultiHatsSignerGate } from "hats-zodiac/MultiHatsSignerGate.sol";
import { SmartInvoiceSplitEscrow } from "smart-invoice/SmartInvoiceSplitEscrow.sol";
import { SmartInvoiceFactory } from "smart-invoice/SmartInvoiceFactory.sol"; 
import { LibString } from "solady/utils/LibString.sol";
import {
  LibRaidRoles,
  RSEvents,
  Roles,
  RaidData,
  InvoiceArgs,
  InvalidArrayLength,
  NotCleric,
  NotRaidParty,
  MissingCleric,
  ClosedRaid
} from "./LibRaidSpinup.sol";
import { Test, console2 } from "forge-std/Test.sol"; // remove after testing

/// @title Raid Spinup
/// @notice creates new Raids complete with a Raid Hat, Smart Invoice, Safe and Hats Signer Gate all child Hats for the client and all Raid members
/// @author TODO: fill in

contract RaidSpinup is HatsOwned {
  using LibRaidRoles for Roles;

  // ============================================================
  // STATE VARIABLES
  // ============================================================

  // Raid Guild's DAO contract or minion
  address public immutable dao;

  
  HatsSignerGateFactory public hsgFactory;
  SmartInvoiceFactory public siFactory;
  address public invoiceArbitrator;
  address public commitmentContract;
  string public raidImageUri;
  // standard images for each role
  mapping(Roles => string) public roleImageUris;

  uint256 public raidManagerHat;
  uint256 public guildClericHat;

  // sets a raid's id as its raid hat id
  // the alternative would be to store raids in an array and use a simple counter for the raid id
  mapping(uint256 => RaidData) public raids;

  // ============================================================
  // CONSTANTS
  // ============================================================

  uint32 internal constant MAX_RAIDERS_PER_ROLE = 5;
  uint256 internal constant MAX_ROLE_INDEX = 15; // uint256(type(Roles).max)
  uint256 internal constant MIN_THRESHOLD = 2;
  uint256 internal constant TARGET_THRESHOLD = 4;
  uint256 internal constant MAX_SIGNERS = 7;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  constructor(
    address _dao,
    address _hats,
    address _hsgFactory,
    address _smartInvoiceFactory,
    address _commitmentStaking,
    address _invoiceArbitrator,
    uint256 _ownerHat,
    uint256 _raidManagerHat,
    uint256 _clericHat,
    string memory _raidImageUri,
    string[] memory _roleImageUris
  ) payable HatsOwned(_ownerHat, _hats) {
    if (_roleImageUris.length != MAX_ROLE_INDEX + 1) revert InvalidArrayLength();

    dao = _dao;
    hsgFactory = HatsSignerGateFactory(_hsgFactory);
    siFactory = SmartInvoiceFactory(_smartInvoiceFactory);
    commitmentContract = _commitmentStaking;
    invoiceArbitrator = _invoiceArbitrator;
    raidManagerHat = _raidManagerHat;
    guildClericHat = _clericHat;
    raidImageUri = _raidImageUri;

    // assign role images to roleImages
    for (uint256 i; i < _roleImageUris.length;) {
      roleImageUris[Roles(i)] = _roleImageUris[i];
      unchecked {
        ++i;
      }
    }
  }

  // ============================================================
  // PUBLIC FUNCTIONS
  // ============================================================

  function getRaidRoleHat(uint256 _raidId, Roles _role) public view returns (uint256 roleHat) {
    // we add 1 to the role enum value to account for the raid hat (ie the admin)
    roleHat = HATS.buildHatId(_raidId, uint16(_role) + 1);
  }

  function getRaidPartyAvatar(uint256 _raidId) public view returns (address avatar) {
    avatar = address(MultiHatsSignerGate(raids[_raidId].signerGate).safe());
  }

  function getRaidPartySignerGate(uint256 _raidId) public view returns (address signerGate) {
    signerGate = raids[_raidId].signerGate;
  }

  function getRaidSmartInvoice(uint256 _raidId) public view returns (address invoice) {
    invoice = raids[_raidId].smartInvoiceSplitEscrow;
  }

  function getRaidStatus(uint256 _raidId) public view returns (bool status) {
    status = raids[_raidId].active;
  }

  // ============================================================
  // ONLY_CLERIC FUNCTIONS
  // ============================================================

  /**
   * @notice Spins up a new raid with the following components:
   *     - A Hat worn by and representing the raid party
   *     - Hats for all possible raid roles
   *     - A Safe multisig for the raid party, with signers gated by the role Hats
   *     - A Smart Invoice Split Escrow for the raid that splits payments between DAO and Safe multisig
   *     - A hat for the raid's client (not yet minted)
   *
   * Supports assignment of up to one raider per role. If there are multiple raiders per role, the raid party can mint
   * the relevant role hat to the
   * additinal raiders once the raid has been created
   *
   * @param _roles a bitmap of roles to be created for the raid
   * @param _raidHatDetails raid details - can be a string or an IPFS CID leading to a JSON object 
   * @param _raiders an array of addresses to be assigned to the raid roles. The mapping of address to role is
   * determined by the order of the array,
   * which must match order the Roles enum, excluding Roles.Client. If a given role is unspecified or not yet filled,
   * the address at that index must be set to address(0).
   * @param _client the address of the raid client
   * @param _invoiceArgs struct of invoice arguments containing:
   *      -token: the token to be used for the invoice
   *      -amounts: an array milestone amounts for the invoice
   *      -terminationTime: the exact invoice termination time at seconds since epoch
   *      -details: bytes-encoded details of the invoice
   * @return raidId the id of the newly created raid
   */
  function createRaid(
    uint16 _roles,
    string calldata _raidHatDetails,
    address[] calldata _raiders,
    address _client,
    InvoiceArgs calldata _invoiceArgs
  ) public onlyCleric returns (uint256 raidId) {
    // ensure that the roles contain a cleric
    if (!Roles.Cleric.isIn(_roles)) revert MissingCleric();
    // ensure that the _raiders array contains a valid cleric

    // Check that the cleric is valid. Ff it's msg.sender, we don't need to check because of onlyCleric modifier
    if (_raiders[0] != msg.sender) _checkValidCleric(_raiders[0]); // _raiders[0] is the cleric, ie
      // `uint256(Roles.Cleric) - 1`

    // 1. Create Raid hat, admin'd by the Raid Manager hat
    raidId = HATS.createHat({
      _admin: raidManagerHat,
      _details: _raidHatDetails,
      _maxSupply: 1,
      _eligibility: dao,
      _toggle: dao,
      _mutable: true,
      _imageURI: raidImageUri
    });

    // 2A. Create the client hat, but DON'T mint it and DON'T add it to MultiHatsSignerGate
    HATS.createHat({
      _admin: raidId,
      _details: _generateRoleHatDetails(Roles.Client),
      _maxSupply: 2
      _eligibility: dao,
      _toggle: dao,
      _mutable: true,
      _imageURI: roleImageUris[Roles.Client]
    });

    // 2B Create the cleric hat and mint it to the cleric
    HATS.mintHat(
      HATS.createHat({
        _admin: raidId,
        _details: _generateRoleHatDetails(Roles.Cleric),
        _maxSupply: 2,
        _eligibility: commitmentContract,
        _toggle: commitmentContract,
        _mutable: true,
        _imageURI: roleImageUris[Roles.Cleric]
      }),
      _raiders[0] // _raiders[0] is the cleric, ie `uint256(Roles.Cleric) - 1`
    );

    /* 3. Create non-client and non-cleric raid role hats and mint as appropriate to the `_raiders`
    For empty roles, create a mutable hat with all properties set to default values. This way, the same role will have
    the same child hat id across all raids. 
        Also adds raid role hatMIN_THRESHOLDs to the MultiHatsSignerGate */

    uint256[] memory signerHats = new uint256[](MAX_ROLE_INDEX);
    signerHats = _createRaidRoles(raidId, _roles, _raiders);

    // 4. Deploy MultiHatsSignerGate and Safe, with Raid Manager Hat as owner and raid role hats (from 2 and 3) as
    // signer hats
    (address mhsg, address payable safe) = hsgFactory.deployMultiHatsSignerGateAndSafe({
      _ownerHatId: raidManagerHat,
      _signersHatIds: signerHats,
      _minThreshold: MIN_THRESHOLD,
      _targetThreshold: TARGET_THRESHOLD,
      _maxSigners: MAX_SIGNERS
     });

    // 5. Mint Raid hat to Safe
    HATS.mintHat(raidId, safe);

    // 6. Deploy Smart Invoice, with Safe as provider
    address smartInvoice =
      _deploySmartInvoice(_client, safe, _invoiceArgs);

    // initialize raid and store it as active
    raids[raidId] = _newRaidData(_roles, smartInvoice, mhsg);

    // emit RaidCreated event
    emit RSEvents.RaidCreated(raidId, safe, mhsg, smartInvoice);
  }

  // ============================================================
  // ONLY_RAID_PARTY FUNCTIONS
  // ============================================================

  function addRoleToRaid(uint256 _raidId, Roles _role) public onlyRaidParty(_raidId) {
    RaidData storage raid = _checkActiveRaid(_raidId);
    uint256 roleHat = getRaidRoleHat(_raidId, _role);

    // update role hat with appropriate properties
    _updateRoleHat(roleHat, _role);

    // add _role to the raid's roles bitmap
    _role.addTo(raid.roles);
  }

  function mintRoleToRaider(Roles _role, uint256 _raidId, address _raider) public onlyRaidParty(_raidId) {
    _checkActiveRaid(_raidId);
    // derive role hat id from raid id and role
    uint256 roleHat = getRaidRoleHat(_raidId, _role);
    // mint role hat to raider
    HATS.mintHat(roleHat, _raider);
  }

  function addAndMintRaidRole(Roles _role, uint256 _raidId, address _raider) public onlyRaidParty(_raidId) {
    _checkActiveRaid(_raidId);
    uint256 roleHat = getRaidRoleHat(_raidId, _role);

    // update role hat with appropriate properties
    _updateRoleHat(roleHat, _role);

    // mint role hat to raider
    HATS.mintHat(roleHat, _raider);
  }

  function mintRaidClientHat(uint256 _raidId, address _client) public onlyRaidParty(_raidId) {
    _checkActiveRaid(_raidId);
    // derive role hat id from raid id and role
    uint256 clientHat = getRaidRoleHat(_raidId, Roles.Client);
    // mint role hat to client
    HATS.mintHat(clientHat, _client);
  }

  function closeRaid(uint256 _raidId, string calldata _comments) public onlyRaidParty(_raidId) {
    RaidData storage raid = _checkActiveRaid(_raidId);

    raid.active = false;

    emit RSEvents.RaidClosed(_raidId, _comments);
  }

  // ============================================================
  // ONLY_OWNER FUNCTIONS
  // ============================================================

  function setHatsSignerGateFactory(address _hsgFactory) public onlyOwner {
    hsgFactory = HatsSignerGateFactory(_hsgFactory);
    emit RSEvents.HatsSignerGateFactorySet(_hsgFactory);
  }

  function setSmartInvoiceFactory(address _siFactory) public onlyOwner {
    siFactory = SmartInvoiceFactory(_siFactory);
    emit RSEvents.SmartInvoiceFactorySet(_siFactory);
  }

  function setInvoiceArbitrator(address _invoiceArbitrator) public onlyOwner {
    invoiceArbitrator = _invoiceArbitrator;
    emit RSEvents.InvoiceArbitratorSet(_invoiceArbitrator);
  }

  function setCommitmentContract(address _commitmentContract) public onlyOwner {
    commitmentContract = _commitmentContract;
    emit RSEvents.CommitmentContractSet(_commitmentContract);
  }

  function setRaidManagerHat(uint256 _raidManagerHat) public onlyOwner {
    raidManagerHat = _raidManagerHat;
    emit RSEvents.RaidManagerHatSet(_raidManagerHat);
  }

  function setGuildClericHat(uint256 _guildClericHat) public onlyOwner {
    guildClericHat = _guildClericHat;
    emit RSEvents.GuildClericHatSet(_guildClericHat);
  }

  function setRaidImageUri(string calldata _imageUri) public onlyOwner {
    raidImageUri = _imageUri;
    emit RSEvents.RaidImageUriSet(_imageUri);
  }

  function setRoleImageUri(Roles _role, string calldata _imageUri) public onlyOwner {
    roleImageUris[_role] = _imageUri;
    emit RSEvents.RoleImageUriSet(_role, _imageUri);
  }

  function setMinThresholdOnRaidSafe(uint256 _raidId, uint256 _minThreshold) public onlyOwner {
    RaidData storage raid = _checkActiveRaid(_raidId);
    MultiHatsSignerGate(raid.signerGate).setMinThreshold(_minThreshold);
  }

  function setMaxThresholdOnRaidSafe(uint256 _raidId, uint256 _maxThreshold) public onlyOwner {
    RaidData storage raid = _checkActiveRaid(_raidId);
    MultiHatsSignerGate(raid.signerGate).setTargetThreshold(_maxThreshold);
  }

  // ============================================================
  // INTERNAL FUNCTIONS
  // ============================================================

  function _generateRoleHatDetails(Roles _role)
    internal
    pure
    returns (string memory details)
  {
    details = string.concat(_role.key());
  }

  function _updateRoleHat(uint256 _roleHat, Roles _role) internal {
    // update role hat with appropriate properties
    HATS.changeHatDetails(_roleHat, _generateRoleHatDetails(_role));
    HATS.changeHatMaxSupply(_roleHat, MAX_RAIDERS_PER_ROLE);
    HATS.changeHatImageURI(_roleHat, roleImageUris[_role]);
  }

  function _createRaidRoles(uint256 _raidId, uint16 _roles, address[] calldata _raiders)
    internal
    returns (uint256[] memory signerHats)
  {
    // console2.log("Creating roles for raid", _raidId);
    uint256 roleHat;
    Roles role;
    address raider;
    signerHats = new uint256[](MAX_ROLE_INDEX + 1);

    for (uint256 i; i < MAX_ROLE_INDEX - 1;) {
      // console2.log("Creating role", i + 2);
      role = Roles(i + 2); // skip the Client and Cleric roles, which were already created
      // Create a hat for each specified role
      if (role.isIn(_roles)) {
        // console2.log("Creating hat for filled role", i + 2);
        roleHat = HATS.createHat({
          _admin: _raidId,
          _details: _generateRoleHatDetails(role),
          _maxSupply: MAX_RAIDERS_PER_ROLE,
          _eligibility: commitmentContract,
          _toggle: commitmentContract,
          _mutable: true,
          _imageURI: roleImageUris[role]
        });
        // console2.log("Created hat", roleHat);

        raider = _raiders[i + 1]; // skip the cleric, who already has a hat
        // if filled, mint the hat to the specified raider
        if (raider != address(0)) {
          // console2.log("Minting hat to raider", i + 1);
          HATS.mintHat(roleHat, raider);
        }
      } else {
        // console2.log("Creating blank hat for unfilled role", i + 2);
        roleHat = HATS.createHat({
          _admin: _raidId,
          _details: "",
          _maxSupply: 0,
          _eligibility: address(1), // has to be 0x1 since Hats.sol reverts on 0x0
          _toggle: address(1), // has to be 0x1 since Hats.sol reverts on 0x0
          _mutable: true,
          _imageURI: ""
        });
      }
      // console2.log("Created hat", roleHat);
      // add roleHat to the signerHats array
      signerHats[i] = roleHat;
      // console2.log("Added hat to signerHats", signerHats[i]);

      unchecked {
        ++i;
      }
    }
  }

  function _deploySmartInvoice(
    address _client,
    address _safe,
    InvoiceArgs calldata _invoiceArgs
  ) internal returns (address smartInvoice) {

    bytes memory _data = abi.encode(
      _client, // _client
      1, // _resolverType (1 = ARBITRATOR)
      invoiceArbitrator, //_resolver
      _invoiceArgs.token, // _token
      _invoiceArgs.terminationTime, // _terminationTime
      _invoiceArgs.details, // _details
      siFactory.wrappedNativeToken(), //_wrappedNativeToken
      true, //_requireVerification
      address(siFactory), //_factory
      dao, // _dao
      1000 // _daoFee (10% in basis points) 
    );

    smartInvoice = siFactory.create( _safe, _invoiceArgs.amounts, _data, "split-escrow");
  }

  function _newRaidData(uint16 _roles, address _smartInvoiceSplitEscrow, address _signerGate)
    internal
    pure
    returns (RaidData memory raid)
  {
    raid.active = true;
    raid.roles = _roles;
    raid.smartInvoiceSplitEscrow = _smartInvoiceSplitEscrow;
    raid.signerGate = _signerGate;
  }

  function _checkActiveRaid(uint256 _raidId) internal view returns (RaidData storage raid) {
    raid = raids[_raidId];
    if (!raid.active) revert ClosedRaid();
  }

  function _checkValidCleric(address _account) internal view {
    if (!HATS.isWearerOfHat(_account, guildClericHat)) revert NotCleric();
  }

  // ============================================================
  // MODIFIERS
  // ============================================================

  modifier onlyCleric() {
    // revert if msg.sender is not wearing an RG Cleric hat
    _checkValidCleric(msg.sender);
    _;
  }

  modifier onlyRaidParty(uint256 _raidId) {
    uint256 clericHat = getRaidRoleHat(_raidId, Roles.Cleric);
    // revert if msg.sender is not wearing the raid cleric or raid party hat
    if (!HATS.isWearerOfHat(msg.sender, _raidId) && !HATS.isWearerOfHat(msg.sender, clericHat)) {
      revert NotRaidParty();
    }
    _;
  }

  modifier activeRaid(uint256 _raidId) {
    if (!raids[_raidId].active) revert ClosedRaid();
    _;
  }
}
