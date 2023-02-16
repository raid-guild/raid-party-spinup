// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { HatsOwned } from "hats-auth/HatsOwned.sol";
import { HatsSignerGateFactory } from "hats-zodiac/HatsSignerGateFactory.sol";
import { IWrappedInvoiceFactory } from "smart-escrow/interfaces/IWrappedInvoiceFactory.sol";
import { LibString } from "solady/utils/LibString.sol";
import { LibRaidRoles, Roles, RaidData, NotCleric, NotRaidParty, MissingCleric } from "./LibRaidSpinup.sol";

contract RaidSpinup is HatsOwned {
    using LibRaidRoles for Roles;

    // EVENTS

    event RaidCreated(uint256 raidId, address raidPartyAvatar, address raidInvoice);
    event HatsSignerGateFactorySet(address factory);
    event WrappedInvoiceFactorySet(address factory);
    event InvoiceArbitratorSet(address arbitrator);
    event CommitmentContractSet(address commitment);
    event RaidManagerHatSet(uint256 hatId);
    event GuildClericHatSet(uint256 hatId);
    event RaidImageUriSet(string image);
    event RoleImageUriSet(Roles role, string imageUri);

    // STORAGE

    // Raid Guild's DAO contract or minion
    address public immutable DAO;

    HatsSignerGateFactory public HSG_FACTORY;
    IWrappedInvoiceFactory public WRAPPED_INVOICE_FACTORY;
    address public INVOICE_ARBITRATOR;
    address public COMMITMENT;
    string public raidImageUri;
    // standard images for each role
    mapping(Roles => string) public roleImageUris;

    uint256 public raidManagerHat;
    uint256 public guildClericHat;

    // sets a raid's id as its raid hat id
    // the alternative would be to store raids in an array and use a simple counter for the raid id
    mapping(uint256 => RaidData) public raids;

    // CONSTANTS

    string internal constant RAID_DETAILS_PRE = "Raid ";

    // CONSTRUCTOR

    constructor(
        address _dao,
        address _hats,
        address _hsgFactory,
        address _wrappedInvoiceFactory,
        address _commitmentStaking,
        address _invoiceArbitrator,
        uint256 _ownerHat,
        uint256 _raidManagerHat,
        uint256 _clericHat,
        string memory _raidImageUri,
        string[] memory _roleImageUris
    ) payable HatsOwned(_ownerHat, _hats) {
        DAO = _dao;
        HSG_FACTORY = HatsSignerGateFactory(_hsgFactory);
        WRAPPED_INVOICE_FACTORY = IWrappedInvoiceFactory(_wrappedInvoiceFactory);
        COMMITMENT = _commitmentStaking;
        INVOICE_ARBITRATOR = _invoiceArbitrator;
        raidManagerHat = _raidManagerHat;
        guildClericHat = _clericHat;
        raidImageUri = _raidImageUri;

        // assign role images to roleImages
        // TODO ensure that _roleImageUris.length == Roles enum length
        for (uint256 i; i < _roleImageUris.length;) {
            roleImageUris[Roles(i)] = _roleImageUris[i];
            unchecked {
                ++i;
            }
        }
    }

    // PUBLIC FUNCTIONS

    function getRaidRoleHat(uint256 _raidId, Roles _role) public view returns (uint256 roleHat) {
        // we add 1 to the role enum value to account for the raid hat (ie the admin)
        roleHat = HATS.buildHatId(_raidId, uint16(_role) + 1);
    }

    // ONLY_CLERIC FUNCTIONS

    /**
     * @notice Spins up a new raid with the following components:
     *     - A Hat worn by and representing the raid party
     *     - Hats for all possible raid roles
     *     - A Safe multisig for the raid party, with signers gated by the role Hats
     *     - A Wrapped Invoice for the raid
     *
     * Supports assignment of up to one raider per role. If there are multiple raiders per role, the raid party can mint the relevant role hat to the
     * additinal raiders once the raid has been created
     *
     * @param _roles a bitmask of roles to be created for the raid
     *
     * @param _raiders an array of addresses to be assigned to the raid roles. The mapping of address to role is determined by the order of the array,
     * which must match order the Roles enum. If a given role is unspecified or not yet filled, the address at that index must be set to address(0).
     *
     * @param _client the address of the raid client
     * @param _invoiceToken the token to be used for the invoice
     * @param _invoiceAmounts an array milestone amounts for the invoice
     * @param _invoiceTerminationTime the exact invoice termination time at seconds since epoch
     * @param _invoiceDetails bytes-encoded details of the invoice
     * @return raidId the id of the newly created raid
     */
    function createRaid(
        uint16 _roles,
        address[] calldata _raiders,
        address _client,
        address _invoiceToken,
        uint256[] calldata _invoiceAmounts,
        uint256 _invoiceTerminationTime,
        bytes32 _invoiceDetails
    ) public onlyCleric returns (uint256 raidId) {
        // ensure that the roles contain a cleric
        if (Roles.Cleric.isIn(_roles)) revert MissingCleric();
        // ensure that the _raiders array contains a valid cleric
        _checkValidCleric(_raiders[0]);

        // 1. Create Raid hat, admin'd by the Raid Manager hat
        string memory raidDetails = string.concat(RAID_DETAILS_PRE, LibString.toString(HATS.getNextId(raidManagerHat)));

        raidId = HATS.createHat({
            _admin: raidManagerHat,
            _details: raidDetails,
            _maxSupply: 1,
            _eligibility: DAO,
            _toggle: DAO,
            _mutable: true,
            _imageURI: raidImageUri
        });

        // 2. Create the client hat, but DON'T mint it and DON'T add it to MultiHatsSignerGate
        HATS.createHat({
            _admin: raidManagerHat,
            _details: string.concat(raidHatDetails, " Client"),
            _maxSupply: 3, // TODO how many client reps should we allow?
            _eligibility: DAO,
            _toggle: DAO,
            _mutable: true,
            _imageURI: roleImageUris[Roles.Client]
        });

        // 3. Deploy MultiHatsSignerGate and Safe, with Raid Manager Hat as owner and raid role hats (from 2 and 3) as signer hats
        (address safe, /* address mhsg*/ ) = HSG_FACTORY.deployMultiHatsSignerGateAndSafe({
            _ownerHatId: raidManagerHat,
            _signersHatIds: signerHats,
            _minThreshold: 2, // TODO figure out correct starting values for these
            _targetThreshold: 3,
            _maxSigners: 9,
            _saltNonce: raidId // for funsies
        });

        // 4. Mint Raid hat to Safe
        HATS.mintHat(raidId, safe);

        // 5. Deploy Wrapped Invoice, with Safe as provider (and RG DAO as spoils recipient?)
        address wrappedInvoice = _deployWrappedInvoice(
            _client, safe, _invoiceToken, _invoiceAmounts, _invoiceTerminationTime, _invoiceDetails
        );

        // initialize raid and store it as active
        RaidData memory raid;
        raid.active = true;
        raid.roles = _roles;
        raids[raidId] = raid;
        raid.wrappedInvoice = wrappedInvoice;
        raid.raidPartyAvatar = safe;

        // emit RaidCreated event
        emit RaidCreated(raidId, safe, wrappedInvoice);
    }

    // ONLY_RAID_PARTY FUNCTIONS

    function mintRoleToRaider(Roles _role, uint256 _raidId, address _raider) public onlyRaidParty(_raidId) {
        // derive role hat id from raid id and role
        uint256 roleHat = getRaidRoleHat(_raidId, _role);
        // mint role hat to raider
        HATS.mintHat(roleHat, _raider);
    }

    function mintRaidClientHat(uint256 _raidId, address _client) public onlyRaidParty(_raidId) {
        // derive role hat id from raid id and role
        uint256 clientHat = getRaidRoleHat(_raidId, Roles.Client);
        // mint role hat to client
        HATS.mintHat(clientHat, _client);
    }
        raids[_raidId].active = false;
    }

    // ONLY_OWNER FUNCTIONS

    function setHatsSignerGateFactory(address _hsgFactory) public onlyOwner {
        HSG_FACTORY = HatsSignerGateFactory(_hsgFactory);
        emit HatsSignerGateFactorySet(_hsgFactory);
    }

    function setWrappedInvoiceFactory(address _wrappedInvoiceFactory) public onlyOwner {
        WRAPPED_INVOICE_FACTORY = IWrappedInvoiceFactory(_wrappedInvoiceFactory);
        emit WrappedInvoiceFactorySet(_wrappedInvoiceFactory);
    }

    function setInvoiceArbitrator(address _invoiceArbitrator) public onlyOwner {
        INVOICE_ARBITRATOR = _invoiceArbitrator;
        emit InvoiceArbitratorSet(_invoiceArbitrator);
    }

    function setCommitmentContract(address _commitmentContract) public onlyOwner {
        COMMITMENT = _commitmentContract;
        emit CommitmentContractSet(_commitmentContract);
    }

    function setRaidManagerHat(uint256 _raidManagerHat) public onlyOwner {
        raidManagerHat = _raidManagerHat;
        emit RaidManagerHatSet(_raidManagerHat);
    }

    function setGuildClericHat(uint256 _guildClericHat) public onlyOwner {
        guildClericHat = _guildClericHat;
        emit GuildClericHatSet(_guildClericHat);
    }

    function setRaidImageUri(string calldata _imageUri) public onlyOwner {
        raidImageUri = _imageUri;
        emit RaidImageUriSet(_imageUri);
    }

    function setRoleImageUri(Roles _role, string calldata _imageUri) public onlyOwner {
        roleImageUris[_role] = _imageUri;
        emit RoleImageUriSet(_role, _imageUri);
    }

    // INTERNAL FUNCTIONS

    function _checkValidCleric(address _account) internal view {
        if (!HATS.isWearerOfHat(_account, guildClericHat)) revert NotCleric();
    }

    function _createRaidRoles(uint256 _raidId, string memory _raidDetails, uint16 _roles, address[] calldata _raiders)
        // uint256[] memory _signerHats
        public
        returns (uint256[] memory signerHats)
    {
        uint256 roleHat;
        Roles role;

        for (uint256 i; i < uint256(type(Roles).max);) {
            role = Roles(i);
            // Create a hat for each specified role
            if (role.isIn(_roles)) {
                roleHat = HATS.createHat({
                    _admin: _raidId,
                    _details: string.concat(_raidDetails, " ", role.key()),
                    _maxSupply: 1, // TODO how do we handle multiple raiders with the same role?
                    _eligibility: COMMITMENT,
                    _toggle: COMMITMENT,
                    _mutable: true,
                    _imageURI: roleImageUris[role]
                });

                // if filled, mint the hat to the specified raider
                //
                if (_raiders[i] != address(0)) {
                    HATS.mintHat(roleHat, _raiders[i]);
                }
            } else {
                roleHat = HATS.createHat({
                    _admin: _raidId,
                    _details: "",
                    _maxSupply: 0,
                    _eligibility: address(0),
                    _toggle: address(0),
                    _mutable: true,
                    _imageURI: ""
                });
            }

            // add roleHat to the signerHats array
            signerHats[i] = roleHat;

            unchecked {
                ++i;
            }
        }
    }

    function _deployWrappedInvoice(
        address _client,
        address _safe,
        address _invoiceToken,
        uint256[] calldata _invoiceAmounts,
        uint256 _invoiceTerminationTime,
        bytes32 _invoiceDetails
    ) internal returns (address wrappedInvoice) {
        address[] memory providers = new address[](2);
        providers[0] = DAO;
        providers[1] = _safe;

        wrappedInvoice = WRAPPED_INVOICE_FACTORY.create({
            _client: _client,
            _providers: providers,
            _splitFactor: 10, // 10% to DAO and 90% to raid party
            _resolverType: 2, // ARBITRATOR
            _resolver: INVOICE_ARBITRATOR,
            _token: _invoiceToken,
            _amounts: _invoiceAmounts,
            _terminationTime: _invoiceTerminationTime,
            _details: _invoiceDetails
        });
    }

    // MODIFIERS

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
}
