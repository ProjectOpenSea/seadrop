// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDropTest } from "./SeaDropTest.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import {
    ERC1155SeaDropConfigurer
} from "seadrop/lib/ERC1155SeaDropConfigurer.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import { MintParams, PublicDrop } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import {
    AdvancedOrder,
    OfferItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

/**
 * @dev Base for the ERC1155SeaDrop Forge tests: deploys the configurer and
 *      builds SIP-12 mint orders, allow list proofs and signed mints for
 *      `token`. The offer of a 1155 mint order is one ERC-1155 item of the
 *      token per token id, with the quantity as the amount.
 */
abstract contract SeaDrop1155Test is SeaDropTest {
    /// @dev Inputs of a mint order. `mintTypeData` is appended to the
    ///      context after the fee recipient and minter: the public drop
    ///      index for a public mint, or the substandard's mint params.
    struct MintOrder {
        address token;
        uint256[] tokenIds;
        uint256[] quantities;
        address feeRecipient;
        uint256 feeBps;
        uint256 price;
        address paymentToken;
        address minter;
        uint8 mintType;
        bytes mintTypeData;
    }

    bytes32 internal constant _SIGNED_MINT_TYPEHASH = keccak256(
        "SignedMint(address minter,address feeRecipient,MintParams mintParams,"
        "uint256 salt)MintParams(uint256 startPrice,uint256 endPrice,"
        "uint256 startTime,uint256 endTime,address paymentToken,"
        "uint256 fromTokenId,uint256 toTokenId,"
        "uint256 maxTotalMintableByWallet,"
        "uint256 maxTotalMintableByWalletPerToken,"
        "uint256 maxTokenSupplyForStage,uint256 dropStageIndex,"
        "uint256 feeBps,bool restrictFeeRecipients)"
    );
    bytes32 internal constant _MINT_PARAMS_TYPEHASH = keccak256(
        "MintParams(uint256 startPrice,uint256 endPrice,uint256 startTime,"
        "uint256 endTime,address paymentToken,uint256 fromTokenId,"
        "uint256 toTokenId,uint256 maxTotalMintableByWallet,"
        "uint256 maxTotalMintableByWalletPerToken,"
        "uint256 maxTokenSupplyForStage,uint256 dropStageIndex,"
        "uint256 feeBps,bool restrictFeeRecipients)"
    );
    bytes32 internal constant _NAME_HASH = keccak256("ERC1155SeaDrop");

    /// @dev The SeaDrop token under test.
    ERC1155SeaDrop token;

    /// @dev The configurer contract.
    ERC1155SeaDropConfigurer configurer;

    function setUp() public virtual override {
        super.setUp();
        configurer = new ERC1155SeaDropConfigurer();
    }

    /// @dev Deploy an ERC1155SeaDrop owned by the caller (or a pranked
    ///      sender).
    function _deployToken() internal returns (ERC1155SeaDrop) {
        return new ERC1155SeaDrop(
            address(configurer), allowedSeaport, "Test1155", "T1155"
        );
    }

    /// @dev `token` cast to its SeaDrop interface.
    function _seaDrop() internal view returns (IERC1155SeaDrop) {
        return IERC1155SeaDrop(address(token));
    }

    /**
     * Mint orders
     */
    function _publicMint(
        address tokenAddress,
        uint256[] memory tokenIds,
        uint256[] memory quantities,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter,
        uint8 publicDropIndex
    ) internal pure returns (MintOrder memory) {
        return MintOrder({
            token: tokenAddress,
            tokenIds: tokenIds,
            quantities: quantities,
            feeRecipient: feeRecipient,
            feeBps: feeBps,
            price: price,
            paymentToken: address(0),
            minter: minter,
            mintType: MINT_TYPE_PUBLIC,
            mintTypeData: abi.encodePacked(publicDropIndex)
        });
    }

    /// @dev A public mint order for a single token id.
    function _publicMintOrder(
        address tokenAddress,
        uint256 tokenId,
        uint256 quantity,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter,
        uint8 publicDropIndex
    ) internal view returns (AdvancedOrder memory order, uint256 value) {
        return _createMintOrder(
            _publicMint(
                tokenAddress,
                _uints(tokenId),
                _uints(quantity),
                feeRecipient,
                feeBps,
                price,
                minter,
                publicDropIndex
            )
        );
    }

    function _allowListMintOrder(
        address tokenAddress,
        uint256[] memory tokenIds,
        uint256[] memory quantities,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter,
        MintParams memory mintParams,
        bytes32[] memory proof
    ) internal view returns (AdvancedOrder memory, uint256) {
        MintOrder memory m = _publicMint(
            tokenAddress,
            tokenIds,
            quantities,
            feeRecipient,
            feeBps,
            price,
            minter,
            0
        );
        m.mintType = MINT_TYPE_ALLOW_LIST;
        m.mintTypeData =
            bytes.concat(abi.encode(mintParams), abi.encodePacked(proof));
        return _createMintOrder(m);
    }

    function _signedMintOrder(
        address tokenAddress,
        uint256[] memory tokenIds,
        uint256[] memory quantities,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter,
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature
    ) internal view returns (AdvancedOrder memory, uint256) {
        MintOrder memory m = _publicMint(
            tokenAddress,
            tokenIds,
            quantities,
            feeRecipient,
            feeBps,
            price,
            minter,
            0
        );
        m.mintType = MINT_TYPE_SIGNED;
        m.mintTypeData =
            bytes.concat(abi.encode(mintParams), bytes32(salt), signature);
        return _createMintOrder(m);
    }

    /// @dev Build the mint order and the native or ERC20 value to pay
    ///      (price * total quantity).
    function _createMintOrder(MintOrder memory m)
        internal
        view
        returns (AdvancedOrder memory order, uint256 value)
    {
        uint256 numItems = m.tokenIds.length;
        OfferItem[] memory offer = new OfferItem[](numItems);
        uint256 totalQuantity;
        for (uint256 i = 0; i < numItems; i++) {
            offer[i] = OfferItem({
                itemType: ItemType.ERC1155,
                token: m.token,
                identifierOrCriteria: m.tokenIds[i],
                startAmount: m.quantities[i],
                endAmount: m.quantities[i]
            });
            totalQuantity += m.quantities[i];
        }

        value = m.price * totalQuantity;
        order = _contractOrder(
            m.token,
            offer,
            _mintConsideration(
                m.token, m.feeRecipient, m.feeBps, value, m.paymentToken
            ),
            bytes.concat(
                bytes1(0x00), // SIP-6 version byte
                bytes1(m.mintType), // substandard version byte
                bytes20(m.feeRecipient),
                bytes20(m.minter),
                m.mintTypeData
            )
        );
    }

    /**
     * Allow list
     */
    function _allowListRootAndProof(
        address[] memory minters,
        MintParams memory mintParams,
        uint256 minterIndexForProof
    ) internal returns (bytes32 root, bytes32[] memory proof) {
        bytes32[] memory leaves = new bytes32[](minters.length);
        for (uint256 i = 0; i < minters.length; i++) {
            leaves[i] = keccak256(abi.encode(minters[i], mintParams));
        }
        return _merkleRootAndProof(leaves, minterIndexForProof);
    }

    /**
     * Signed mint
     */
    function _getDigest(
        address tokenAddress,
        address minter,
        address feeRecipient,
        MintParams memory mintParams,
        uint256 salt
    ) internal view returns (bytes32) {
        bytes32 mintParamsHashStruct = keccak256(
            bytes.concat(
                abi.encode(
                    _MINT_PARAMS_TYPEHASH,
                    mintParams.startPrice,
                    mintParams.endPrice,
                    mintParams.startTime,
                    mintParams.endTime,
                    mintParams.paymentToken,
                    mintParams.fromTokenId,
                    mintParams.toTokenId
                ),
                abi.encode(
                    mintParams.maxTotalMintableByWallet,
                    mintParams.maxTotalMintableByWalletPerToken,
                    mintParams.maxTokenSupplyForStage,
                    mintParams.dropStageIndex,
                    mintParams.feeBps,
                    mintParams.restrictFeeRecipients
                )
            )
        );
        return keccak256(
            bytes.concat(
                bytes2(0x1901),
                _domainSeparator(_NAME_HASH, tokenAddress),
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

    /// @dev Sign a mint with `signerName`'s key, returning the EIP-2098
    ///      compact signature and the signed digest.
    function _signMint(
        string memory signerName,
        address tokenAddress,
        address minter,
        address feeRecipient,
        MintParams memory mintParams,
        uint256 salt
    ) internal returns (bytes memory signature, bytes32 digest) {
        digest =
            _getDigest(tokenAddress, minter, feeRecipient, mintParams, salt);
        signature = _signDigest(signerName, digest);
    }

    /**
     * Minting setup
     */

    /// @dev Temporarily set a free public drop for `tokenId` at index 0,
    ///      mint `quantity` to `minter` through Seaport, then restore the
    ///      previous public drop.
    function _mintTokens(address minter, uint256 tokenId, uint256 quantity)
        internal
    {
        PublicDrop memory prevPublicDrop = _seaDrop().getPublicDrop(0);

        _seaDrop()
            .updatePublicDrop(
                PublicDrop({
                    startPrice: 0,
                    endPrice: 0,
                    startTime: uint40(vm.getBlockTimestamp() - 1000),
                    endTime: uint40(vm.getBlockTimestamp() + 5000),
                    paymentToken: address(0),
                    fromTokenId: uint24(tokenId),
                    toTokenId: uint24(tokenId),
                    maxTotalMintableByWallet: 1000,
                    maxTotalMintableByWalletPerToken: 1000,
                    feeBps: 0,
                    restrictFeeRecipients: false
                }),
                0
            );

        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            address(token),
            tokenId,
            quantity,
            address(0x1111111111111111111111111111111111111111),
            0,
            0,
            minter,
            0
        );
        _fulfill(order, minter, value);

        _seaDrop().updatePublicDrop(prevPublicDrop, 0);
    }
}

/**
 * @dev Fixture for the ERC1155SeaDropContractOfferer tests: the test
 *      contract (`owner`) deploys the token with max supply 5 for token id
 *      0, a public drop for token ids 0 to 10 at index 0, an allowed fee
 *      recipient and a single creator payout.
 */
abstract contract SeaDrop1155OffererFixture is SeaDrop1155Test {
    /// @dev An arbitrary allow list merkle root for configuration tests.
    bytes32 internal constant _ALLOW_LIST_MERKLE_ROOT =
        0x3333333333333333333333333333333333333333333333333333333333333333;

    address internal owner;
    address internal creator;
    address internal minter;
    uint256 internal minterPk;
    address internal feeRecipient;

    /// @dev The public drop configured in setUp at index 0.
    PublicDrop internal publicDrop;

    function setUp() public virtual override {
        super.setUp();

        owner = address(this);
        creator = makeAddr("creator");
        (minter, minterPk) = makeAddrAndKey("minter");
        feeRecipient = makeAddr("feeRecipient");

        vm.deal(minter, 100 ether);

        token = _deployToken();

        publicDrop = PublicDrop({
            startPrice: 0.1 ether,
            endPrice: 0.1 ether,
            startTime: uint40(vm.getBlockTimestamp() - 1000),
            endTime: uint40(vm.getBlockTimestamp() + 1000),
            fromTokenId: 0,
            toTokenId: 10,
            paymentToken: address(0),
            maxTotalMintableByWallet: 10,
            maxTotalMintableByWalletPerToken: 9,
            feeBps: 1000,
            restrictFeeRecipients: true
        });

        token.setMaxSupply(0, 5);
        _seaDrop().updatePublicDrop(publicDrop, 0);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);
        _setSingleCreatorPayout(address(token), creator);
    }
}
