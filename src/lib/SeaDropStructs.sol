// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @notice A struct defining a creator payout address and basis points.
 *
 * @param payoutAddress The payout address.
 * @param basisPoints   The basis points to pay out to the creator.
 *                      The total creator payouts must equal 10_000 bps.
 */
struct CreatorPayout {
    address payoutAddress;
    uint16 basisPoints;
}

/**
 * @notice A struct defining allow list data (for minting an allow list).
 *
 * @param merkleRoot    The merkle root for the allow list.
 * @param publicKeyURIs If the allowListURI is encrypted, a list of URIs
 *                      pointing to the public keys. Empty if unencrypted.
 * @param allowListURI  The URI for the allow list.
 */
struct AllowListData {
    bytes32 merkleRoot;
    string[] publicKeyURIs;
    string allowListURI;
}
