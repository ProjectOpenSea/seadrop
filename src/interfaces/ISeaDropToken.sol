// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ISeaDropTokenContractMetadata
} from "./ISeaDropTokenContractMetadata.sol";

import { AllowListData, CreatorPayout } from "../lib/SeaDropStructs.sol";

/**
 * @dev A helper base interface for IERC721SeaDrop and IERC1155SeaDrop.
 *      The token does not expose these methods as part of its external
 *      interface to optimize contract size, but does implement them.
 */
interface ISeaDropToken is ISeaDropTokenContractMetadata {
    /**
     * @notice Update the SeaDrop allowed Seaport contracts privileged to mint.
     *         Only the owner can use this function.
     *
     * @param allowedSeaport The allowed Seaport addresses.
     */
    function updateAllowedSeaport(address[] calldata allowedSeaport) external;

    /**
     * @notice Update the SeaDrop allowed fee recipient.
     *         Only the owner can use this function.
     *
     * @param feeRecipient The new fee recipient.
     * @param allowed      Whether the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(
        address feeRecipient,
        bool allowed
    ) external;

    /**
     * @notice Update the SeaDrop creator payout addresses.
     *         The total basis points must add up to exactly 10_000.
     *         Only the owner can use this function.
     *
     * @param creatorPayouts The new creator payouts.
     */
    function updateCreatorPayouts(
        CreatorPayout[] calldata creatorPayouts
    ) external;

    /**
     * @notice Update the SeaDrop drop URI.
     *         Only the owner can use this function.
     *
     * @param dropURI The new drop URI.
     */
    function updateDropURI(string calldata dropURI) external;

    /**
     * @notice Update the SeaDrop allow list data.
     *         Only the owner can use this function.
     *
     * @param allowListData The new allow list data.
     */
    function updateAllowList(AllowListData calldata allowListData) external;

    /**
     * @notice Update the SeaDrop allowed payers.
     *         Only the owner can use this function.
     *
     * @param payer   The payer to update.
     * @param allowed Whether the payer is allowed.
     */
    function updatePayer(address payer, bool allowed) external;

    /**
     * @notice Update the SeaDrop allowed signer.
     *         Only the owner can use this function.
     *         The signer can also disallow themselves.
     *
     * @param signer  The signer to update.
     * @param allowed Whether the signer is allowed.
     */
    function updateSigner(address signer, bool allowed) external;

    /**
     * @notice Get the SeaDrop allowed Seaport contracts privileged to mint.
     */
    function getAllowedSeaport() external view returns (address[] memory);

    /**
     * @notice Returns the SeaDrop creator payouts.
     */
    function getCreatorPayouts() external view returns (CreatorPayout[] memory);

    /**
     * @notice Returns the SeaDrop allow list merkle root.
     */
    function getAllowListMerkleRoot() external view returns (bytes32);

    /**
     * @notice Returns the SeaDrop allowed fee recipients.
     */
    function getAllowedFeeRecipients() external view returns (address[] memory);

    /**
     * @notice Returns the SeaDrop allowed signers.
     */
    function getSigners() external view returns (address[] memory);

    /**
     * @notice Returns if the signed digest has been used.
     *
     * @param digest The digest hash.
     */
    function getDigestIsUsed(bytes32 digest) external view returns (bool);

    /**
     * @notice Returns the SeaDrop allowed payers.
     */
    function getPayers() external view returns (address[] memory);
}
