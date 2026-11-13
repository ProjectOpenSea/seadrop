// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {
    INonFungibleSeaDropToken,
    ISeaDropTokenContractMetadata
} from "../interfaces/INonFungibleSeaDropToken.sol";

import { ISeaDrop } from "../interfaces/ISeaDrop.sol";

import {
    AllowListData,
    PublicDrop,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "../lib/SeaDropStructs.sol";

import {
    ERC721SeaDropStructsErrorsAndEvents
} from "../lib/ERC721SeaDropStructsErrorsAndEvents.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";

import { IERC2981 } from "openzeppelin-contracts/interfaces/IERC2981.sol";

import {
    IERC165
} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

/**
 * @title  ERC721SeaDropAdapter
 * @author OpenSea
 * @notice Runs a SeaDrop drop for an ERC-721 contract that was deployed
 *         without SeaDrop support (the target).
 *
 *         SeaDrop treats the adapter as the drop's token contract. Drop
 *         stages, payout settings, mint stats and SeaDrop's events are all
 *         keyed by the adapter's address, and the adapter delivers each mint
 *         on the target. Subclasses decide how a mint is delivered: by
 *         calling a mint function the target lets the adapter call
 *         (`ERC721SeaDropMintAdapter`), or by transferring tokens the
 *         adapter holds (`ERC721SeaDropTransferAdapter`).
 *
 *         The adapter's max supply caps how many tokens this drop can mint,
 *         independent of the target's own supply. Token metadata and
 *         royalties stay on the target, so `setBaseURI` and
 *         `setRoyaltyInfo` revert and the royalty getters read the target.
 */
abstract contract ERC721SeaDropAdapter is
    INonFungibleSeaDropToken,
    ERC721SeaDropStructsErrorsAndEvents,
    TwoStepOwnable,
    ReentrancyGuard
{
    /// @notice Revert when a function only the target contract can serve is
    ///         called on the adapter, such as `setBaseURI`.
    error NotSupportedByAdapter();

    /// @notice Revert when the target has no code.
    error TargetHasNoCode(address target);

    /**
     * @notice Emit on deployment, naming the contract the adapter mints
     *         for. OpenSea reads it to show the drop on that contract's
     *         collection instead of on the adapter's own.
     */
    event SeaDropShimDeployed(address indexed tokenContract);

    /// @notice The ERC-721 contract this adapter mints for.
    address public immutable target;

    /// @notice Track the allowed SeaDrop addresses.
    mapping(address => bool) internal _allowedSeaDrop;

    /// @notice Track the enumerated allowed SeaDrop addresses.
    address[] internal _enumeratedAllowedSeaDrop;

    /// @notice The most tokens this drop can mint.
    uint256 internal _maxSupply;

    /// @notice The number of tokens this drop has minted.
    uint256 internal _totalMinted;

    /// @notice The number of tokens each minter has minted in this drop.
    mapping(address => uint256) internal _numberMinted;

    /// @notice The contract URI for the drop.
    string internal _contractURI;

    /// @notice The provenance hash for the drop's tokens.
    bytes32 internal _provenanceHash;

    /**
     * @notice Deploy the adapter. The deployer becomes the owner.
     *
     * @param targetContract The existing ERC-721 contract to mint for.
     * @param allowedSeaDrop The SeaDrop addresses allowed to mint.
     */
    constructor(address targetContract, address[] memory allowedSeaDrop) {
        if (targetContract.code.length == 0) {
            revert TargetHasNoCode(targetContract);
        }
        target = targetContract;

        uint256 allowedSeaDropLength = allowedSeaDrop.length;
        for (uint256 i = 0; i < allowedSeaDropLength;) {
            _allowedSeaDrop[allowedSeaDrop[i]] = true;
            unchecked {
                ++i;
            }
        }
        _enumeratedAllowedSeaDrop = allowedSeaDrop;

        emit SeaDropTokenDeployed();
        emit SeaDropShimDeployed(targetContract);
    }

    /**
     * @dev Deliver `quantity` tokens of the target to `minter`. Called by
     *      `mintSeaDrop` after the supply checks and counter updates.
     *      Implementations must revert unless the minter received exactly
     *      `quantity` tokens.
     */
    function _deliver(address minter, uint256 quantity) internal virtual;

    /**
     * @dev The most tokens this drop can mint right now. Defaults to the
     *      configured max supply; the transfer adapter also caps it at the
     *      tokens it holds.
     */
    function _mintableSupply() internal view virtual returns (uint256) {
        return _maxSupply;
    }

    function _onlyAllowedSeaDrop(address seaDrop) internal view {
        if (!_allowedSeaDrop[seaDrop]) {
            revert OnlyAllowedSeaDrop();
        }
    }

    function _onlyOwnerOrSelf() internal view {
        if (msg.sender != owner() && msg.sender != address(this)) {
            revert OnlyOwner();
        }
    }

    /**
     * @notice Update the allowed SeaDrop contracts. Only the owner can call.
     *
     * @param allowedSeaDrop The allowed SeaDrop addresses.
     */
    function updateAllowedSeaDrop(address[] calldata allowedSeaDrop)
        external
        override
        onlyOwner
    {
        uint256 enumeratedLength = _enumeratedAllowedSeaDrop.length;
        for (uint256 i = 0; i < enumeratedLength;) {
            _allowedSeaDrop[_enumeratedAllowedSeaDrop[i]] = false;
            unchecked {
                ++i;
            }
        }

        uint256 allowedSeaDropLength = allowedSeaDrop.length;
        for (uint256 i = 0; i < allowedSeaDropLength;) {
            _allowedSeaDrop[allowedSeaDrop[i]] = true;
            unchecked {
                ++i;
            }
        }

        _enumeratedAllowedSeaDrop = allowedSeaDrop;

        emit AllowedSeaDropUpdated(allowedSeaDrop);
    }

    /**
     * @notice Mint tokens on the target for a SeaDrop mint. Only an allowed
     *         SeaDrop can call.
     *
     * @param minter   The address to mint to.
     * @param quantity The number of tokens to mint.
     */
    function mintSeaDrop(address minter, uint256 quantity)
        external
        override
        nonReentrant
    {
        _onlyAllowedSeaDrop(msg.sender);

        uint256 newTotal = _totalMinted + quantity;
        uint256 mintable = _mintableSupply();
        if (newTotal > mintable) {
            revert MintQuantityExceedsMaxSupply(newTotal, mintable);
        }

        _totalMinted = newTotal;
        _numberMinted[minter] += quantity;

        _deliver(minter, quantity);
    }

    /**
     * @notice Return the mint stats SeaDrop checks before a mint. The counts
     *         cover this drop only, not the target's earlier mints.
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
            uint256 maxSupply_
        )
    {
        minterNumMinted = _numberMinted[minter];
        currentTotalSupply = _totalMinted;
        maxSupply_ = _mintableSupply();
    }

    /// @notice The number of tokens this drop has minted.
    function totalMinted() external view returns (uint256) {
        return _totalMinted;
    }

    function updatePublicDrop(
        address seaDropImpl,
        PublicDrop calldata publicDrop
    ) external override {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updatePublicDrop(publicDrop);
    }

    function updateAllowList(
        address seaDropImpl,
        AllowListData calldata allowListData
    ) external override {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updateAllowList(allowListData);
    }

    function updateTokenGatedDrop(
        address seaDropImpl,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external override {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updateTokenGatedDrop(allowedNftToken, dropStage);
    }

    function updateDropURI(address seaDropImpl, string calldata dropURI)
        external
        override
    {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updateDropURI(dropURI);
    }

    function updateCreatorPayoutAddress(
        address seaDropImpl,
        address payoutAddress
    ) external override {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updateCreatorPayoutAddress(payoutAddress);
    }

    function updateAllowedFeeRecipient(
        address seaDropImpl,
        address feeRecipient,
        bool allowed
    ) external override {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updateAllowedFeeRecipient(feeRecipient, allowed);
    }

    function updateSignedMintValidationParams(
        address seaDropImpl,
        address signer,
        SignedMintValidationParams memory signedMintValidationParams
    ) external override {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl)
            .updateSignedMintValidationParams(
                signer, signedMintValidationParams
            );
    }

    function updatePayer(address seaDropImpl, address payer, bool allowed)
        external
        override
    {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updatePayer(payer, allowed);
    }

    /**
     * @notice Set the most tokens this drop can mint. Only the owner can
     *         call.
     *
     * @param newMaxSupply The new max supply.
     */
    function setMaxSupply(uint256 newMaxSupply) external override onlyOwner {
        if (newMaxSupply > 2 ** 64 - 1) {
            revert CannotExceedMaxSupplyOfUint64(newMaxSupply);
        }
        if (newMaxSupply < _totalMinted) {
            revert NewMaxSupplyCannotBeLessThenTotalMinted(
                newMaxSupply,
                _totalMinted
            );
        }
        _maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(newMaxSupply);
    }

    /// @notice The most tokens this drop can mint.
    function maxSupply() external view override returns (uint256) {
        return _maxSupply;
    }

    /**
     * @notice Set the contract URI for the drop. Only the owner can call.
     *
     * @param newContractURI The new contract URI.
     */
    function setContractURI(string calldata newContractURI)
        external
        override
        onlyOwner
    {
        _contractURI = newContractURI;
        emit ContractURIUpdated(newContractURI);
        emit ContractURIUpdated();
    }

    function contractURI() external view override returns (string memory) {
        return _contractURI;
    }

    /**
     * @notice Set the provenance hash for the drop's tokens. Only the owner
     *         can call, and only before the drop's first mint.
     *
     * @param newProvenanceHash The new provenance hash.
     */
    function setProvenanceHash(bytes32 newProvenanceHash)
        external
        override
        onlyOwner
    {
        if (_totalMinted != 0) {
            revert ProvenanceHashCannotBeSetAfterMintStarted();
        }
        bytes32 oldProvenanceHash = _provenanceHash;
        _provenanceHash = newProvenanceHash;
        emit ProvenanceHashUpdated(oldProvenanceHash, newProvenanceHash);
    }

    function provenanceHash() external view override returns (bytes32) {
        return _provenanceHash;
    }

    /// @notice Token metadata lives on the target. Always reverts.
    function setBaseURI(string calldata) external pure override {
        revert NotSupportedByAdapter();
    }

    /// @notice Token metadata lives on the target. Returns an empty string.
    function baseURI() external pure override returns (string memory) {
        return "";
    }

    /// @notice Royalties live on the target. Always reverts.
    function setRoyaltyInfo(RoyaltyInfo calldata) external pure override {
        revert NotSupportedByAdapter();
    }

    /**
     * @notice Return the target's EIP-2981 royalty, or none if the target
     *         doesn't support it.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        public
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        // A low-level call, so a target without EIP-2981 returns no royalty
        // even when its fallback succeeds with empty or short returndata.
        (bool success, bytes memory returnData) = target.staticcall(
            abi.encodeCall(IERC2981.royaltyInfo, (tokenId, salePrice))
        );
        if (success && returnData.length >= 64) {
            (receiver, royaltyAmount) =
                abi.decode(returnData, (address, uint256));
        }
    }

    /// @notice The target's royalty receiver for its first token.
    function royaltyAddress() external view override returns (address) {
        (address receiver,) = royaltyInfo(1, 10_000);
        return receiver;
    }

    /// @notice The target's royalty in basis points for its first token.
    function royaltyBasisPoints() external view override returns (uint256) {
        (, uint256 amount) = royaltyInfo(1, 10_000);
        return amount;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165)
        returns (bool)
    {
        return interfaceId == type(INonFungibleSeaDropToken).interfaceId
            || interfaceId == type(ISeaDropTokenContractMetadata).interfaceId
            || interfaceId == type(IERC2981).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }
}
