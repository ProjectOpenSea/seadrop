// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {TwoStepOwnable} from "./TwoStepOwnable.sol";

/**
 * @notice Smart contract that verifies and tracks allow list redemptions against a configurable Merkle root, up to a
 * max number configured at deploy
 */
contract AllowList is TwoStepOwnable {
    bytes32 public merkleRoot;

    error NotAllowListed();

    ///@notice Checks if msg.sender is included in AllowList, revert otherwise
    ///@param proof Merkle proof
    modifier onlyAllowListed(bytes32[] calldata proof) {
        if (!isAllowListed(proof, msg.sender)) {
            revert NotAllowListed();
        }
        _;
    }

    constructor(bytes32 _merkleRoot) {
        merkleRoot = _merkleRoot;
    }

    ///@notice set the Merkle root in the contract. OnlyOwner.
    ///@param _merkleRoot the new Merkle root
    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    ///@notice Given a Merkle proof, check if an address is AllowListed against the root
    ///@param proof Merkle proof
    ///@param data abi-encoded data to be checked against the root
    ///@return boolean isAllowListed
    function isAllowListed(bytes32[] calldata proof, bytes memory data)
        public
        view
        returns (bool)
    {
        return verifyCalldata(proof, merkleRoot, keccak256(data));
    }

    ///@notice Given a Merkle proof, check if an address is AllowListed against the root
    ///@param proof Merkle proof
    ///@param addr address to check against allow list
    ///@return boolean isAllowListed
    function isAllowListed(bytes32[] calldata proof, address addr)
        public
        view
        returns (bool)
    {
        return
            verifyCalldata(
                proof,
                merkleRoot,
                keccak256(abi.encodePacked(addr))
            );
    }

    /**
     * @dev Calldata version of {verify}
     * Copied from OpenZeppelin's MerkleProof.sol
     */
    function verifyCalldata(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProofCalldata(proof, leaf) == root;
    }

    /**
     * @dev Calldata version of {processProof}
     * Copied from OpenZeppelin's MerkleProof.sol
     */
    function processProofCalldata(bytes32[] calldata proof, bytes32 leaf)
        internal
        pure
        returns (bytes32)
    {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; ) {
            computedHash = _hashPair(computedHash, proof[i]);
            unchecked {
                ++i;
            }
        }
        return computedHash;
    }

    /// @dev Copied from OpenZeppelin's MerkleProof.sol
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    /// @dev Copied from OpenZeppelin's MerkleProof.sol
    function _efficientHash(bytes32 a, bytes32 b)
        private
        pure
        returns (bytes32 value)
    {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
