// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract ZKVerifyAttestation {
    bytes32 public immutable merkleRoot;

    constructor(bytes32 _merkleRoot) {
        merkleRoot = _merkleRoot;
    }

    function verifyProofAttestation(
        uint256 _attestationId,
        bytes32 _leaf,
        bytes32[] calldata _merklePath,
        uint256 _leafCount,
        uint256 _index
    ) public view returns (bool) {
        bytes32 computedHash = _leaf;

        for (uint256 i = 0; i < _merklePath.length; i++) {
            if (_index % 2 == 0) {
                computedHash = keccak256(abi.encodePacked(computedHash, _merklePath[i]));
            } else {
                computedHash = keccak256(abi.encodePacked(_merklePath[i], computedHash));
            }
            _index = _index / 2;
        }

        return computedHash == merkleRoot;
    }
}
