// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {ZKVerifyAttestation} from "../src/ZKVerifyAttestation.sol";

contract DeployZKVerify is Script {
    function run() external returns (ZKVerifyAttestation) {
        // Load attestation data

        // Deploy ZKVerify contract
        vm.startBroadcast();

        ZKVerifyAttestation zkVerify = new ZKVerifyAttestation(
            bytes32(0xf4188d90a32bf696191116236aec12ade13fa21f6c9b140485296f6a93d13b43) // Merkle root from attestation.json
        );

        vm.stopBroadcast();

        return zkVerify;
    }
}
