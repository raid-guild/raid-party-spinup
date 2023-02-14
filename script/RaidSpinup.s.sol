// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";

contract DeployRaidSpinup is Script {
    function setUp() public { }

    function run() public {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(privKey);
        vm.startBroadcast(deployer);

        vm.stopBroadcast();
    }
}

// forge script script/RaidPartySpinupScript.s.sol -f ethereum --broadcast --verify
