// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

function c_827753e8(bytes8 c__827753e8) pure {}

function c_true827753e8(bytes8 c__827753e8) pure returns (bool) {
    return true;
}

function c_false827753e8(bytes8 c__827753e8) pure returns (bool) {
    return false;
}

import { ERC721SeaDropUpgradeable } from "./ERC721SeaDropUpgradeable.sol";

import { ISeaDropUpgradeable } from "./interfaces/ISeaDropUpgradeable.sol";

import {
    AllowListData,
    PublicDrop,
    TokenGatedDropStage,
    SignedMintValidationParams
} from "./lib/SeaDropStructsUpgradeable.sol";

import {
    TwoStepAdministeredUpgradeable
} from "../lib/utility-contracts/src/TwoStepAdministeredUpgradeable.sol";
import {
    TwoStepAdministeredStorage
} from "../lib/utility-contracts/src/TwoStepAdministeredStorage.sol";

/**
 * @title  ERC721PartnerSeaDrop
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721PartnerSeaDrop is a token contract that contains methods
 *         to properly interact with SeaDrop, with additional administrative
 *         functionality tailored for business requirements around partnered
 *         mints with off-chain agreements in place between two parties.
 *
 *         The "Owner" should control mint specifics such as price and start.
 *         The "Administrator" should control fee parameters.
 *
 *         Otherwise, for ease of administration, either Owner or Administrator
 *         should be able to configure mint parameters. They have the ability
 *         to override each other's actions in many circumstances, which is
 *         why the establishment of off-chain trust is important.
 *
 *         Note: An Administrator is not required to interface with SeaDrop.
 */
contract ERC721PartnerSeaDropUpgradeable is
    ERC721SeaDropUpgradeable,
    TwoStepAdministeredUpgradeable
{
    using TwoStepAdministeredStorage for TwoStepAdministeredStorage.Layout;

    function c_60c9757a(bytes8 c__60c9757a) internal pure {}

    function c_true60c9757a(bytes8 c__60c9757a) internal pure returns (bool) {
        return true;
    }

    function c_false60c9757a(bytes8 c__60c9757a) internal pure returns (bool) {
        return false;
    }

    modifier c_modf14a66b2() {
        c_60c9757a(0x6b63414c92a572c0); /* modifier-post */
        _;
    }
    modifier c_modfc7144ec() {
        c_60c9757a(0x89771e8aaddb4a1b); /* modifier-pre */
        _;
    }
    modifier c_modfed485eb() {
        c_60c9757a(0x3866d9e83daa600f); /* modifier-post */
        _;
    }
    modifier c_mode42dbd3d() {
        c_60c9757a(0x1d7e2a066c4b64eb); /* modifier-pre */
        _;
    }
    modifier c_mod450f0345() {
        c_60c9757a(0x887f1a2c3ec57dc0); /* modifier-post */
        _;
    }
    modifier c_mod0425b4f0() {
        c_60c9757a(0x7b58e7b26be55375); /* modifier-pre */
        _;
    }
    modifier c_modb2da17f4() {
        c_60c9757a(0x85487e7e799289fa); /* modifier-post */
        _;
    }
    modifier c_mod5f3892c8() {
        c_60c9757a(0x75ff3f05190066c2); /* modifier-pre */
        _;
    }
    modifier c_mod11dd9477() {
        c_60c9757a(0x993cc62c19805681); /* modifier-post */
        _;
    }
    modifier c_mod6cb9d867() {
        c_60c9757a(0xf601ce9065465f3b); /* modifier-pre */
        _;
    }
    modifier c_modee32e96b() {
        c_60c9757a(0xe5a5aec627f1a296); /* modifier-post */
        _;
    }
    modifier c_mod08f92c65() {
        c_60c9757a(0x35018dbbb4395c73); /* modifier-pre */
        _;
    }
    modifier c_mod64a1778e() {
        c_60c9757a(0x10750da062b15134); /* modifier-post */
        _;
    }
    modifier c_moddb1fb247() {
        c_60c9757a(0xbaffdc5ffc771447); /* modifier-pre */
        _;
    }
    modifier c_mod2448366b() {
        c_60c9757a(0x6ce567c924cc4eb9); /* modifier-post */
        _;
    }
    modifier c_mod5ee91b96() {
        c_60c9757a(0x08934a5cc8da8107); /* modifier-pre */
        _;
    }
    modifier c_mod97a6928b() {
        c_60c9757a(0x43a8c46c69aa1ddc); /* modifier-post */
        _;
    }
    modifier c_mod215415f4() {
        c_60c9757a(0xb0929e52b61a0b4d); /* modifier-pre */
        _;
    }
    modifier c_mod3bc086f7() {
        c_60c9757a(0xbc1068ee70294d02); /* modifier-post */
        _;
    }
    modifier c_mod0d64bc36() {
        c_60c9757a(0x9f7c8c867c938aa5); /* modifier-pre */
        _;
    }
    modifier c_mod400c8bc6() {
        c_60c9757a(0xa53e559b7c5c6c10); /* modifier-post */
        _;
    }
    modifier c_mod0933e736() {
        c_60c9757a(0xb80e0d75f7c30f23); /* modifier-pre */
        _;
    }
    modifier c_mod910a6ae8() {
        c_60c9757a(0xc2b2ddb6363edf87); /* modifier-post */
        _;
    }
    modifier c_modb829701c() {
        c_60c9757a(0x1371bab9dce5858f); /* modifier-pre */
        _;
    }
    modifier c_modd7ef1442() {
        c_60c9757a(0x8230c2a275b1c47a); /* modifier-post */
        _;
    }
    modifier c_mod2005f4a3() {
        c_60c9757a(0x5bde5daf75672baf); /* modifier-pre */
        _;
    }
    modifier c_modb4df92e2() {
        c_60c9757a(0x05d3c77b1c14e383); /* modifier-post */
        _;
    }
    modifier c_mod085fc00f() {
        c_60c9757a(0xce617cdee1c9798d); /* modifier-pre */
        _;
    }
    modifier c_mod976c2dc8() {
        c_60c9757a(0x755e683a38d63af1); /* modifier-post */
        _;
    }
    modifier c_mod76e882ec() {
        c_60c9757a(0xf82cdea9693e4b11); /* modifier-pre */
        _;
    }
    modifier c_mod36fd2584() {
        c_60c9757a(0x0cd232b15cee718e); /* modifier-post */
        _;
    }
    modifier c_mode60ba18b() {
        c_60c9757a(0x15124ed78baddda7); /* modifier-pre */
        _;
    }

    /// @notice To prevent Owner from overriding fees, Administrator must
    ///         first initialize with fee.
    error AdministratorMustInitializeWithFee();

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    function __ERC721PartnerSeaDrop_init(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    ) internal onlyInitializing {
        __ERC721A_init_unchained(name, symbol);
        __ConstructorInitializable_init_unchained();
        __TwoStepOwnable_init_unchained();
        __ERC721ContractMetadata_init_unchained(name, symbol);
        __ReentrancyGuard_init_unchained();
        __ERC721SeaDrop_init_unchained(name, symbol, allowedSeaDrop);
        __TwoStepAdministered_init_unchained(administrator);
        __ERC721PartnerSeaDrop_init_unchained(
            name,
            symbol,
            administrator,
            allowedSeaDrop
        );
    }

    function __ERC721PartnerSeaDrop_init_unchained(
        string memory,
        string memory,
        address,
        address[] memory
    ) internal onlyInitializing {
        c_60c9757a(0x46227060ee4c1372); /* function */
    }

    /**
     * @notice Mint tokens, restricted to the SeaDrop contract.
     *
     * @param minter   The address to mint to.
     * @param quantity The number of tokens to mint.
     */
    function mintSeaDrop(address minter, uint256 quantity)
        external
        payable
        virtual
        override
        c_mode60ba18b
        onlyAllowedSeaDrop(msg.sender)
        c_mod36fd2584
    {
        c_60c9757a(0x49183c9c8aca4962); /* function */

        // Extra safety check to ensure the max supply is not exceeded.
        c_60c9757a(0x0811ae00921e5e4e); /* line */
        c_60c9757a(0xa3bab4750d7fc687); /* statement */
        if (_totalMinted() + quantity > maxSupply()) {
            c_60c9757a(0xae01f5ee1b8981e0); /* branch */

            c_60c9757a(0x91eda2e7a01ed4ad); /* line */
            revert MintQuantityExceedsMaxSupply(
                _totalMinted() + quantity,
                maxSupply()
            );
        } else {
            c_60c9757a(0x46f59258bfdb83e3); /* branch */
        }

        // Mint the quantity of tokens to the minter.
        c_60c9757a(0xd48d819bf71bc721); /* line */
        c_60c9757a(0x1b35ec695b583986); /* statement */
        _mint(minter, quantity);
    }

    /**
     * @notice Update the allowed SeaDrop contracts.
     *         Only the owner or administrator can use this function.
     *
     * @param allowedSeaDrop The allowed SeaDrop addresses.
     */
    function updateAllowedSeaDrop(address[] calldata allowedSeaDrop)
        external
        override
        c_mod76e882ec
        onlyOwnerOrAdministrator
        c_mod976c2dc8
    {
        c_60c9757a(0x38e299f892b3f7a1); /* function */

        c_60c9757a(0xd3da06e94ee2ce42); /* line */
        c_60c9757a(0xe272a36f66bd86c4); /* statement */
        _updateAllowedSeaDrop(allowedSeaDrop);
    }

    /**
     * @notice Update the public drop data for this nft contract on SeaDrop.
     *         Only the owner or administrator can use this function.
     *
     *         The administrator can only update `feeBps`.
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
        c_mod085fc00f
        onlyOwnerOrAdministrator
        c_modb4df92e2
        c_mod2005f4a3
        onlyAllowedSeaDrop(seaDropImpl)
        c_modd7ef1442
    {
        c_60c9757a(0xa068d4789837b878); /* function */

        // Track the previous public drop data.
        c_60c9757a(0x67903bb92879a819); /* line */
        c_60c9757a(0xef7e28f8939fc91b); /* statement */
        PublicDrop memory retrieved = ISeaDropUpgradeable(seaDropImpl)
            .getPublicDrop(address(this));

        // Track the newly supplied drop data.
        c_60c9757a(0x7888442f69136c42); /* line */
        c_60c9757a(0x96b74a8d0e536f51); /* statement */
        PublicDrop memory supplied = publicDrop;

        // Only the administrator (OpenSea) can set feeBps.
        c_60c9757a(0x79d12bedd0d1f4d0); /* line */
        c_60c9757a(0x9118c0bf4fa8ac23); /* statement */
        if (msg.sender != TwoStepAdministeredStorage.layout().administrator) {
            c_60c9757a(0x8ac6dad8b7ee92a2); /* branch */

            // Administrator must first set fee.
            c_60c9757a(0xbaef42845ae435d2); /* line */
            c_60c9757a(0x364b14e0af5e3046); /* statement */
            if (retrieved.maxTotalMintableByWallet == 0) {
                c_60c9757a(0x1e80a7b9bfdc6ac5); /* branch */

                c_60c9757a(0xff5e74443fdbef6b); /* line */
                revert AdministratorMustInitializeWithFee();
            } else {
                c_60c9757a(0xec5472bffe024ae4); /* branch */
            }
            c_60c9757a(0xd83f05cc4e901d3a); /* line */
            supplied.feeBps = retrieved.feeBps;
            c_60c9757a(0x67b1f3e2d540ed38); /* line */
            supplied.restrictFeeRecipients = true;
        } else {
            c_60c9757a(0x40ab4d6fb81397d0); /* branch */

            // Administrator can only initialize
            // (maxTotalMintableByWallet > 0) and set
            // feeBps/restrictFeeRecipients.
            c_60c9757a(0x67ce576f1d00a72e); /* line */
            c_60c9757a(0x30993261a38b29bb); /* statement */
            uint16 maxTotalMintableByWallet = retrieved
                .maxTotalMintableByWallet;
            c_60c9757a(0xeca5a176a25182b3); /* line */
            retrieved.maxTotalMintableByWallet = ((maxTotalMintableByWallet >
                0 &&
                c_true60c9757a(0xb4476ee656219d6f)) ||
                c_false60c9757a(0x08c175bebc3d1e34))
                ? maxTotalMintableByWallet
                : 1;
            c_60c9757a(0xc80087bc84526c4f); /* line */
            retrieved.feeBps = supplied.feeBps;
            c_60c9757a(0x5841bbf8e4b2a8a0); /* line */
            retrieved.restrictFeeRecipients = true;
            c_60c9757a(0xda192ae464c0c1c7); /* line */
            supplied = retrieved;
        }

        // Update the public drop data on SeaDrop.
        c_60c9757a(0x816f5d2e87336bb6); /* line */
        c_60c9757a(0xbd43812c168d8490); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updatePublicDrop(supplied);
    }

    /**
     * @notice Update the allow list data for this nft contract on SeaDrop.
     *         Only the owner or administrator can use this function.
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
        c_modb829701c
        onlyOwnerOrAdministrator
        c_mod910a6ae8
        c_mod0933e736
        onlyAllowedSeaDrop(seaDropImpl)
        c_mod400c8bc6
    {
        c_60c9757a(0x928ede3bd7a035aa); /* function */

        // Update the allow list on SeaDrop.
        c_60c9757a(0x2e9366532b8ff172); /* line */
        c_60c9757a(0xe1c8034ca6d3d7e9); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updateAllowList(allowListData);
    }

    /**
     * @notice Update the token gated drop stage data for this nft contract
     *         on SeaDrop.
     *         Only the owner or administrator can use this function.
     *
     *         The administrator must first set `feeBps`.
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
        c_mod0d64bc36
        onlyOwnerOrAdministrator
        c_mod3bc086f7
        c_mod215415f4
        onlyAllowedSeaDrop(seaDropImpl)
        c_mod97a6928b
    {
        c_60c9757a(0xbc508548d930223c); /* function */

        // Track the previous drop stage data.
        c_60c9757a(0xee8e20886803ca3b); /* line */
        c_60c9757a(0xf7e0cb840432b52e); /* statement */
        TokenGatedDropStage memory retrieved = ISeaDropUpgradeable(seaDropImpl)
            .getTokenGatedDrop(address(this), allowedNftToken);

        // Track the newly supplied drop data.
        c_60c9757a(0xa65ea46ece3a4875); /* line */
        c_60c9757a(0xf1a60b0ab40fba03); /* statement */
        TokenGatedDropStage memory supplied = dropStage;

        // Only the administrator (OpenSea) can set feeBps on Partner
        // contracts.
        c_60c9757a(0x0d31f10689b11617); /* line */
        c_60c9757a(0xda9d6d735e5e37bb); /* statement */
        if (msg.sender != TwoStepAdministeredStorage.layout().administrator) {
            c_60c9757a(0x8b6cbe4ef41f2479); /* branch */

            // Administrator must first set fee.
            c_60c9757a(0x8c61ec2942fc23f8); /* line */
            c_60c9757a(0xb9fe92944e0309e2); /* statement */
            if (retrieved.maxTotalMintableByWallet == 0) {
                c_60c9757a(0x021f8385f360bdf2); /* branch */

                c_60c9757a(0x3adc455b48220470); /* line */
                revert AdministratorMustInitializeWithFee();
            } else {
                c_60c9757a(0x447f888ab20ca5c6); /* branch */
            }
            c_60c9757a(0x506968fb366b66e6); /* line */
            supplied.feeBps = retrieved.feeBps;
            c_60c9757a(0xf2b5636e81adc9eb); /* line */
            supplied.restrictFeeRecipients = true;
        } else {
            c_60c9757a(0xf99db162176f0f2f); /* branch */

            // Administrator can only initialize
            // (maxTotalMintableByWallet > 0) and set
            // feeBps/restrictFeeRecipients.
            c_60c9757a(0x668f0cf8381f9502); /* line */
            c_60c9757a(0xc5bddaf4b7aca39a); /* statement */
            uint16 maxTotalMintableByWallet = retrieved
                .maxTotalMintableByWallet;
            c_60c9757a(0x6f1a8b3880cd915b); /* line */
            retrieved.maxTotalMintableByWallet = ((maxTotalMintableByWallet >
                0 &&
                c_true60c9757a(0x9e92c7037267b50e)) ||
                c_false60c9757a(0x89e2705a0d3cc24d))
                ? maxTotalMintableByWallet
                : 1;
            c_60c9757a(0x45b41060acbf9470); /* line */
            retrieved.feeBps = supplied.feeBps;
            c_60c9757a(0xf808fcf0c638cbc4); /* line */
            retrieved.restrictFeeRecipients = true;
            c_60c9757a(0xe5853d90c0c945ab); /* line */
            supplied = retrieved;
        }

        // Update the token gated drop stage.
        c_60c9757a(0xdfb7179563fbf6d7); /* line */
        c_60c9757a(0x855221daac19c700); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updateTokenGatedDrop(
            allowedNftToken,
            supplied
        );
    }

    /**
     * @notice Update the drop URI for this nft contract on SeaDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param dropURI     The new drop URI.
     */
    function updateDropURI(address seaDropImpl, string calldata dropURI)
        external
        virtual
        override
        c_mod5ee91b96
        onlyOwnerOrAdministrator
        c_mod2448366b
        c_moddb1fb247
        onlyAllowedSeaDrop(seaDropImpl)
        c_mod64a1778e
    {
        c_60c9757a(0xbb6b7d8ad17f42bc); /* function */

        // Update the drop URI.
        c_60c9757a(0x067fa3346b3387b2); /* line */
        c_60c9757a(0x172f119407c194c7); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updateDropURI(dropURI);
    }

    /**
     * @notice Update the allowed fee recipient for this nft contract
     *         on SeaDrop.
     *         Only the administrator can set the allowed fee recipient.
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
        override
        c_mod08f92c65
        onlyAdministrator
        c_modee32e96b
        c_mod6cb9d867
        onlyAllowedSeaDrop(seaDropImpl)
        c_mod11dd9477
    {
        c_60c9757a(0x8ea0d1e9ffa6e145); /* function */

        // Update the allowed fee recipient.
        c_60c9757a(0x15e7c6e393569512); /* line */
        c_60c9757a(0xc3b77d222f2061ac); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updateAllowedFeeRecipient(
            feeRecipient,
            allowed
        );
    }

    /**
     * @notice Update the server-side signers for this nft contract
     *         on SeaDrop.
     *         Only the owner or administrator can use this function.
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
        c_mod5f3892c8
        onlyOwnerOrAdministrator
        c_modb2da17f4
        c_mod0425b4f0
        onlyAllowedSeaDrop(seaDropImpl)
        c_mod450f0345
    {
        c_60c9757a(0x498b21a88c913e2a); /* function */

        // Track the previous signed mint validation params.
        c_60c9757a(0xfe9d5a532a570a86); /* line */
        c_60c9757a(0xff3ec29044b988fa); /* statement */
        SignedMintValidationParams memory retrieved = ISeaDropUpgradeable(
            seaDropImpl
        ).getSignedMintValidationParams(address(this), signer);

        // Track the newly supplied params.
        c_60c9757a(0xf1a4626c61f0cc75); /* line */
        c_60c9757a(0xe32a1bc9732a0c96); /* statement */
        SignedMintValidationParams memory supplied = signedMintValidationParams;

        // Only the administrator (OpenSea) can set feeBps on Partner
        // contracts.
        c_60c9757a(0x09e1c20a7e5c9cb3); /* line */
        c_60c9757a(0x6b14e69c6e68f870); /* statement */
        if (msg.sender != TwoStepAdministeredStorage.layout().administrator) {
            c_60c9757a(0x8642f1b6d1f82d83); /* branch */

            // Administrator must first set fee.
            c_60c9757a(0x64838a3532078010); /* line */
            c_60c9757a(0xfc1d29270552f304); /* statement */
            if (retrieved.maxMaxTotalMintableByWallet == 0) {
                c_60c9757a(0xd18b4cd86bc0bdc2); /* branch */

                c_60c9757a(0xc361f269d203684f); /* line */
                revert AdministratorMustInitializeWithFee();
            } else {
                c_60c9757a(0xda8058a40df96aa5); /* branch */
            }
            c_60c9757a(0x405d2dfabdc3ff7b); /* line */
            supplied.minFeeBps = retrieved.minFeeBps;
            c_60c9757a(0x767e30b005599cb1); /* line */
            supplied.maxFeeBps = retrieved.maxFeeBps;
        } else {
            c_60c9757a(0x8c04cc30ac09e6e8); /* branch */

            // Administrator can only initialize
            // (maxTotalMintableByWallet > 0) and set
            // feeBps/restrictFeeRecipients.
            c_60c9757a(0x3dac27cf37be55d7); /* line */
            c_60c9757a(0x68f886779ffd0d78); /* statement */
            uint24 maxMaxTotalMintableByWallet = retrieved
                .maxMaxTotalMintableByWallet;
            c_60c9757a(0xe72137fc734d1ee9); /* line */
            retrieved
                .maxMaxTotalMintableByWallet = ((maxMaxTotalMintableByWallet >
                0 &&
                c_true60c9757a(0xbc0a1c4a73723737)) ||
                c_false60c9757a(0x2c02638db7d11ec6))
                ? maxMaxTotalMintableByWallet
                : 1;
            c_60c9757a(0xd0015be85c89a3fa); /* line */
            retrieved.minFeeBps = supplied.minFeeBps;
            c_60c9757a(0x57bcd10590080432); /* line */
            retrieved.maxFeeBps = supplied.maxFeeBps;
            c_60c9757a(0x70208e9f374958a2); /* line */
            supplied = retrieved;
        }

        // Update the signed mint validation params.
        c_60c9757a(0xc1043e4f8abdacef); /* line */
        c_60c9757a(0xf35e9111d1ce2498); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updateSignedMintValidationParams(
            signer,
            supplied
        );
    }

    /**
     * @notice Update the allowed payers for this nft contract on SeaDrop.
     *         Only the owner or administrator can use this function.
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
        c_mode42dbd3d
        onlyOwnerOrAdministrator
        c_modfed485eb
        c_modfc7144ec
        onlyAllowedSeaDrop(seaDropImpl)
        c_modf14a66b2
    {
        c_60c9757a(0x0f3ba04544779ca4); /* function */

        // Update the payer.
        c_60c9757a(0x8d9a9922f47f174b); /* line */
        c_60c9757a(0x20c1c7c28aa12b63); /* statement */
        ISeaDropUpgradeable(seaDropImpl).updatePayer(payer, allowed);
    }
}
