// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

function c_465a6b07(bytes8 c__465a6b07) pure {}

function c_true465a6b07(bytes8 c__465a6b07) pure returns (bool) {
    return true;
}

function c_false465a6b07(bytes8 c__465a6b07) pure returns (bool) {
    return false;
}

import {
    ERC721ContractMetadataUpgradeable,
    ISeaDropTokenContractMetadataUpgradeable
} from "./ERC721ContractMetadataUpgradeable.sol";

import {
    INonFungibleSeaDropTokenUpgradeable
} from "./interfaces/INonFungibleSeaDropTokenUpgradeable.sol";

import { ISeaDropUpgradeable } from "./interfaces/ISeaDropUpgradeable.sol";

import {
    AllowListData,
    PublicDrop,
    TokenGatedDropStage,
    SignedMintValidationParams
} from "./lib/SeaDropStructsUpgradeable.sol";

import {
    ERC721AUpgradeable
} from "../lib/ERC721A/contracts/ERC721AUpgradeable.sol";

import {
    ReentrancyGuardUpgradeable
} from "../lib/solmate/src/utils/ReentrancyGuardUpgradeable.sol";

import {
    IERC165Upgradeable
} from "../lib/openzeppelin-contracts/contracts/utils/introspection/IERC165Upgradeable.sol";

import {
    DefaultOperatorFilterer721Upgradeable
} from "../lib/operator-filter-registry/src/example/upgradeable/DefaultOperatorFilterer721Upgradeable.sol";
import { ERC721SeaDropStorage } from "./ERC721SeaDropStorage.sol";
import {
    ERC721ContractMetadataStorage
} from "./ERC721ContractMetadataStorage.sol";

/**
 * @title  ERC721SeaDrop
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721SeaDrop is a token contract that contains methods
 *         to properly interact with SeaDrop.
 */
contract ERC721SeaDropUpgradeable is
    ERC721ContractMetadataUpgradeable,
    INonFungibleSeaDropTokenUpgradeable,
    ReentrancyGuardUpgradeable,
    DefaultOperatorFilterer721Upgradeable
{
    using ERC721SeaDropStorage for ERC721SeaDropStorage.Layout;
    using ERC721ContractMetadataStorage for ERC721ContractMetadataStorage.Layout;

    function c_d527060f(bytes8 c__d527060f) internal pure {}

    function c_trued527060f(bytes8 c__d527060f) internal pure returns (bool) {
        return true;
    }

    function c_falsed527060f(bytes8 c__d527060f) internal pure returns (bool) {
        return false;
    }

    modifier c_mod3cfbb367() {
        c_d527060f(0x2074e9b39ec41e1a); /* modifier-post */
        _;
    }
    modifier c_modfc5038a2() {
        c_d527060f(0xe1f17f1f24dadea6); /* modifier-pre */
        _;
    }
    modifier c_mod43f1f644() {
        c_d527060f(0xdc74069346af692d); /* modifier-post */
        _;
    }
    modifier c_mod10543891() {
        c_d527060f(0x6cd937e5844854fa); /* modifier-pre */
        _;
    }
    modifier c_mod202a337c() {
        c_d527060f(0x4f018f5c6a852d7b); /* modifier-post */
        _;
    }
    modifier c_mod6efbb7d2() {
        c_d527060f(0x9090bf53ae007a8a); /* modifier-pre */
        _;
    }
    modifier c_modddb9c0ca() {
        c_d527060f(0x2de26df3a2d3c450); /* modifier-post */
        _;
    }
    modifier c_modefb7bba3() {
        c_d527060f(0xbfcf44e4be25bff6); /* modifier-pre */
        _;
    }
    modifier c_mod2b24e034() {
        c_d527060f(0x4c69ebf3b5c8ac92); /* modifier-post */
        _;
    }
    modifier c_mod9b2b9d83() {
        c_d527060f(0xb5dcf175aeb32c0f); /* modifier-pre */
        _;
    }
    modifier c_mod6422ee31() {
        c_d527060f(0xbcc7bafb163fd8b0); /* modifier-post */
        _;
    }
    modifier c_mod9400e2b6() {
        c_d527060f(0x742cefba25d826a6); /* modifier-pre */
        _;
    }
    modifier c_mod15fd79e8() {
        c_d527060f(0x23d3a7fe7d8bbfb8); /* modifier-post */
        _;
    }
    modifier c_modafe22915() {
        c_d527060f(0x0c63039b371d61fb); /* modifier-pre */
        _;
    }
    modifier c_mod954ed8e5() {
        c_d527060f(0x2ee540f28834f32c); /* modifier-post */
        _;
    }
    modifier c_mod31d20c51() {
        c_d527060f(0xd680f65ebdb2fecb); /* modifier-pre */
        _;
    }
    modifier c_mod96740165() {
        c_d527060f(0x7fcd41ada559f0e0); /* modifier-post */
        _;
    }
    modifier c_mod676bd09a() {
        c_d527060f(0xe7b2d5f65ed47b2d); /* modifier-pre */
        _;
    }
    modifier c_mode0c0e150() {
        c_d527060f(0xdbe6c16c16b4166b); /* modifier-post */
        _;
    }
    modifier c_modfef441b2() {
        c_d527060f(0x351d9b3219bb5542); /* modifier-pre */
        _;
    }
    modifier c_mod4602f1d0() {
        c_d527060f(0xd483f24672f003ae); /* modifier-post */
        _;
    }
    modifier c_mod64041d1c() {
        c_d527060f(0x56f0216f7b480044); /* modifier-pre */
        _;
    }
    modifier c_mod2d3609f7() {
        c_d527060f(0x65d754b5b701e7cc); /* modifier-post */
        _;
    }
    modifier c_mod5109d810() {
        c_d527060f(0x2eb59f4802626a90); /* modifier-pre */
        _;
    }
    modifier c_mod5a4bacf3() {
        c_d527060f(0x2fb80f4adb87a7b8); /* modifier-post */
        _;
    }
    modifier c_mod81c4c3e7() {
        c_d527060f(0x021bf80cee431a15); /* modifier-pre */
        _;
    }
    modifier c_mod4b291931() {
        c_d527060f(0x114d926e9ea94a51); /* modifier-post */
        _;
    }
    modifier c_mod7ab1b03e() {
        c_d527060f(0x118b64ad912ed7bc); /* modifier-pre */
        _;
    }
    modifier c_mod19d8392f() {
        c_d527060f(0x838673d4c141d72d); /* modifier-post */
        _;
    }
    modifier c_mod071d6fb0() {
        c_d527060f(0xfd9bc5b522b4e808); /* modifier-pre */
        _;
    }
    modifier c_mod97685826() {
        c_d527060f(0x2ede98c38c63ab14); /* modifier-post */
        _;
    }
    modifier c_mod750dde0d() {
        c_d527060f(0x9cdc45b5dd60b3bd); /* modifier-pre */
        _;
    }
    modifier c_modbc4574aa() {
        c_d527060f(0x256e1f2255be81e2); /* modifier-post */
        _;
    }
    modifier c_mod14ddafe3() {
        c_d527060f(0xc6ce18ab58cda1fc); /* modifier-pre */
        _;
    }
    modifier c_modd3b81e76() {
        c_d527060f(0xf2615412dce7b459); /* modifier-post */
        _;
    }
    modifier c_modf92279c5() {
        c_d527060f(0x1ceb8edc6cfcc312); /* modifier-pre */
        _;
    }
    modifier c_mod095ecc27() {
        c_d527060f(0x528da315e4a05462); /* modifier-post */
        _;
    }
    modifier c_mod6de168d4() {
        c_d527060f(0xa3656824fd02120e); /* modifier-pre */
        _;
    }
    modifier c_mod8065f47a() {
        c_d527060f(0xe30c8d217fb8d269); /* modifier-post */
        _;
    }
    modifier c_mod03ecd475() {
        c_d527060f(0xec68f7c4b259ff74); /* modifier-pre */
        _;
    }
    modifier c_mod4e2feaab() {
        c_d527060f(0xb36e6053c642f776); /* modifier-post */
        _;
    }
    modifier c_modead411b8() {
        c_d527060f(0x928a5bc4b6de7b93); /* modifier-pre */
        _;
    }
    modifier c_modb8599039() {
        c_d527060f(0xa81c166d6e36e3d0); /* modifier-post */
        _;
    }
    modifier c_modf98a20e7() {
        c_d527060f(0x3fe03519fe9bdeea); /* modifier-pre */
        _;
    }

    /// @notice Revert with an error if mint exceeds the max supply.
    error MintQuantityExceedsMaxSupply(uint256 total, uint256 maxSupply);

    /**
     * @notice Modifier to restrict access exclusively to
     *         allowed SeaDrop contracts.
     */
    modifier onlyAllowedSeaDrop(address seaDrop) {
        c_d527060f(0x27928abdc8faee4b); /* function */

        c_d527060f(0xea129d57fdca0eca); /* line */
        c_d527060f(0x5c1160364f3f7207); /* statement */
        if (ERC721SeaDropStorage.layout()._allowedSeaDrop[seaDrop] != true) {
            c_d527060f(0xa36c85b02f617152); /* branch */

            c_d527060f(0x6f91a426f7be2e69); /* line */
            revert OnlyAllowedSeaDrop();
        } else {
            c_d527060f(0x2363a9ac44d4dc5b); /* branch */
        }
        c_d527060f(0xa36b5f3b9554f61b); /* line */
        _;
    }

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed SeaDrop addresses.
     */
    function __ERC721SeaDrop_init(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) internal onlyInitializing {
        __ERC721A_init_unchained(name, symbol);
        __ConstructorInitializable_init_unchained();
        __TwoStepOwnable_init_unchained();
        __ERC721ContractMetadata_init_unchained(name, symbol);
        __ReentrancyGuard_init_unchained();
        __DefaultOperatorFilterer721_init();
        __ERC721SeaDrop_init_unchained(name, symbol, allowedSeaDrop);
    }

    function __ERC721SeaDrop_init_unchained(
        string memory,
        string memory,
        address[] memory allowedSeaDrop
    ) internal onlyInitializing {
        c_d527060f(0xd59bab0b161f7183); /* function */

        // Put the length on the stack for more efficient access.
        c_d527060f(0x99b0c9daa36d7b9a); /* line */
        c_d527060f(0xc583703545537775); /* statement */
        uint256 allowedSeaDropLength = allowedSeaDrop.length;

        // Set the mapping for allowed SeaDrop contracts.
        c_d527060f(0x4870add1d029360f); /* line */
        c_d527060f(0x680cbda7d2cb1ea2); /* statement */
        for (uint256 i = 0; i < allowedSeaDropLength; ) {
            c_d527060f(0x89fc9e03c661e347); /* line */
            ERC721SeaDropStorage.layout()._allowedSeaDrop[
                allowedSeaDrop[i]
            ] = true;
            c_d527060f(0xb9f33b175832c32d); /* line */
            unchecked {
                c_d527060f(0x98b3a783a2240aa5); /* line */
                ++i;
            }
        }

        // Set the enumeration.
        c_d527060f(0x5d6fee98e9843655); /* line */
        ERC721SeaDropStorage
            .layout()
            ._enumeratedAllowedSeaDrop = allowedSeaDrop;
    }

    /**
     * @notice Update the allowed SeaDrop contracts.
     *         Only the owner or administrator can use this function.
     *
     * @param allowedSeaDrop The allowed SeaDrop addresses.
     */
    function updateAllowedSeaDrop(address[] calldata allowedSeaDrop)
        external
        virtual
        override
        c_modf98a20e7
        onlyOwner
        c_modb8599039
    {
        c_d527060f(0x368f513f792e8024); /* function */

        c_d527060f(0xd1231250f562ab99); /* line */
        c_d527060f(0xf35dc1ddd52a20cd); /* statement */
        _updateAllowedSeaDrop(allowedSeaDrop);
    }

    /**
     * @notice Internal function to update the allowed SeaDrop contracts.
     *
     * @param allowedSeaDrop The allowed SeaDrop addresses.
     */
    function _updateAllowedSeaDrop(address[] calldata allowedSeaDrop) internal {
        c_d527060f(0xd67fb1132ab4472a); /* function */

        // Put the length on the stack for more efficient access.
        c_d527060f(0xbf061a3f651c023d); /* line */
        c_d527060f(0x08a87b2a0903d89c); /* statement */
        uint256 enumeratedAllowedSeaDropLength = ERC721SeaDropStorage
            .layout()
            ._enumeratedAllowedSeaDrop
            .length;
        c_d527060f(0x8992e6249cf6ca93); /* line */
        c_d527060f(0x4416e17e29e3265a); /* statement */
        uint256 allowedSeaDropLength = allowedSeaDrop.length;

        // Reset the old mapping.
        c_d527060f(0xea8b594f5473519c); /* line */
        c_d527060f(0xeab27514d116b5d2); /* statement */
        for (uint256 i = 0; i < enumeratedAllowedSeaDropLength; ) {
            c_d527060f(0x5ad7f4bce2f1e613); /* line */
            ERC721SeaDropStorage.layout()._allowedSeaDrop[
                ERC721SeaDropStorage.layout()._enumeratedAllowedSeaDrop[i]
            ] = false;
            c_d527060f(0x553afa62eeac5631); /* line */
            unchecked {
                c_d527060f(0x90a55b0b3d1c01ee); /* line */
                ++i;
            }
        }

        // Set the new mapping for allowed SeaDrop contracts.
        c_d527060f(0x5f38fe22c9654492); /* line */
        c_d527060f(0x5b6f97db15c788d5); /* statement */
        for (uint256 i = 0; i < allowedSeaDropLength; ) {
            c_d527060f(0xd42c1124081d28c7); /* line */
            ERC721SeaDropStorage.layout()._allowedSeaDrop[
                allowedSeaDrop[i]
            ] = true;
            c_d527060f(0x6ee625c6d44ea700); /* line */
            unchecked {
                c_d527060f(0xbe852319eaf19eac); /* line */
                ++i;
            }
        }

        // Set the enumeration.
        c_d527060f(0x76a566fc9f49d01c); /* line */
        ERC721SeaDropStorage
            .layout()
            ._enumeratedAllowedSeaDrop = allowedSeaDrop;

        // Emit an event for the update.
        c_d527060f(0x094e4b9370fbbe73); /* line */
        c_d527060f(0x4219da2af5851ad4); /* statement */
        emit AllowedSeaDropUpdated(allowedSeaDrop);
    }

    /**
     * @dev Overrides the `_startTokenId` function from ERC721A
     *      to start at token id `1`.
     *
     *      This is to avoid future possible problems since `0` is usually
     *      used to signal values that have not been set or have been removed.
     */
    function _startTokenId() internal view virtual override returns (uint256) {
        c_d527060f(0x95855e205a573b52); /* function */

        c_d527060f(0x80ff55489acba68e); /* line */
        c_d527060f(0xdf80e5d5f916fa84); /* statement */
        return 1;
    }

    /**
     * @notice Mint tokens, restricted to the SeaDrop contract.
     *
     * @dev    NOTE: If a token registers itself with multiple SeaDrop
     *         contracts, the implementation of this function should guard
     *         against reentrancy. If the implementing token uses
     *         _safeMint(), or a feeRecipient with a malicious receive() hook
     *         is specified, the token or fee recipients may be able to execute
     *         another mint in the same transaction via a separate SeaDrop
     *         contract.
     *         This is dangerous if an implementing token does not correctly
     *         update the minterNumMinted and currentTotalSupply values before
     *         transferring minted tokens, as SeaDrop references these values
     *         to enforce token limits on a per-wallet and per-stage basis.
     *
     *         ERC721A tracks these values automatically, but this note and
     *         nonReentrant modifier are left here to encourage best-practices
     *         when referencing this contract.
     *
     * @param minter   The address to mint to.
     * @param quantity The number of tokens to mint.
     */
    function mintSeaDrop(address minter, uint256 quantity)
        external
        payable
        virtual
        override
        c_modead411b8
        onlyAllowedSeaDrop(msg.sender)
        c_mod4e2feaab
        c_mod03ecd475
        nonReentrant
        c_mod8065f47a
    {
        c_d527060f(0x8011197d47a92018); /* function */

        // Extra safety check to ensure the max supply is not exceeded.
        c_d527060f(0x9d08a328dcbce1c1); /* line */
        c_d527060f(0xe887122023326604); /* statement */
        if (_totalMinted() + quantity > maxSupply()) {
            c_d527060f(0x85a6da34a81cf06b); /* branch */

            c_d527060f(0x14ef566d4bcb388e); /* line */
            revert MintQuantityExceedsMaxSupply(
                _totalMinted() + quantity,
                maxSupply()
            );
        } else {
            c_d527060f(0x134325bb29a6ebcf); /* branch */
        }

        // Mint the quantity of tokens to the minter.
        c_d527060f(0x56845a593b6751de); /* line */
        c_d527060f(0x9ea23de8d2cbbaf6); /* statement */
        _safeMint(minter, quantity);
    }

    /**
     * @notice Update the public drop data for this nft contract on SeaDrop.
     *         Only the owner can use this function.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param publicDrop  The public drop data.
     */
    function updatePublicDrop(
        address seaDropImpl,
        PublicDrop calldata publicDrop
    )
        external
        virtual
        override
        c_mod6de168d4
        onlyOwner
        c_mod095ecc27
        c_modf92279c5
        onlyAllowedSeaDrop(seaDropImpl)
        c_modd3b81e76
    {
        c_d527060f(0x0ba52ce725d8029f); /* function */

        // Update the public drop data on SeaDrop.
        c_d527060f(0xdba04330d4735121); /* line */
        c_d527060f(0x2403d6349add8d7e); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updatePublicDrop(publicDrop);
    }

    /**
     * @notice Update the allow list data for this nft contract on SeaDrop.
     *         Only the owner can use this function.
     *
     * @param seaDropImpl   The allowed SeaDrop contract.
     * @param allowListData The allow list data.
     */
    function updateAllowList(
        address seaDropImpl,
        AllowListData calldata allowListData
    )
        external
        virtual
        override
        c_mod14ddafe3
        onlyOwner
        c_modbc4574aa
        c_mod750dde0d
        onlyAllowedSeaDrop(seaDropImpl)
        c_mod97685826
    {
        c_d527060f(0x8f3c7cc450e23c1d); /* function */

        // Update the allow list on SeaDrop.
        c_d527060f(0x0a623160ed0ecdb1); /* line */
        c_d527060f(0xe9bcb92a52199d5a); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updateAllowList(allowListData);
    }

    /**
     * @notice Update the token gated drop stage data for this nft contract
     *         on SeaDrop.
     *         Only the owner can use this function.
     *
     *         Note: If two INonFungibleSeaDropToken tokens are doing
     *         simultaneous token gated drop promotions for each other,
     *         they can be minted by the same actor until
     *         `maxTokenSupplyForStage` is reached. Please ensure the
     *         `allowedNftToken` is not running an active drop during the
     *         `dropStage` time period.
     *
     * @param seaDropImpl     The allowed SeaDrop contract.
     * @param allowedNftToken The allowed nft token.
     * @param dropStage       The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address seaDropImpl,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    )
        external
        virtual
        override
        c_mod071d6fb0
        onlyOwner
        c_mod19d8392f
        c_mod7ab1b03e
        onlyAllowedSeaDrop(seaDropImpl)
        c_mod4b291931
    {
        c_d527060f(0xaabee1ae560d54e8); /* function */

        // Update the token gated drop stage.
        c_d527060f(0xffa228bb71642ad0); /* line */
        c_d527060f(0x6bf131be51c74f72); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updateTokenGatedDrop(
            allowedNftToken,
            dropStage
        );
    }

    /**
     * @notice Update the drop URI for this nft contract on SeaDrop.
     *         Only the owner can use this function.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param dropURI     The new drop URI.
     */
    function updateDropURI(address seaDropImpl, string calldata dropURI)
        external
        virtual
        override
        c_mod81c4c3e7
        onlyOwner
        c_mod5a4bacf3
        c_mod5109d810
        onlyAllowedSeaDrop(seaDropImpl)
        c_mod2d3609f7
    {
        c_d527060f(0x02f9e83275c062d0); /* function */

        // Update the drop URI.
        c_d527060f(0x759860a18861b3d7); /* line */
        c_d527060f(0x8472b7f20e9756cf); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updateDropURI(dropURI);
    }

    /**
     * @notice Update the creator payout address for this nft contract on SeaDrop.
     *         Only the owner can set the creator payout address.
     *
     * @param seaDropImpl   The allowed SeaDrop contract.
     * @param payoutAddress The new payout address.
     */
    function updateCreatorPayoutAddress(
        address seaDropImpl,
        address payoutAddress
    )
        external
        c_mod64041d1c
        onlyOwner
        c_mod4602f1d0
        c_modfef441b2
        onlyAllowedSeaDrop(seaDropImpl)
        c_mode0c0e150
    {
        c_d527060f(0x97503474dc944dfc); /* function */

        // Update the creator payout address.
        c_d527060f(0x387d89e270f9fe44); /* line */
        c_d527060f(0x15e081c291c4a856); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updateCreatorPayoutAddress(
            payoutAddress
        );
    }

    /**
     * @notice Update the allowed fee recipient for this nft contract
     *         on SeaDrop.
     *         Only the owner can set the allowed fee recipient.
     *
     * @param seaDropImpl  The allowed SeaDrop contract.
     * @param feeRecipient The new fee recipient.
     * @param allowed      If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(
        address seaDropImpl,
        address feeRecipient,
        bool allowed
    )
        external
        virtual
        c_mod676bd09a
        onlyOwner
        c_mod96740165
        c_mod31d20c51
        onlyAllowedSeaDrop(seaDropImpl)
        c_mod954ed8e5
    {
        c_d527060f(0xfcd812c62f261ead); /* function */

        // Update the allowed fee recipient.
        c_d527060f(0x3d91b9a5600f05f9); /* line */
        c_d527060f(0x78c40b7ab5c7d3c9); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updateAllowedFeeRecipient(
            feeRecipient,
            allowed
        );
    }

    /**
     * @notice Update the server-side signers for this nft contract
     *         on SeaDrop.
     *         Only the owner can use this function.
     *
     * @param seaDropImpl                The allowed SeaDrop contract.
     * @param signer                     The signer to update.
     * @param signedMintValidationParams Minimum and maximum parameters to
     *                                   enforce for signed mints.
     */
    function updateSignedMintValidationParams(
        address seaDropImpl,
        address signer,
        SignedMintValidationParams memory signedMintValidationParams
    )
        external
        virtual
        override
        c_modafe22915
        onlyOwner
        c_mod15fd79e8
        c_mod9400e2b6
        onlyAllowedSeaDrop(seaDropImpl)
        c_mod6422ee31
    {
        c_d527060f(0x7681664a454dda99); /* function */

        // Update the signer.
        c_d527060f(0xc55ac01663e0cc07); /* line */
        c_d527060f(0xf167387f0fb1624f); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
    }

    /**
     * @notice Update the allowed payers for this nft contract on SeaDrop.
     *         Only the owner can use this function.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param payer       The payer to update.
     * @param allowed     Whether the payer is allowed.
     */
    function updatePayer(
        address seaDropImpl,
        address payer,
        bool allowed
    )
        external
        virtual
        override
        c_mod9b2b9d83
        onlyOwner
        c_mod2b24e034
        c_modefb7bba3
        onlyAllowedSeaDrop(seaDropImpl)
        c_modddb9c0ca
    {
        c_d527060f(0x2d56c977eff020ca); /* function */

        // Update the payer.
        c_d527060f(0x8030c74fc9c91a8c); /* line */
        c_d527060f(0x312bc4fc2278a1f0); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updatePayer(payer, allowed);
    }

    /**
     * @notice Returns a set of mint stats for the address.
     *         This assists SeaDrop in enforcing maxSupply,
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
        c_d527060f(0x1476a3c48286f8a1); /* function */

        c_d527060f(0x2c50a543c460f181); /* line */
        minterNumMinted = _numberMinted(minter);
        c_d527060f(0x9aaacbecf62e7843); /* line */
        currentTotalSupply = _totalMinted();
        c_d527060f(0xe5760bbc18241737); /* line */
        maxSupply = ERC721ContractMetadataStorage.layout()._maxSupply;
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
        override(IERC165Upgradeable, ERC721AUpgradeable)
        returns (bool)
    {
        c_d527060f(0xcf6d379b2b73b84b); /* function */

        c_d527060f(0x5858e42e0a79d49a); /* line */
        c_d527060f(0xf67c247233a5b16f); /* statement */
        return
            ((interfaceId ==
                type(INonFungibleSeaDropTokenUpgradeable).interfaceId &&
                c_trued527060f(0x950245f740b9cc46)) ||
                ((interfaceId ==
                    type(ISeaDropTokenContractMetadataUpgradeable)
                        .interfaceId &&
                    c_trued527060f(0xcf9226f9b38f004f)) &&
                    c_trued527060f(0x8b74e38188c8e713))) ||
            // ERC721A returns supportsInterface true for
            // ERC165, ERC721, ERC721Metadata
            (super.supportsInterface(interfaceId) &&
                c_trued527060f(0x5a19a9fb8bb3021d));
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
     * - The operator (msg.sender) must be allowed.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override c_mod6efbb7d2 onlyAllowedOperator(from) c_mod202a337c {
        c_d527060f(0xda7e351e7f12838f); /* function */

        c_d527060f(0x037b13e1dc40d047); /* line */
        c_d527060f(0x28bd2b0e5e1921dc); /* statement */
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override c_mod10543891 onlyAllowedOperator(from) c_mod43f1f644 {
        c_d527060f(0xf2623cacb5078dcf); /* function */

        c_d527060f(0xbfb0a08800570a68); /* line */
        c_d527060f(0x45f1f36d6111ddf7); /* statement */
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
     * - The operator (msg.sender) must be allowed.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override c_modfc5038a2 onlyAllowedOperator(from) c_mod3cfbb367 {
        c_d527060f(0x37b110c976cc8171); /* function */

        c_d527060f(0xed10de0be8894704); /* line */
        c_d527060f(0x762b6a2cf4778a49); /* statement */
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
