// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DelegationRegistry } from "seadrop/test/DelegationRegistry.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import {
    ERC1155SeaDropConfigurer
} from "seadrop/lib/ERC1155SeaDropConfigurer.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import { MintParams } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import { AllowListData, CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

import { SeaDropErrorsAndEvents } from "seadrop/lib/SeaDropErrorsAndEvents.sol";

import { BaseOrderTest } from "seaport-test-utils/BaseOrderTest.sol";

import {
    CriteriaResolver,
    ItemType
} from "seaport/lib/ConsiderationStructs.sol";

import { OrderType } from "seaport/lib/ConsiderationEnums.sol";

import {
    ZoneInteractionErrors
} from "seaport/interfaces/ZoneInteractionErrors.sol";

import { Merkle } from "murky/Merkle.sol";

contract SeaDrop1155Test is
    BaseOrderTest,
    SeaDropErrorsAndEvents,
    ZoneInteractionErrors
{
    /// @dev The SeaDrop token.
    ERC1155SeaDrop token;

    /// @dev The configurer contract.
    ERC1155SeaDropConfigurer configurer;

    /// @dev The allowed Seaport address to interact with the contract token.
    address internal allowedSeaport;

    /// @dev SeaDrop doesn't use criteria resolvers.
    CriteriaResolver[] internal criteriaResolvers;

    /// @notice Internal constants for EIP-712: Typed structured
    ///         data hashing and signing
    bytes32 internal constant _SIGNED_MINT_TYPEHASH =
        // prettier-ignore
        keccak256(
             "SignedMint("
                "address minter,"
                "address feeRecipient,"
                "MintParams mintParams,"
                "uint256 salt"
            ")"
            "MintParams("
                "uint256 startPrice,"
                "uint256 endPrice,"
                "uint256 startTime,"
                "uint256 endTime,"
                "address paymentToken,"
                "uint256 fromTokenId,"
                "uint256 toTokenId,"
                "uint256 maxTotalMintableByWallet,"
                "uint256 maxTotalMintableByWalletPerToken,"
                "uint256 maxTokenSupplyForStage,"
                "uint256 dropStageIndex,"
                "uint256 feeBps,"
                "bool restrictFeeRecipients"
            ")"
        );
    bytes32 internal constant _MINT_PARAMS_TYPEHASH =
        // prettier-ignore
        keccak256(
            "MintParams("
                "uint256 startPrice,"
                "uint256 endPrice,"
                "uint256 startTime,"
                "uint256 endTime,"
                "address paymentToken,"
                "uint256 fromTokenId,"
                "uint256 toTokenId,"
                "uint256 maxTotalMintableByWallet,"
                "uint256 maxTotalMintableByWalletPerToken,"
                "uint256 maxTokenSupplyForStage,"
                "uint256 dropStageIndex,"
                "uint256 feeBps,"
                "bool restrictFeeRecipients"
            ")"
        );
    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH =
        // prettier-ignore
        keccak256(
            "EIP712Domain("
                "string name,"
                "string version,"
                "uint256 chainId,"
                "address verifyingContract"
            ")"
        );
    bytes32 internal constant _NAME_HASH = keccak256("ERC1155SeaDrop");
    bytes32 internal constant _VERSION_HASH = keccak256("2.0");
    uint256 internal immutable _CHAIN_ID = block.chainid;

    function setUp() public virtual override {
        super.setUp();

        // Set configurer
        configurer = new ERC1155SeaDropConfigurer();

        // Set allowedSeaport
        allowedSeaport = address(consideration);

        // Deploy DelegationRegistry to the expected address.
        address registryAddress = 0x00000000000076A84feF008CDAbe6409d2FE638B;
        address deployedRegistry = address(new DelegationRegistry());
        vm.etch(registryAddress, deployedRegistry.code);
    }

    /**
     * Drop configuration
     */
    function setSingleCreatorPayout(address creator) internal {
        CreatorPayout[] memory creatorPayouts = new CreatorPayout[](1);
        creatorPayouts[0] = CreatorPayout({
            payoutAddress: creator,
            basisPoints: 10_000
        });
        IERC1155SeaDrop(address(token)).updateCreatorPayouts(creatorPayouts);
    }

    function setAllowListMerkleRootAndReturnProof(
        address[] memory allowList,
        uint256 proofIndex,
        MintParams memory mintParams
    ) internal returns (bytes32[] memory) {
        (bytes32 root, bytes32[] memory proof) = _createMerkleRootAndProof(
            allowList,
            proofIndex,
            mintParams
        );
        AllowListData memory allowListData = AllowListData({
            merkleRoot: root,
            publicKeyURIs: new string[](0),
            allowListURI: ""
        });
        IERC1155SeaDrop(address(token)).updateAllowList(allowListData);
        return proof;
    }

    function _createMerkleRootAndProof(
        address[] memory allowList,
        uint256 proofIndex,
        MintParams memory mintParams
    ) internal returns (bytes32 root, bytes32[] memory proof) {
        require(proofIndex < allowList.length);

        // Declare a bytes32 array for the allowlist tuples.
        bytes32[] memory allowListTuples = new bytes32[](allowList.length);

        // Create allowList tuples using allowList addresses and mintParams.
        for (uint256 i = 0; i < allowList.length; i++) {
            allowListTuples[i] = keccak256(
                abi.encode(allowList[i], mintParams)
            );
        }

        // Initialize Merkle.
        Merkle m = new Merkle();

        // Get the merkle root of the allowlist tuples.
        root = m.getRoot(allowListTuples);

        // Get the merkle proof of the tuple at proofIndex.
        proof = m.getProof(allowListTuples, proofIndex);

        // Verify that the merkle root can be obtained from the proof.
        bool verified = m.verifyProof(root, proof, allowListTuples[proofIndex]);
        assertTrue(verified);
    }

    function getSignedMint(
        string memory signerName,
        address seadrop,
        address minter,
        address feeRecipient,
        MintParams memory mintParams,
        uint256 salt,
        bool compact2098
    ) internal returns (bytes memory signature) {
        bytes32 digest = _getDigest(
            seadrop,
            minter,
            feeRecipient,
            mintParams,
            salt
        );
        (, uint256 pk) = makeAddrAndKey(signerName);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        if (compact2098) {
            signature = _encodeSignature2098(r, s, v);
        } else {
            signature = abi.encodePacked(r, s, v);
        }
    }

    function _getDigest(
        address seadrop,
        address minter,
        address feeRecipient,
        MintParams memory mintParams,
        uint256 salt
    ) internal view returns (bytes32 digest) {
        MintParams memory mintParams_ = mintParams;
        bytes32 mintParamsHashStruct = keccak256(
            abi.encode(
                _MINT_PARAMS_TYPEHASH,
                mintParams_.startPrice,
                mintParams_.endPrice,
                mintParams_.startTime,
                mintParams_.endTime,
                mintParams_.paymentToken,
                mintParams_.fromTokenId,
                mintParams_.toTokenId,
                mintParams_.maxTotalMintableByWallet,
                mintParams_.maxTotalMintableByWalletPerToken,
                mintParams_.maxTokenSupplyForStage,
                mintParams_.dropStageIndex,
                mintParams_.feeBps,
                mintParams_.restrictFeeRecipients
            )
        );
        digest = keccak256(
            bytes.concat(
                bytes2(0x1901),
                _deriveDomainSeparator(seadrop),
                keccak256(
                    abi.encode(
                        _SIGNED_MINT_TYPEHASH,
                        minter,
                        feeRecipient,
                        mintParamsHashStruct,
                        salt
                    )
                )
            )
        );
    }

    /**
     * Order helpers
     */
    function addSeaDropOfferItem(uint256 identifier, uint256 amount) internal {
        addOfferItem(ItemType.ERC1155, address(token), identifier, amount);
    }

    function addSeaDropConsiderationItems(
        address feeRecipient,
        uint256 feeBps,
        uint256 totalValue
    ) internal {
        // Add consideration item for fee recipient.
        uint256 feeAmount = (totalValue * feeBps) / 10_000;
        uint256 creatorAmount = totalValue - feeAmount;
        addConsiderationItem(
            payable(feeRecipient),
            ItemType.NATIVE,
            address(0),
            0,
            feeAmount,
            feeAmount
        );

        // Add consideration items for creator payouts.
        CreatorPayout[] memory creatorPayouts = IERC1155SeaDrop(address(token))
            .getCreatorPayouts();
        for (uint256 i = 0; i < creatorPayouts.length; i++) {
            uint256 amount = (creatorAmount * creatorPayouts[i].basisPoints) /
                10_000;
            addConsiderationItem(
                payable(creatorPayouts[i].payoutAddress),
                ItemType.NATIVE,
                address(0),
                0,
                amount,
                amount
            );
        }
    }

    function configureSeaDropOrderParameters() internal {
        _configureOrderParameters({
            offerer: address(token),
            zone: address(0),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.CONTRACT;
        configureOrderComponents(0);
    }

    function _deriveDomainSeparator(
        address seadrop
    ) internal view returns (bytes32) {
        // prettier-ignore
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                seadrop
            )
        );
    }

    function _encodeSignature2098(
        bytes32 r,
        bytes32 s,
        uint8 v
    ) internal pure returns (bytes memory) {
        uint256 yParity;
        if (v == 27) {
            yParity = 0;
        } else {
            yParity = 1;
        }
        uint256 yParityAndS = (yParity << 255) | uint256(s);
        return abi.encodePacked(r, yParityAndS);
    }
}
