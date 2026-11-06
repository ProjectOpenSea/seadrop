// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDropTest } from "./SeaDropTest.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    ERC721SeaDropConfigurer
} from "seadrop/lib/ERC721SeaDropConfigurer.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { MintParams, PublicDrop } from "seadrop/lib/ERC721SeaDropStructs.sol";

import {
    AdvancedOrder,
    OfferItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

/**
 * @dev Base for the ERC721SeaDrop Forge tests: deploys the configurer and
 *      builds SIP-12 mint orders, allow list proofs and signed mints for
 *      `token`. The offer of a 721 mint order is a single ERC-1155 item of
 *      the token with identifier 0 and the quantity as the amount.
 */
abstract contract SeaDrop721Test is SeaDropTest {
    /// @dev Inputs of a mint order. Fields a substandard doesn't use are
    ///      ignored.
    struct MintOrder {
        address token;
        uint256 identifier;
        uint256 quantity;
        address feeRecipient;
        uint256 feeBps;
        uint256 price;
        address paymentToken;
        address minter;
        uint8 mintType;
        MintParams mintParams;
        bytes32[] proof;
        uint256 salt;
        bytes signature;
    }

    bytes32 internal constant _SIGNED_MINT_TYPEHASH = keccak256(
        "SignedMint(address minter,address feeRecipient,MintParams mintParams,"
        "uint256 salt)MintParams(uint256 startPrice,uint256 endPrice,"
        "uint256 startTime,uint256 endTime,address paymentToken,"
        "uint256 maxTotalMintableByWallet,uint256 maxTokenSupplyForStage,"
        "uint256 dropStageIndex,uint256 feeBps,bool restrictFeeRecipients)"
    );
    bytes32 internal constant _MINT_PARAMS_TYPEHASH = keccak256(
        "MintParams(uint256 startPrice,uint256 endPrice,uint256 startTime,"
        "uint256 endTime,address paymentToken,"
        "uint256 maxTotalMintableByWallet,uint256 maxTokenSupplyForStage,"
        "uint256 dropStageIndex,uint256 feeBps,bool restrictFeeRecipients)"
    );
    bytes32 internal constant _NAME_HASH = keccak256("ERC721SeaDrop");

    /// @dev The SeaDrop token under test.
    ERC721SeaDrop token;

    /// @dev The configurer contract.
    ERC721SeaDropConfigurer configurer;

    function setUp() public virtual override {
        super.setUp();
        configurer = new ERC721SeaDropConfigurer();
    }

    /// @dev Deploy an ERC721SeaDrop owned by the caller (or a pranked
    ///      sender).
    function _deployToken() internal returns (ERC721SeaDrop) {
        return new ERC721SeaDrop(
            address(configurer), allowedSeaport, "Test721", "T721"
        );
    }

    /// @dev `token` cast to its SeaDrop interface.
    function _seaDrop() internal view returns (IERC721SeaDrop) {
        return IERC721SeaDrop(address(token));
    }

    /**
     * Mint orders
     */
    function _publicMint(
        address tokenAddress,
        uint256 quantity,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter
    ) internal pure returns (MintOrder memory m) {
        m.token = tokenAddress;
        m.quantity = quantity;
        m.feeRecipient = feeRecipient;
        m.feeBps = feeBps;
        m.price = price;
        m.minter = minter;
        m.mintType = MINT_TYPE_PUBLIC;
    }

    function _publicMintOrder(
        address tokenAddress,
        uint256 quantity,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter
    ) internal view returns (AdvancedOrder memory order, uint256 value) {
        return _createMintOrder(
            _publicMint(
                tokenAddress, quantity, feeRecipient, feeBps, price, minter
            )
        );
    }

    function _allowListMintOrder(
        address tokenAddress,
        uint256 quantity,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter,
        MintParams memory mintParams,
        bytes32[] memory proof
    ) internal view returns (AdvancedOrder memory order, uint256 value) {
        MintOrder memory m = _publicMint(
            tokenAddress, quantity, feeRecipient, feeBps, price, minter
        );
        m.mintType = MINT_TYPE_ALLOW_LIST;
        m.mintParams = mintParams;
        m.proof = proof;
        return _createMintOrder(m);
    }

    function _signedMintOrder(
        address tokenAddress,
        uint256 quantity,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter,
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature
    ) internal view returns (AdvancedOrder memory order, uint256 value) {
        MintOrder memory m = _publicMint(
            tokenAddress, quantity, feeRecipient, feeBps, price, minter
        );
        m.mintType = MINT_TYPE_SIGNED;
        m.mintParams = mintParams;
        m.salt = salt;
        m.signature = signature;
        return _createMintOrder(m);
    }

    /// @dev Build the mint order and the native or ERC20 value to pay
    ///      (price * quantity).
    function _createMintOrder(MintOrder memory m)
        internal
        view
        returns (AdvancedOrder memory order, uint256 value)
    {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC1155,
            token: m.token,
            identifierOrCriteria: m.identifier,
            startAmount: m.quantity,
            endAmount: m.quantity
        });

        value = m.price * m.quantity;
        order = _contractOrder(
            m.token,
            offer,
            _mintConsideration(
                m.token, m.feeRecipient, m.feeBps, value, m.paymentToken
            ),
            _mintExtraData(m)
        );
    }

    /// @dev SIP-6 version byte, substandard byte, fee recipient and minter,
    ///      then the substandard's own data.
    function _mintExtraData(MintOrder memory m)
        internal
        pure
        returns (bytes memory extraData)
    {
        extraData = bytes.concat(
            bytes1(0x00),
            bytes1(m.mintType),
            bytes20(m.feeRecipient),
            bytes20(m.minter)
        );
        if (m.mintType == MINT_TYPE_ALLOW_LIST) {
            extraData = bytes.concat(
                extraData, abi.encode(m.mintParams), abi.encodePacked(m.proof)
            );
        } else if (m.mintType == MINT_TYPE_SIGNED) {
            extraData = bytes.concat(
                extraData,
                abi.encode(m.mintParams),
                bytes32(m.salt),
                m.signature
            );
        }
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

    function _allowListRootAndProof(
        address minter,
        MintParams memory mintParams
    ) internal returns (bytes32 root, bytes32[] memory proof) {
        return _allowListRootAndProof(_addrs(minter), mintParams, 0);
    }

    /// @dev A copy of mint params, since assigning a memory struct aliases
    ///      it.
    function _copyMintParams(MintParams memory mintParams)
        internal
        pure
        returns (MintParams memory)
    {
        return abi.decode(abi.encode(mintParams), (MintParams));
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
            abi.encode(
                _MINT_PARAMS_TYPEHASH,
                mintParams.startPrice,
                mintParams.endPrice,
                mintParams.startTime,
                mintParams.endTime,
                mintParams.paymentToken,
                mintParams.maxTotalMintableByWallet,
                mintParams.maxTokenSupplyForStage,
                mintParams.dropStageIndex,
                mintParams.feeBps,
                mintParams.restrictFeeRecipients
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

    /// @dev Temporarily set a free public drop on `token`, mint `quantity`
    ///      to `minter` through Seaport, then restore the previous public
    ///      drop.
    function _mintTokens(address minter, uint256 quantity) internal {
        PublicDrop memory prevPublicDrop = _seaDrop().getPublicDrop();

        _seaDrop()
            .updatePublicDrop(
                PublicDrop({
                    startPrice: 0,
                    endPrice: 0,
                    startTime: uint40(vm.getBlockTimestamp() - 1000),
                    endTime: uint40(vm.getBlockTimestamp() + 5000),
                    paymentToken: address(0),
                    maxTotalMintableByWallet: 1000,
                    feeBps: 0,
                    restrictFeeRecipients: false
                })
            );

        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            address(token),
            quantity,
            address(0x1111111111111111111111111111111111111111),
            0,
            0,
            minter
        );
        _fulfill(order, minter, value);

        _seaDrop().updatePublicDrop(prevPublicDrop);
    }
}

/**
 * @dev Fixture for the ERC721SeaDropContractOfferer tests: `owner` deploys
 *      the token with max supply 5, a public drop, an allowed fee recipient
 *      and a single creator payout.
 */
abstract contract SeaDrop721OffererFixture is SeaDrop721Test {
    /// @dev An arbitrary allow list merkle root for configuration tests.
    bytes32 internal constant _ALLOW_LIST_MERKLE_ROOT =
        0x3333333333333333333333333333333333333333333333333333333333333333;

    address internal owner;
    address internal creator;
    address internal minter;
    uint256 internal minterPk;
    address internal feeRecipient;

    /// @dev The public drop configured in setUp.
    PublicDrop internal publicDrop;

    function setUp() public virtual override {
        super.setUp();

        owner = makeAddr("owner");
        creator = makeAddr("creator");
        (minter, minterPk) = makeAddrAndKey("minter");
        feeRecipient = makeAddr("feeRecipient");

        vm.deal(owner, 100 ether);
        vm.deal(minter, 100 ether);
        vm.deal(creator, 100 ether);
        vm.deal(feeRecipient, 100 ether);

        vm.prank(owner);
        token = _deployToken();

        publicDrop = PublicDrop({
            startPrice: 0.1 ether,
            endPrice: 0.1 ether,
            startTime: uint40(vm.getBlockTimestamp() - 1000),
            endTime: uint40(vm.getBlockTimestamp() + 1000),
            paymentToken: address(0),
            maxTotalMintableByWallet: 10,
            feeBps: 1000,
            restrictFeeRecipients: true
        });

        vm.startPrank(owner);
        token.setMaxSupply(5);
        _seaDrop().updatePublicDrop(publicDrop);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);
        _seaDrop().updateCreatorPayouts(_payouts(creator, 10_000));
        vm.stopPrank();
    }
}
