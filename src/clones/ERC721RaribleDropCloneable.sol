// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721ContractMetadataCloneable,
    IRaribleDropTokenContractMetadata
} from "./ERC721ContractMetadataCloneable.sol";

import {
    INonFungibleRaribleDropToken
} from "../interfaces/INonFungibleRaribleDropToken.sol";

import { IRaribleDrop } from "../interfaces/IRaribleDrop.sol";

import {
    AllowListData,
    PublicDrop,
    TokenGatedDropStage,
    SignedMintValidationParams
} from "../lib/RaribleDropStructs.sol";

import {
    ERC721RaribleDropStructsErrorsAndEvents
} from "../lib/ERC721RaribleDropStructsErrorsAndEvents.sol";

import { ERC721ACloneable } from "./ERC721ACloneable.sol";

import {
    ReentrancyGuardUpgradeable
} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {
    IERC165
} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

import {
    DefaultOperatorFiltererUpgradeable
} from "operator-filter-registry/upgradeable/DefaultOperatorFiltererUpgradeable.sol";

/**
 * @title  ERC721RaribleDrop
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721RaribleDrop is a token contract that contains methods
 *         to properly interact with RaribleDrop.
 */
contract ERC721RaribleDropCloneable is
    ERC721ContractMetadataCloneable,
    INonFungibleRaribleDropToken,
    ERC721RaribleDropStructsErrorsAndEvents,
    ReentrancyGuardUpgradeable,
    DefaultOperatorFiltererUpgradeable
{
    /// @notice Track the allowed RaribleDrop addresses.
    mapping(address => bool) internal _allowedRaribleDrop;

    /// @notice Track the enumerated allowed RaribleDrop addresses.
    address[] internal _enumeratedAllowedRaribleDrop;

    /**
     * @dev Reverts if not an allowed RaribleDrop contract.
     *      This function is inlined instead of being a modifier
     *      to save contract space from being inlined N times.
     *
     * @param raribleDrop The RaribleDrop address to check if allowed.
     */
    function _onlyAllowedRaribleDrop(address raribleDrop) internal view {
        if (_allowedRaribleDrop[raribleDrop] != true) {
            revert OnlyAllowedRaribleDrop();
        }
    }

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed RaribleDrop addresses.
     */
    function initialize(
        string calldata __name,
        string calldata __symbol,
        address[] calldata allowedRaribleDrop,
        address initialOwner
    ) public initializer {
        __ERC721ACloneable__init(__name, __symbol);
        __ReentrancyGuard_init();
        __DefaultOperatorFilterer_init();
        _updateAllowedRaribleDrop(allowedRaribleDrop);
        _transferOwnership(initialOwner);
        emit RaribleDropTokenDeployed();
    }

    /**
     * @notice Update the allowed RaribleDrop contracts.
     *         Only the owner or administrator can use this function.
     *
     * @param allowedRaribleDrop The allowed RaribleDrop addresses.
     */
    function updateAllowedRaribleDrop(address[] calldata allowedRaribleDrop)
        external
        virtual
        override
        onlyOwner
    {
        _updateAllowedRaribleDrop(allowedRaribleDrop);
    }

    /**
     * @notice Internal function to update the allowed RaribleDrop contracts.
     *
     * @param allowedRaribleDrop The allowed RaribleDrop addresses.
     */
    function _updateAllowedRaribleDrop(address[] calldata allowedRaribleDrop) internal {
        // Put the length on the stack for more efficient access.
        uint256 enumeratedAllowedRaribleDropLength = _enumeratedAllowedRaribleDrop
            .length;
        uint256 allowedRaribleDropLength = allowedRaribleDrop.length;

        // Reset the old mapping.
        for (uint256 i = 0; i < enumeratedAllowedRaribleDropLength; ) {
            _allowedRaribleDrop[_enumeratedAllowedRaribleDrop[i]] = false;
            unchecked {
                ++i;
            }
        }

        // Set the new mapping for allowed RaribleDrop contracts.
        for (uint256 i = 0; i < allowedRaribleDropLength; ) {
            _allowedRaribleDrop[allowedRaribleDrop[i]] = true;
            unchecked {
                ++i;
            }
        }

        // Set the enumeration.
        _enumeratedAllowedRaribleDrop = allowedRaribleDrop;

        // Emit an event for the update.
        emit AllowedRaribleDropUpdated(allowedRaribleDrop);
    }

    /**
     * @dev Overrides the `_startTokenId` function from ERC721A
     *      to start at token id `1`.
     *
     *      This is to avoid future possible problems since `0` is usually
     *      used to signal values that have not been set or have been removed.
     */
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    /**
     * @dev Overrides the `tokenURI()` function from ERC721A
     *      to return just the base URI if it is implied to not be a directory.
     *
     *      This is to help with ERC721 contracts in which the same token URI
     *      is desired for each token, such as when the tokenURI is 'unrevealed'.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();

        // Exit early if the baseURI is empty.
        if (bytes(baseURI).length == 0) {
            return "";
        }

        // Check if the last character in baseURI is a slash.
        if (bytes(baseURI)[bytes(baseURI).length - 1] != bytes("/")[0]) {
            return baseURI;
        }

        return string(abi.encodePacked(baseURI, _toString(tokenId)));
    }

    /**
     * @notice Mint tokens, restricted to the RaribleDrop contract.
     *
     * @dev    NOTE: If a token registers itself with multiple RaribleDrop
     *         contracts, the implementation of this function should guard
     *         against reentrancy. If the implementing token uses
     *         _safeMint(), or a feeRecipient with a malicious receive() hook
     *         is specified, the token or fee recipients may be able to execute
     *         another mint in the same transaction via a separate RaribleDrop
     *         contract.
     *         This is dangerous if an implementing token does not correctly
     *         update the minterNumMinted and currentTotalSupply values before
     *         transferring minted tokens, as RaribleDrop references these values
     *         to enforce token limits on a per-wallet and per-stage basis.
     *
     *         ERC721A tracks these values automatically, but this note and
     *         nonReentrant modifier are left here to encourage best-practices
     *         when referencing this contract.
     *
     * @param minter   The address to mint to.
     * @param quantity The number of tokens to mint.
     */
    function mintRaribleDrop(address minter, uint256 quantity)
        external
        virtual
        override
        nonReentrant
    {
        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(msg.sender);

        // Extra safety check to ensure the max supply is not exceeded.
        if (_totalMinted() + quantity > maxSupply()) {
            revert MintQuantityExceedsMaxSupply(
                _totalMinted() + quantity,
                maxSupply()
            );
        }

        // Mint the quantity of tokens to the minter.
        _safeMint(minter, quantity);
    }

    /**
     * @notice Update the public drop data for this nft contract on RaribleDrop.
     *         Only the owner can use this function.
     *
     * @param raribleDropImpl The allowed RaribleDrop contract.
     * @param publicDrop  The public drop data.
     */
    function updatePublicDrop(
        address raribleDropImpl,
        PublicDrop calldata publicDrop
    ) external virtual override {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the public drop data on RaribleDrop.
        IRaribleDrop(raribleDropImpl).updatePublicDrop(publicDrop);
    }

    /**
     * @notice Update the allow list data for this nft contract on RaribleDrop.
     *         Only the owner can use this function.
     *
     * @param raribleDropImpl   The allowed RaribleDrop contract.
     * @param allowListData The allow list data.
     */
    function updateAllowList(
        address raribleDropImpl,
        AllowListData calldata allowListData
    ) external virtual override {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the allow list on RaribleDrop.
        IRaribleDrop(raribleDropImpl).updateAllowList(allowListData);
    }

    /**
     * @notice Update the token gated drop stage data for this nft contract
     *         on RaribleDrop.
     *         Only the owner can use this function.
     *
     *         Note: If two INonFungibleRaribleDropToken tokens are doing
     *         simultaneous token gated drop promotions for each other,
     *         they can be minted by the same actor until
     *         `maxTokenSupplyForStage` is reached. Please ensure the
     *         `allowedNftToken` is not running an active drop during the
     *         `dropStage` time period.
     *
     * @param raribleDropImpl     The allowed RaribleDrop contract.
     * @param allowedNftToken The allowed nft token.
     * @param dropStage       The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address raribleDropImpl,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external virtual override {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the token gated drop stage.
        IRaribleDrop(raribleDropImpl).updateTokenGatedDrop(allowedNftToken, dropStage);
    }

    /**
     * @notice Update the drop URI for this nft contract on RaribleDrop.
     *         Only the owner can use this function.
     *
     * @param raribleDropImpl The allowed RaribleDrop contract.
     * @param dropURI     The new drop URI.
     */
    function updateDropURI(address raribleDropImpl, string calldata dropURI)
        external
        virtual
        override
    {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the drop URI.
        IRaribleDrop(raribleDropImpl).updateDropURI(dropURI);
    }

    /**
     * @notice Update the creator payout address for this nft contract on
     *         RaribleDrop.
     *         Only the owner can set the creator payout address.
     *
     * @param raribleDropImpl   The allowed RaribleDrop contract.
     * @param payoutAddress The new payout address.
     */
    function updateCreatorPayoutAddress(
        address raribleDropImpl,
        address payoutAddress
    ) external {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the creator payout address.
        IRaribleDrop(raribleDropImpl).updateCreatorPayoutAddress(payoutAddress);
    }

    /**
     * @notice Update the allowed fee recipient for this nft contract
     *         on RaribleDrop.
     *         Only the owner can set the allowed fee recipient.
     *
     * @param raribleDropImpl  The allowed RaribleDrop contract.
     * @param feeRecipient The new fee recipient.
     * @param allowed      If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(
        address raribleDropImpl,
        address feeRecipient,
        bool allowed
    ) external virtual {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the allowed fee recipient.
        IRaribleDrop(raribleDropImpl).updateAllowedFeeRecipient(feeRecipient, allowed);
    }

    /**
     * @notice Update the server-side signers for this nft contract
     *         on RaribleDrop.
     *         Only the owner can use this function.
     *
     * @param raribleDropImpl                The allowed RaribleDrop contract.
     * @param signer                     The signer to update.
     * @param signedMintValidationParams Minimum and maximum parameters to
     *                                   enforce for signed mints.
     */
    function updateSignedMintValidationParams(
        address raribleDropImpl,
        address signer,
        SignedMintValidationParams memory signedMintValidationParams
    ) external virtual override {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the signer.
        IRaribleDrop(raribleDropImpl).updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
    }

    /**
     * @notice Update the allowed payers for this nft contract on RaribleDrop.
     *         Only the owner can use this function.
     *
     * @param raribleDropImpl The allowed RaribleDrop contract.
     * @param payer       The payer to update.
     * @param allowed     Whether the payer is allowed.
     */
    function updatePayer(
        address raribleDropImpl,
        address payer,
        bool allowed
    ) external virtual override {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the payer.
        IRaribleDrop(raribleDropImpl).updatePayer(payer, allowed);
    }

    /**
     * @notice Returns a set of mint stats for the address.
     *         This assists RaribleDrop in enforcing maxSupply,
     *         maxTotalMintableByWallet, and maxTokenSupplyForStage checks.
     *
     * @dev    NOTE: Implementing contracts should always update these numbers
     *         before transferring any tokens with _safeMint() to mitigate
     *         consequences of malicious onERC721Received() hooks.
     *
     * @param minter The minter address.
     */
    function getMintStats(address minter)
        external
        view
        override
        returns (
            uint256 minterNumMinted,
            uint256 currentTotalSupply,
            uint256 maxSupply
        )
    {
        minterNumMinted = _numberMinted(minter);
        currentTotalSupply = _totalMinted();
        maxSupply = _maxSupply;
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721ContractMetadataCloneable)
        returns (bool)
    {
        return
            interfaceId == type(INonFungibleRaribleDropToken).interfaceId ||
            interfaceId == type(IRaribleDropTokenContractMetadata).interfaceId ||
            // ERC721ContractMetadata returns supportsInterface true for
            //     EIP-2981
            // ERC721A returns supportsInterface true for
            //     ERC165, ERC721, ERC721Metadata
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     * - The `operator` must be allowed.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     * - The `operator` mut be allowed.
     *
     * Emits an {Approval} event.
     */
    function approve(address operator, uint256 tokenId)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     * - The operator must be allowed.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     * - The operator must be allowed.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * @notice Configure multiple properties at a time.
     *
     *         Note: The individual configure methods should be used
     *         to unset or reset any properties to zero, as this method
     *         will ignore zero-value properties in the config struct.
     *
     * @param config The configuration struct.
     */
    function multiConfigure(MultiConfigureStruct calldata config)
        external
        onlyOwner
    {
        if (config.maxSupply > 0) {
            this.setMaxSupply(config.maxSupply);
        }
        if (bytes(config.baseURI).length != 0) {
            this.setBaseURI(config.baseURI);
        }
        if (bytes(config.contractURI).length != 0) {
            this.setContractURI(config.contractURI);
        }
        if (
            _cast(config.publicDrop.startTime != 0) |
                _cast(config.publicDrop.endTime != 0) ==
            1
        ) {
            this.updatePublicDrop(config.raribleDropImpl, config.publicDrop);
        }
        if (bytes(config.dropURI).length != 0) {
            this.updateDropURI(config.raribleDropImpl, config.dropURI);
        }
        if (config.allowListData.merkleRoot != bytes32(0)) {
            this.updateAllowList(config.raribleDropImpl, config.allowListData);
        }
        if (config.creatorPayoutAddress != address(0)) {
            this.updateCreatorPayoutAddress(
                config.raribleDropImpl,
                config.creatorPayoutAddress
            );
        }
        if (config.provenanceHash != bytes32(0)) {
            this.setProvenanceHash(config.provenanceHash);
        }
        if (config.allowedFeeRecipients.length > 0) {
            for (uint256 i = 0; i < config.allowedFeeRecipients.length; ) {
                this.updateAllowedFeeRecipient(
                    config.raribleDropImpl,
                    config.allowedFeeRecipients[i],
                    true
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedFeeRecipients.length > 0) {
            for (uint256 i = 0; i < config.disallowedFeeRecipients.length; ) {
                this.updateAllowedFeeRecipient(
                    config.raribleDropImpl,
                    config.disallowedFeeRecipients[i],
                    false
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.allowedPayers.length > 0) {
            for (uint256 i = 0; i < config.allowedPayers.length; ) {
                this.updatePayer(
                    config.raribleDropImpl,
                    config.allowedPayers[i],
                    true
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedPayers.length > 0) {
            for (uint256 i = 0; i < config.disallowedPayers.length; ) {
                this.updatePayer(
                    config.raribleDropImpl,
                    config.disallowedPayers[i],
                    false
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.tokenGatedDropStages.length > 0) {
            if (
                config.tokenGatedDropStages.length !=
                config.tokenGatedAllowedNftTokens.length
            ) {
                revert TokenGatedMismatch();
            }
            for (uint256 i = 0; i < config.tokenGatedDropStages.length; ) {
                this.updateTokenGatedDrop(
                    config.raribleDropImpl,
                    config.tokenGatedAllowedNftTokens[i],
                    config.tokenGatedDropStages[i]
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedTokenGatedAllowedNftTokens.length > 0) {
            for (
                uint256 i = 0;
                i < config.disallowedTokenGatedAllowedNftTokens.length;

            ) {
                TokenGatedDropStage memory emptyStage;
                this.updateTokenGatedDrop(
                    config.raribleDropImpl,
                    config.disallowedTokenGatedAllowedNftTokens[i],
                    emptyStage
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.signedMintValidationParams.length > 0) {
            if (
                config.signedMintValidationParams.length !=
                config.signers.length
            ) {
                revert SignersMismatch();
            }
            for (
                uint256 i = 0;
                i < config.signedMintValidationParams.length;

            ) {
                this.updateSignedMintValidationParams(
                    config.raribleDropImpl,
                    config.signers[i],
                    config.signedMintValidationParams[i]
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedSigners.length > 0) {
            for (uint256 i = 0; i < config.disallowedSigners.length; ) {
                SignedMintValidationParams memory emptyParams;
                this.updateSignedMintValidationParams(
                    config.raribleDropImpl,
                    config.disallowedSigners[i],
                    emptyParams
                );
                unchecked {
                    ++i;
                }
            }
        }
    }
}
