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

/**
 * @notice A struct defining token gated mint params.
 *
 * @param allowedNftToken    The allowed nft token contract address.
 * @param allowedNftTokenIds The token ids to redeem.
 * @param amounts            The token amounts to redeem, per allowedNftTokenId.
 */
struct TokenGatedMintParams {
    address allowedNftToken;
    uint256[] allowedNftTokenIds;
    uint256[] amounts;
}

/**
 * @dev From Seaport.
 *      For SpentItem struct.
 * */
enum ItemType {
    // 0: ETH on mainnet, MATIC on polygon, etc.
    NATIVE,
    // 1: ERC20 items (ERC777 and ERC20 analogues could also technically work)
    ERC20,
    // 2: ERC721 items
    ERC721,
    // 3: ERC1155 items
    ERC1155,
    // 4: ERC721 items where a number of tokenIds are supported
    ERC721_WITH_CRITERIA,
    // 5: ERC1155 items where a number of ids are supported
    ERC1155_WITH_CRITERIA
}

/**
 * @dev From Seaport.
 *      A spent item is translated from a utilized offer item and has four
 *      components: an item type (ETH or other native tokens, ERC20, ERC721,
 *      and ERC1155), a token address, a tokenId, and an amount.
 */
struct SpentItem {
    ItemType itemType;
    address token;
    uint256 identifier;
    uint256 amount;
}
