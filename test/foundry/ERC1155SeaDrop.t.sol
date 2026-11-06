// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./utils/SeaDrop1155Test.sol";

import { ERC1155 } from "solady/src/tokens/ERC1155.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "seadrop/lib/ERC1155SeaDropErrorsAndEvents.sol";

import { MintParams, PublicDrop } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @dev Fuzzed end-to-end mints through Seaport for each SIP-12 substandard,
 *      with the test contract as the minter.
 */
contract ERC1155SeaDropTest is SeaDrop1155Test {
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

        assumeNotPrecompile(args.feeRecipient);
        assumeNotPrecompile(args.creator);

        _;
    }

    function setUp() public override {
        super.setUp();
        token = _deployToken();
        vm.deal(address(this), 10 ether);
    }

    function testMintPublic(Context memory context)
        public
        fuzzConstraints(context.args)
    {
        address feeRecipient = context.args.feeRecipient;
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);
        token.setMaxSupply(1, 10);
        token.setMaxSupply(3, 10);
        _setSingleCreatorPayout(address(token), context.args.creator);

        PublicDrop memory publicDrop = PublicDrop({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + 500),
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 3,
            maxTotalMintableByWallet: 6,
            maxTotalMintableByWalletPerToken: 5,
            feeBps: uint16(feeBps),
            restrictFeeRecipients: true
        });
        _seaDrop().updatePublicDrop(publicDrop, 0);

        // Token id 1 x3 and token id 3 x1.
        address minter = address(this);
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            _publicMint(
                address(token),
                _uints(1, 3),
                _uints(3, 1),
                feeRecipient,
                feeBps,
                1 ether,
                minter,
                0
            )
        );
        assertEq(value, 4 ether);

        _fulfillAndExpectMint(order, minter, value, 0);

        assertEq(token.balanceOf(minter, 1), 3);
        assertEq(token.balanceOf(minter, 3), 1);
        assertEq(context.args.creator.balance, 4 ether * 0.95);

        // Minting the same again exceeds maxTotalMintableByWalletPerToken for
        // token id 1: 3 minted of it plus 3 (not the wallet's 4 overall).
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWalletForTokenId
                    .selector,
                1,
                6,
                5
            )
        );
    }

    function testMintAllowList(Context memory context)
        public
        fuzzConstraints(context.args)
    {
        address feeRecipient = context.args.feeRecipient;
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);
        token.setMaxSupply(1, 10);
        _setSingleCreatorPayout(address(token), context.args.creator);

        MintParams memory mintParams = MintParams({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp) + 500,
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 1,
            maxTotalMintableByWallet: 6,
            maxTotalMintableByWalletPerToken: 5,
            maxTokenSupplyForStage: 1000,
            dropStageIndex: 2,
            feeBps: feeBps,
            restrictFeeRecipients: false
        });

        address minter = address(this);
        (bytes32 root, bytes32[] memory proof) = _allowListRootAndProof(
            _addrs(minter, makeAddr("fred")), mintParams, 0
        );
        _updateAllowList(address(token), root);

        (AdvancedOrder memory order, uint256 value) = _allowListMintOrder(
            address(token),
            _uints(1),
            _uints(3),
            feeRecipient,
            feeBps,
            1 ether,
            minter,
            mintParams,
            proof
        );

        _fulfillAndExpectMint(order, minter, value, 2);

        assertEq(token.balanceOf(minter, 1), 3);
        assertEq(context.args.creator.balance, 3 ether * 0.95);

        // Minting the same again exceeds maxTotalMintableByWalletPerToken.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWalletForTokenId
                    .selector,
                1,
                6,
                5
            )
        );
    }

    function testMintSigned(Context memory context)
        public
        fuzzConstraints(context.args)
    {
        address feeRecipient = context.args.feeRecipient;
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);
        token.setMaxSupply(1, 10);
        _setSingleCreatorPayout(address(token), context.args.creator);

        _seaDrop().updateSigner(makeAddr("signer-doug"), true);

        MintParams memory mintParams = MintParams({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp) + 500,
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 1,
            maxTotalMintableByWallet: 4,
            maxTotalMintableByWalletPerToken: 4,
            maxTokenSupplyForStage: 1000,
            dropStageIndex: 3,
            feeBps: feeBps,
            restrictFeeRecipients: true
        });

        address minter = address(this);
        (bytes memory signature,) = _signMint(
            "signer-doug", address(token), minter, feeRecipient, mintParams, 123
        );
        (AdvancedOrder memory order, uint256 value) = _signedMintOrder(
            address(token),
            _uints(1),
            _uints(2),
            feeRecipient,
            feeBps,
            1 ether,
            minter,
            mintParams,
            123,
            signature
        );

        _fulfillAndExpectMint(order, minter, value, 3);

        assertEq(token.balanceOf(minter, 1), 2);
        assertEq(context.args.creator.balance, 2 ether * 0.95);

        // Minting again with the same signature fails as the digest is used.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(SignatureAlreadyUsed.selector)
        );

        // A fresh signature can't mint past maxTotalMintableByWalletPerToken.
        (signature,) = _signMint(
            "signer-doug", address(token), minter, feeRecipient, mintParams, 456
        );
        (order, value) = _signedMintOrder(
            address(token),
            _uints(1),
            _uints(3),
            feeRecipient,
            feeBps,
            1 ether,
            minter,
            mintParams,
            456,
            signature
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWalletForTokenId
                    .selector,
                1,
                5,
                4
            )
        );
    }

    /// @dev An order with an empty minimumReceived can't mint.
    function testPOCEmptyMinimumReceived() public {
        address feeRecipient = address(0xfee);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);
        token.setMaxSupply(1, 10);
        token.setMaxSupply(3, 10);
        _setSingleCreatorPayout(address(token), address(0xc1ea101));

        // A free mint.
        PublicDrop memory publicDrop = PublicDrop({
            startPrice: 0 ether,
            endPrice: 0 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + 500),
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 3,
            maxTotalMintableByWallet: 6,
            maxTotalMintableByWalletPerToken: 5,
            feeBps: uint16(feeBps),
            restrictFeeRecipients: true
        });
        _seaDrop().updatePublicDrop(publicDrop, 0);

        (AdvancedOrder memory order,) = _createMintOrder(
            _publicMint(
                address(token),
                new uint256[](0),
                new uint256[](0),
                feeRecipient,
                feeBps,
                0,
                address(this),
                0
            )
        );
        assertEq(order.parameters.offer.length, 0);

        _expectInvalidContractOrder(address(token));
        _fulfill(order, address(this), 0);
    }
}

/**
 * @dev Transfers and burns of minted tokens.
 */
contract ERC1155SeaDropTransferAndBurnTest is SeaDrop1155Test {
    address owner;
    address creator;
    address minter;

    function setUp() public override {
        super.setUp();
        token = _deployToken();
        owner = address(this);
        creator = makeAddr("creator");
        minter = makeAddr("minter");
    }

    function testTransfer() public {
        token.setMaxSupply(0, 5);
        _mintTokens(minter, 0, 5);

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidCallerOnlyAllowedSeaport.selector, minter
            )
        );
        token.safeTransferFrom(address(token), creator, 0, 1, "");

        vm.prank(minter);
        token.safeTransferFrom(minter, creator, 0, 1, "");

        vm.prank(minter);
        token.setApprovalForAll(creator, true);
        vm.prank(creator);
        token.safeBatchTransferFrom(minter, creator, _uints(0), _uints(2), "");

        assertEq(token.balanceOf(creator, 0), 3);
        assertEq(token.balanceOf(minter, 0), 2);

        // Should auto-approve the conduit to transfer.
        assertTrue(token.isApprovedForAll(creator, OPENSEA_CONDUIT));
        assertTrue(token.isApprovedForAll(minter, OPENSEA_CONDUIT));
        vm.prank(OPENSEA_CONDUIT);
        token.safeTransferFrom(creator, minter, 0, 1, "");
        vm.prank(OPENSEA_CONDUIT);
        token.safeBatchTransferFrom(
            creator, minter, _uints(0), _uints(1), hex"dadb0d"
        );

        // Should not allow a non-approved address to transfer.
        vm.prank(owner);
        vm.expectRevert(ERC1155.NotOwnerNorApproved.selector);
        token.safeTransferFrom(minter, creator, 0, 1, "");
        vm.prank(owner);
        vm.expectRevert(ERC1155.NotOwnerNorApproved.selector);
        token.safeBatchTransferFrom(
            minter, creator, _uints(0), _uints(1), hex"dadb0d"
        );
    }

    function testOnlyOwnerOrApprovedCanBurn() public {
        uint256 tokenId = 2;
        assertEq(token.balanceOf(minter, tokenId), 0);
        assertEq(token.totalSupply(tokenId), 0);
        assertEq(token.maxSupply(tokenId), 0);

        // Mint 6 tokens to the minter.
        token.setMaxSupply(tokenId, 6);
        _mintTokens(minter, tokenId, 6);

        assertEq(token.balanceOf(minter, tokenId), 6);
        assertEq(token.totalSupply(tokenId), 6);
        assertEq(token.maxSupply(tokenId), 6);

        // Only the owner or approved of the minted token should be able to
        // burn it.
        vm.prank(owner);
        vm.expectRevert(ERC1155.NotOwnerNorApproved.selector);
        token.burn(minter, tokenId, 1);
        vm.prank(creator);
        vm.expectRevert(ERC1155.NotOwnerNorApproved.selector);
        token.batchBurn(minter, _uints(tokenId), _uints(2));

        assertEq(token.balanceOf(minter, tokenId), 6);
        assertEq(token.totalSupply(tokenId), 6);

        vm.prank(minter);
        token.burn(minter, tokenId, 1);

        assertEq(token.totalSupply(tokenId), 5);

        vm.prank(minter);
        token.setApprovalForAll(creator, true);
        vm.prank(creator);
        token.burn(minter, tokenId, 1);

        assertEq(token.totalSupply(tokenId), 4);

        vm.prank(minter);
        token.setApprovalForAll(creator, false);
        vm.prank(creator);
        vm.expectRevert(ERC1155.NotOwnerNorApproved.selector);
        token.burn(minter, tokenId, 1);

        vm.prank(minter);
        token.burn(minter, tokenId, 1);
        assertEq(token.balanceOf(minter, tokenId), 3);
        assertEq(token.totalSupply(tokenId), 3);

        vm.prank(minter);
        vm.expectRevert(ERC1155.InsufficientBalance.selector);
        token.burn(minter, tokenId, 4);

        // Should not be able to burn a nonexistent token.
        uint256[4] memory nonexistent = [uint256(20), 15, 29, 31];
        for (uint256 i = 0; i < nonexistent.length; i++) {
            vm.prank(minter);
            vm.expectRevert(ERC1155.InsufficientBalance.selector);
            token.burn(minter, nonexistent[i], 1);
            vm.prank(minter);
            vm.expectRevert(ERC1155.InsufficientBalance.selector);
            token.batchBurn(minter, _uints(nonexistent[i]), _uints(1));
        }

        // Should revert if trying to burn more than the balance.
        vm.prank(minter);
        vm.expectRevert(ERC1155.InsufficientBalance.selector);
        token.batchBurn(minter, _uints(0, tokenId), _uints(1, 1));

        vm.prank(minter);
        token.batchBurn(minter, _uints(tokenId), _uints(1));
        assertEq(token.balanceOf(minter, tokenId), 2);
        assertEq(token.totalSupply(tokenId), 2);

        vm.prank(minter);
        token.batchBurn(minter, _uints(tokenId), _uints(2));
        assertEq(token.balanceOf(minter, tokenId), 0);
        assertEq(token.totalSupply(tokenId), 0);
    }
}
