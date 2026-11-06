// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721Test } from "./utils/SeaDrop721Test.sol";

import { SeaDrop721MintHelpers } from "./utils/SeaDrop721MintHelpers.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { MintParams, PublicDrop } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { RevertedRecipient } from "seadrop/test/RevertedRecipient.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

import { IERC721A } from "ERC721A/IERC721A.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

contract ERC721SeaDropTest is SeaDrop721Test {
    FuzzArgs empty;

    uint256 feeBps = 500;

    struct FuzzArgs {
        address feeRecipient;
        address creator;
    }

    struct Context {
        FuzzArgs args;
    }

    modifier fuzzConstraints(FuzzArgs memory args) {
        // Assume feeRecipient and creator are not the zero address.
        vm.assume(args.feeRecipient != address(0));
        vm.assume(args.creator != address(0));

        // Assume creator has zero balance.
        vm.assume(args.creator.balance == 0);

        // Assume feeRecipient is not the creator.
        vm.assume(args.feeRecipient != args.creator);

        // Assume feeRecipient and creator are EOAs.
        vm.assume(args.feeRecipient.code.length == 0);
        vm.assume(args.creator.code.length == 0);

        assumeNoPrecompiles(args.feeRecipient);
        assumeNoPrecompiles(args.creator);

        _;
    }

    function setUp() public override {
        super.setUp();
        token = new ERC721SeaDrop(address(configurer), allowedSeaport, "", "");
    }

    function testMintPublic(Context memory context)
        public
        fuzzConstraints(context.args)
    {
        address feeRecipient = context.args.feeRecipient;
        IERC721SeaDrop(address(token))
            .updateAllowedFeeRecipient(feeRecipient, true);
        token.setMaxSupply(10);
        setSingleCreatorPayout(context.args.creator);

        PublicDrop memory publicDrop = PublicDrop({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + 500),
            paymentToken: address(0),
            maxTotalMintableByWallet: 5,
            feeBps: uint16(feeBps),
            restrictFeeRecipients: true
        });
        IERC721SeaDrop(address(token)).updatePublicDrop(publicDrop);

        addSeaDropOfferItem(3); // 3 mints
        addSeaDropConsiderationItems(feeRecipient, feeBps, 3 ether);
        configureSeaDropOrderParameters();

        address minter = address(this);
        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x00), // substandard version byte: public mint
            bytes20(feeRecipient),
            bytes20(minter)
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraData
        });

        vm.deal(address(this), 10 ether);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(address(this), 0);

        consideration.fulfillAdvancedOrder{ value: 3 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        assertEq(token.ownerOf(3), minter);
        assertEq(context.args.creator.balance, 3 ether * 0.95);

        // Minting any more should exceed maxTotalMintableByWallet
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(token))) << 96)
                    + consideration.getContractOffererNonce(address(token))
            )
        );
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testMintAllowList(Context memory context)
        public
        fuzzConstraints(context.args)
    {
        address feeRecipient = context.args.feeRecipient;
        IERC721SeaDrop(address(token))
            .updateAllowedFeeRecipient(feeRecipient, true);
        token.setMaxSupply(10);
        setSingleCreatorPayout(context.args.creator);

        MintParams memory mintParams = MintParams({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp) + 500,
            paymentToken: address(0),
            maxTotalMintableByWallet: 5,
            maxTokenSupplyForStage: 1000,
            dropStageIndex: 2,
            feeBps: feeBps,
            restrictFeeRecipients: false
        });

        address[] memory allowList = new address[](2);
        allowList[0] = address(this);
        allowList[1] = makeAddr("fred");
        bytes32[] memory proof =
            setAllowListMerkleRootAndReturnProof(allowList, 0, mintParams);

        addSeaDropOfferItem(3); // 3 mints
        addSeaDropConsiderationItems(feeRecipient, feeBps, 3 ether);
        configureSeaDropOrderParameters();

        address minter = address(this);
        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x01), // substandard version byte: allow list mint
            bytes20(feeRecipient),
            bytes20(minter),
            abi.encode(mintParams),
            abi.encodePacked(proof)
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraData
        });

        vm.deal(address(this), 10 ether);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(address(this), 2);

        consideration.fulfillAdvancedOrder{ value: 3 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        assertEq(token.ownerOf(3), minter);
        assertEq(context.args.creator.balance, 3 ether * 0.95);

        // Minting any more should exceed maxTotalMintableByWallet
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(token))) << 96)
                    + consideration.getContractOffererNonce(address(token))
            )
        );
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testMintSigned(Context memory context)
        public
        fuzzConstraints(context.args)
    {
        address feeRecipient = context.args.feeRecipient;
        IERC721SeaDrop(address(token))
            .updateAllowedFeeRecipient(feeRecipient, true);
        token.setMaxSupply(10);
        setSingleCreatorPayout(context.args.creator);

        address signer = makeAddr("signer-doug");
        IERC721SeaDrop(address(token)).updateSigner(signer, true);

        MintParams memory mintParams = MintParams({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp) + 500,
            paymentToken: address(0),
            maxTotalMintableByWallet: 4,
            maxTokenSupplyForStage: 1000,
            dropStageIndex: 3,
            feeBps: feeBps,
            restrictFeeRecipients: true
        });

        // Get the signature.
        address minter = address(this);
        uint256 salt = 123;
        bytes memory signature = getSignedMint(
            "signer-doug",
            address(token),
            minter,
            feeRecipient,
            mintParams,
            salt,
            true
        );

        addSeaDropOfferItem(2); // 2 mints
        addSeaDropConsiderationItems(feeRecipient, feeBps, 3 ether);
        configureSeaDropOrderParameters();

        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x02), // substandard version byte: signed mint
            bytes20(feeRecipient),
            bytes20(minter),
            abi.encode(mintParams),
            bytes32(salt),
            signature
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraData
        });

        vm.deal(address(this), 10 ether);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(address(this), 3);

        consideration.fulfillAdvancedOrder{ value: 2 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        assertEq(context.args.creator.balance, 2 ether * 0.95);

        // Minting more should fail as the digest is used
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(token))) << 96)
                    + consideration.getContractOffererNonce(address(token))
            )
        );
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        // Minting any more should exceed maxTotalMintableByWallet
        salt = 456;
        signature = getSignedMint(
            "signer-doug",
            address(token),
            minter,
            feeRecipient,
            mintParams,
            salt,
            true
        );
        extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x02), // substandard version byte: signed mint
            bytes20(feeRecipient),
            bytes20(minter),
            abi.encode(mintParams),
            bytes32(salt),
            signature
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(token))) << 96)
                    + consideration.getContractOffererNonce(address(token))
            )
        );
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }
}

/**
 * @dev Port of test/ERC721SeaDrop.spec.ts.
 *      The test contract deploys the token, so it plays the spec's `owner`.
 */
contract ERC721SeaDropTransferBurnWithdrawTest is SeaDrop721MintHelpers {
    address creator = makeAddr("creator");
    address minter = makeAddr("minter");

    function setUp() public override {
        super.setUp();
        token = new ERC721SeaDrop(
            address(configurer),
            allowedSeaport,
            "Test721",
            "T721"
        );
        vm.deal(minter, 100 ether);
        vm.deal(creator, 100 ether);
    }

    /// @dev "Should be able to transfer successfully"
    function testTransfer() public {
        token.setMaxSupply(5);
        _mintTokens(minter, 5);

        vm.startPrank(minter);
        token.transferFrom(minter, creator, 1);
        token.safeTransferFrom(minter, creator, 2);
        token.safeTransferFrom(minter, creator, 3, hex"dadb0d");
        vm.stopPrank();
        assertEq(token.balanceOf(creator), 3);

        vm.startPrank(minter);
        token.setApprovalForAll(creator, true);
        token.approve(creator, 4);
        vm.stopPrank();

        // Should auto-approve the conduit to transfer.
        assertTrue(token.isApprovedForAll(creator, OPENSEA_CONDUIT));
        assertTrue(token.isApprovedForAll(minter, OPENSEA_CONDUIT));
        vm.startPrank(OPENSEA_CONDUIT);
        token.transferFrom(creator, minter, 1);
        token.safeTransferFrom(creator, minter, 2);
        token.safeTransferFrom(creator, minter, 3, hex"dadb0d");
        vm.stopPrank();

        // Should not allow a non-approved address to transfer.
        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        token.transferFrom(minter, creator, 1);
        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        token.safeTransferFrom(minter, creator, 2);
        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        token.safeTransferFrom(minter, creator, 3, hex"dadb0d");
    }

    /// @dev "Should only let the token owner or approved burn their token"
    function testBurn() public {
        // Mint 3 tokens to the minter.
        token.setMaxSupply(3);
        _mintTokens(minter, 3);

        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        assertEq(token.ownerOf(3), minter);
        assertEq(token.totalSupply(), 3);

        // Only the owner or approved of the minted token should be able to
        // burn it.
        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        token.burn(1);
        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        vm.prank(creator);
        token.burn(1);
        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        vm.prank(creator);
        token.burn(2);
        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        vm.prank(creator);
        token.burn(3);

        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        assertEq(token.ownerOf(3), minter);
        assertEq(token.totalSupply(), 3);

        vm.prank(minter);
        token.burn(1);

        assertEq(token.totalSupply(), 2);

        vm.prank(minter);
        token.setApprovalForAll(creator, true);
        vm.prank(creator);
        token.burn(2);

        assertEq(token.totalSupply(), 1);

        vm.prank(minter);
        token.setApprovalForAll(creator, false);
        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        vm.prank(creator);
        token.burn(3);

        vm.prank(minter);
        token.approve(address(this), 3);
        token.burn(3);

        assertEq(token.totalSupply(), 0);

        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        token.ownerOf(1);
        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        token.ownerOf(2);
        assertEq(token.totalSupply(), 0);

        // Should not be able to burn a nonexistent token.
        for (uint256 tokenId = 0; tokenId <= 3; tokenId++) {
            vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
            vm.prank(minter);
            token.burn(tokenId);
        }
    }

    /// @dev "Should allow the contract owner to withdraw all funds in the
    ///      contract"
    function testWithdraw() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(minter);
        token.withdraw();

        vm.expectRevert(NoBalanceToWithdraw.selector);
        token.withdraw();

        // Send some balance to the contract.
        token.setMaxSupply(1);
        _mintTokens(minter, 1);
        vm.prank(minter);
        token.approve{ value: 100 }(address(this), 1);

        assertEq(address(token).balance, 100);

        // Forge runs with a zero gas price, so the owner has no tx cost.
        uint256 ownerBalanceBefore = address(this).balance;
        token.withdraw();
        assertEq(address(this).balance, ownerBalanceBefore + 100);

        assertEq(address(token).balance, 0);

        // Owner storage slot from solady's Ownable.sol.
        bytes32 ownerStorageSlot = bytes32(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff74873927
        );

        RevertedRecipient revertedRecipient = new RevertedRecipient();
        // The token reverts with no data (its fallback is not payable), and
        // RevertedRecipient reverts with a custom error. withdraw() bubbles
        // up the revert data.
        address[2] memory ownerAddresses = [
            address(token),
            address(revertedRecipient)
        ];
        bytes[2] memory expectedRevertData = [
            bytes(""),
            abi.encodeWithSelector(RevertedRecipient.CannotAcceptEther.selector)
        ];

        for (uint256 i = 0; i < ownerAddresses.length; i++) {
            vm.store(
                address(token),
                ownerStorageSlot,
                bytes32(uint256(uint160(ownerAddresses[i])))
            );
            assertEq(token.owner(), ownerAddresses[i]);

            vm.prank(minter);
            token.approve{ value: 100 }(address(this), 1);

            vm.prank(ownerAddresses[i]);
            (bool success, bytes memory returnData) = address(token).call(
                abi.encodeCall(ERC721SeaDrop.withdraw, ())
            );
            assertFalse(success);
            assertEq(returnData, expectedRevertData[i]);
        }
    }
}
