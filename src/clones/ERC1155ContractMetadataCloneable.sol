// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IERC1155ContractMetadata
} from "../interfaces/IERC1155ContractMetadata.sol";

import {
    ERC1155ConduitPreapproved
} from "../lib/ERC1155ConduitPreapproved.sol";

import {
    ICreatorToken,
    ILegacyCreatorToken
} from "../interfaces/ICreatorToken.sol";

import { ITransferValidator1155 } from "../interfaces/ITransferValidator.sol";

import { TokenTransferValidator } from "../lib/TokenTransferValidator.sol";

import { ERC1155 } from "solady/src/tokens/ERC1155.sol";

import { ERC2981 } from "solady/src/tokens/ERC2981.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

import {
    Initializable
} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

/**
 * @title  ERC1155ContractMetadataCloneable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice A cloneable token contract that extends ERC-1155
 *         with additional metadata and ownership capabilities.
 */
contract ERC1155ContractMetadataCloneable is
    ERC1155ConduitPreapproved,
    TokenTransferValidator,
    ERC2981,
    Ownable,
    IERC1155ContractMetadata,
    Initializable
{
    /// @notice A struct containing the token supply info per token id.
    mapping(uint256 => TokenSupply) _tokenSupply;

    /// @notice The total number of tokens minted by address.
    mapping(address => uint256) _totalMintedByUser;

    /// @notice The total number of tokens minted per token id by address.
    mapping(address => mapping(uint256 => uint256)) _totalMintedByUserPerToken;

    /// @notice The name of the token.
    string internal _name;

    /// @notice The symbol of the token.
    string internal _symbol;

    /// @notice The base URI for token metadata.
    string internal _baseURI;

    /// @notice The contract URI for contract metadata.
    string internal _contractURI;

    /// @notice The provenance hash for guaranteeing metadata order
    ///         for random reveals.
    bytes32 internal _provenanceHash;

    /// @notice The allowed contract that can configure SeaDrop parameters.
    address internal _CONFIGURER;

    /**
     * @dev Reverts if the sender is not the owner or the allowed
     *      configurer contract.
     *
     *      This is used as a function instead of a modifier
     *      to save contract space when used multiple times.
     */
    function _onlyOwnerOrConfigurer() internal view {
        if (msg.sender != _CONFIGURER && msg.sender != owner()) {
            revert Unauthorized();
        }
    }

    /**
     * @notice Deploy the token contract.
     *
     * @param allowedConfigurer The address of the contract allowed to
     *                          configure parameters. Also contains SeaDrop
     *                          implementation code.
     * @param name_             The name of the token.
     * @param symbol_           The symbol of the token.
     */
    function __ERC1155ContractMetadataCloneable_init(
        address allowedConfigurer,
        string memory name_,
        string memory symbol_
    ) internal onlyInitializing {
        // Set the name of the token.
        _name = name_;

        // Set the symbol of the token.
        _symbol = symbol_;

        // Set the allowed configurer contract to interact with this contract.
        _CONFIGURER = allowedConfigurer;
    }

    /**
     * @notice Sets the base URI for the token metadata and emits an event.
     *
     * @param newBaseURI The new base URI to set.
     */
    function setBaseURI(string calldata newBaseURI) external override {
        // Ensure the sender is only the owner or configurer contract.
        _onlyOwnerOrConfigurer();

        // Set the new base URI.
        _baseURI = newBaseURI;

        // Emit an event with the update.
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    /**
     * @notice Sets the contract URI for contract metadata.
     *
     * @param newContractURI The new contract URI.
     */
    function setContractURI(string calldata newContractURI) external override {
        // Ensure the sender is only the owner or configurer contract.
        _onlyOwnerOrConfigurer();

        // Set the new contract URI.
        _contractURI = newContractURI;

        // Emit an event with the update.
        emit ContractURIUpdated(newContractURI);
    }

    /**
     * @notice Emit an event notifying metadata updates for
     *         a range of token ids, according to EIP-4906.
     *
     * @param fromTokenId The start token id.
     * @param toTokenId   The end token id.
     */
    function emitBatchMetadataUpdate(
        uint256 fromTokenId,
        uint256 toTokenId
    ) external {
        // Ensure the sender is only the owner or configurer contract.
        _onlyOwnerOrConfigurer();

        // Emit an event with the update.
        if (fromTokenId == toTokenId) {
            // If only one token is being updated, use the event
            // in the 1155 spec.
            emit URI(uri(fromTokenId), fromTokenId);
        } else {
            emit BatchMetadataUpdate(fromTokenId, toTokenId);
        }
    }

    /**
     * @notice Sets the max token supply and emits an event.
     *
     * @param tokenId      The token id to set the max supply for.
     * @param newMaxSupply The new max supply to set.
     */
    function setMaxSupply(uint256 tokenId, uint256 newMaxSupply) external {
        // Ensure the sender is only the owner or configurer contract.
        _onlyOwnerOrConfigurer();

        // Ensure the max supply does not exceed the maximum value of uint64,
        // a limit due to the storage of bit-packed variables in TokenSupply.
        if (newMaxSupply > 2 ** 64 - 1) {
            revert CannotExceedMaxSupplyOfUint64(newMaxSupply);
        }

        // Ensure the max supply does not exceed the total minted.
        if (newMaxSupply < _tokenSupply[tokenId].totalMinted) {
            revert NewMaxSupplyCannotBeLessThenTotalMinted(
                newMaxSupply,
                _tokenSupply[tokenId].totalMinted
            );
        }

        // Set the new max supply.
        _tokenSupply[tokenId].maxSupply = uint64(newMaxSupply);

        // Emit an event with the update.
        emit MaxSupplyUpdated(tokenId, newMaxSupply);
    }

    /**
     * @notice Sets the provenance hash and emits an event.
     *
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it has not been
     *         modified after mint started.
     *
     *         This function will revert if the provenance hash has already
     *         been set, so be sure to carefully set it only once.
     *
     * @param newProvenanceHash The new provenance hash to set.
     */
    function setProvenanceHash(bytes32 newProvenanceHash) external {
        // Ensure the sender is only the owner or configurer contract.
        _onlyOwnerOrConfigurer();

        // Keep track of the old provenance hash for emitting with the event.
        bytes32 oldProvenanceHash = _provenanceHash;

        // Revert if the provenance hash has already been set.
        if (oldProvenanceHash != bytes32(0)) {
            revert ProvenanceHashCannotBeSetAfterAlreadyBeingSet();
        }

        // Set the new provenance hash.
        _provenanceHash = newProvenanceHash;

        // Emit an event with the update.
        emit ProvenanceHashUpdated(oldProvenanceHash, newProvenanceHash);
    }

    /**
     * @notice Sets the default royalty information.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator of 10_000 basis points.
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external {
        // Ensure the sender is only the owner or configurer contract.
        _onlyOwnerOrConfigurer();

        // Set the default royalty.
        // ERC2981 implementation ensures feeNumerator <= feeDenominator
        // and receiver != address(0).
        _setDefaultRoyalty(receiver, feeNumerator);

        // Emit an event with the updated params.
        emit RoyaltyInfoUpdated(receiver, feeNumerator);
    }

    /**
     * @notice Returns the name of the token.
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the base URI for token metadata.
     */
    function baseURI() external view override returns (string memory) {
        return _baseURI;
    }

    /**
     * @notice Returns the contract URI for contract metadata.
     */
    function contractURI() external view override returns (string memory) {
        return _contractURI;
    }

    /**
     * @notice Returns the max token supply for a token id.
     */
    function maxSupply(uint256 tokenId) external view returns (uint256) {
        return _tokenSupply[tokenId].maxSupply;
    }

    /**
     * @notice Returns the total supply for a token id.
     */
    function totalSupply(uint256 tokenId) external view returns (uint256) {
        return _tokenSupply[tokenId].totalSupply;
    }

    /**
     * @notice Returns the total minted for a token id.
     */
    function totalMinted(uint256 tokenId) external view returns (uint256) {
        return _tokenSupply[tokenId].totalMinted;
    }

    /**
     * @notice Returns the provenance hash.
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it is unmodified
     *         after mint has started.
     */
    function provenanceHash() external view override returns (bytes32) {
        return _provenanceHash;
    }

    /**
     * @notice Returns the URI for token metadata.
     *
     *         This implementation returns the same URI for *all* token types.
     *         It relies on the token type ID substitution mechanism defined
     *         in the EIP to replace {id} with the token id.
     *
     * @custom:param tokenId The token id to get the URI for.
     */
    function uri(
        uint256 /* tokenId */
    ) public view virtual override returns (string memory) {
        // Return the base URI.
        return _baseURI;
    }

    /**
     * @notice Returns the transfer validation function used.
     */
    function getTransferValidationFunction()
        external
        pure
        returns (bytes4 functionSignature, bool isViewFunction)
    {
        functionSignature = ITransferValidator1155.validateTransfer.selector;
        isViewFunction = true;
    }

    /**
     * @notice Set the transfer validator. Only callable by the token owner.
     */
    function setTransferValidator(address newValidator) external onlyOwner {
        // Set the new transfer validator.
        _setTransferValidator(newValidator);
    }

    /// @dev Override this function to return true if `_beforeTokenTransfer` is used.
    function _useBeforeTokenTransfer()
        internal
        view
        virtual
        override
        returns (bool)
    {
        return true;
    }

    /**
     * @dev Hook that is called before any token transfer.
     *      This includes minting and burning.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory /* data */
    ) internal virtual override {
        if (from != address(0) && to != address(0)) {
            // Call the transfer validator if one is set.
            address transferValidator = _transferValidator;
            if (transferValidator != address(0)) {
                for (uint256 i = 0; i < ids.length; i++) {
                    ITransferValidator1155(transferValidator).validateTransfer(
                        msg.sender,
                        from,
                        to,
                        ids[i],
                        amounts[i]
                    );
                }
            }
        }
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC2981) returns (bool) {
        return
            interfaceId == type(IERC1155ContractMetadata).interfaceId ||
            interfaceId == type(ICreatorToken).interfaceId ||
            interfaceId == type(ILegacyCreatorToken).interfaceId ||
            interfaceId == 0x49064906 || // ERC-4906 (MetadataUpdate)
            ERC2981.supportsInterface(interfaceId) ||
            // ERC1155 returns supportsInterface true for
            //     ERC165, ERC1155, ERC1155MetadataURI
            ERC1155.supportsInterface(interfaceId);
    }

    /**
     * @dev Adds to the internal counters for a mint.
     *
     * @param to     The address to mint to.
     * @param id     The token id to mint.
     * @param amount The quantity to mint.
     * @param data   The data to pass if receiver is a contract.
     */
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual override {
        // Increment mint counts.
        _incrementMintCounts(to, id, amount);

        ERC1155._mint(to, id, amount, data);
    }

    /**
     * @dev Adds to the internal counters for a batch mint.
     *
     * @param to      The address to mint to.
     * @param ids     The token ids to mint.
     * @param amounts The quantities to mint.
     * @param data    The data to pass if receiver is a contract.
     */
    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        // Put ids length on the stack to save MLOADs.
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            // Increment mint counts.
            _incrementMintCounts(to, ids[i], amounts[i]);

            unchecked {
                ++i;
            }
        }

        ERC1155._batchMint(to, ids, amounts, data);
    }

    /**
     * @dev Subtracts from the internal counters for a burn.
     *
     * @param by     The address calling the burn.
     * @param from   The address to burn from.
     * @param id     The token id to burn.
     * @param amount The amount to burn.
     */
    function _burn(
        address by,
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual override {
        // Reduce the supply.
        _reduceSupplyOnBurn(id, amount);

        ERC1155._burn(by, from, id, amount);
    }

    /**
     * @dev Subtracts from the internal counters for a batch burn.
     *
     * @param by      The address calling the burn.
     * @param from    The address to burn from.
     * @param ids     The token ids to burn.
     * @param amounts The amounts to burn.
     */
    function _batchBurn(
        address by,
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual override {
        // Put ids length on the stack to save MLOADs.
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            // Reduce the supply.
            _reduceSupplyOnBurn(ids[i], amounts[i]);

            unchecked {
                ++i;
            }
        }

        ERC1155._batchBurn(by, from, ids, amounts);
    }

    function _reduceSupplyOnBurn(uint256 id, uint256 amount) internal {
        // Get the current token supply.
        TokenSupply storage tokenSupply = _tokenSupply[id];

        // Reduce the totalSupply.
        unchecked {
            tokenSupply.totalSupply -= uint64(amount);
        }
    }

    /**
     * @dev Internal function to increment mint counts.
     *
     *      Note that this function does not check if the mint exceeds
     *      maxSupply, which should be validated before this function is called.
     *
     * @param to     The address to mint to.
     * @param id     The token id to mint.
     * @param amount The quantity to mint.
     */
    function _incrementMintCounts(
        address to,
        uint256 id,
        uint256 amount
    ) internal {
        // Get the current token supply.
        TokenSupply storage tokenSupply = _tokenSupply[id];

        if (tokenSupply.totalMinted + amount > tokenSupply.maxSupply) {
            revert MintExceedsMaxSupply(
                tokenSupply.totalMinted + amount,
                tokenSupply.maxSupply
            );
        }

        // Increment supply and number minted.
        // Can be unchecked because maxSupply cannot be set to exceed uint64.
        unchecked {
            tokenSupply.totalSupply += uint64(amount);
            tokenSupply.totalMinted += uint64(amount);

            // Increment total minted by user.
            _totalMintedByUser[to] += amount;

            // Increment total minted by user per token.
            _totalMintedByUserPerToken[to][id] += amount;
        }
    }
}
