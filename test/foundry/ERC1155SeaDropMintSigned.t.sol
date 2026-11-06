// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155MintHelpers } from "./utils/SeaDrop1155MintHelpers.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "seadrop/lib/ERC1155SeaDropErrorsAndEvents.sol";

import { MintParams } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import {
    IDelegationRegistry
} from "seadrop/interfaces/IDelegationRegistry.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

import { ECDSA } from "solady/src/utils/ECDSA.sol";

/**
 * @dev Port of test/ERC1155SeaDrop-mintSigned.spec.ts.
 *
 *      The spec draws a random 32-byte salt in beforeEach; it is a fuzz
 *      input here.
 *
 *      Where the spec only asserts Seaport's InvalidContractOrder and names
 *      the token's inner error in a comment, the port also asserts the inner
 *      error through previewOrder. Where the comment names the wrong inner
 *      error, the port asserts the actual one and says so.
 */
contract ERC1155SeaDropMintSignedTest is SeaDrop1155MintHelpers {
    IERC1155SeaDrop seadropToken;

    address owner;
    address creator;
    address payer;
    address minter;
    address feeRecipient;
    address signer;

    function setUp() public override {
        super.setUp();

        owner = address(this);
        creator = makeAddr("creator");
        payer = makeAddr("payer");
        minter = makeAddr("minter");
        feeRecipient = makeAddr("feeRecipient");
        signer = makeAddr("signer");
        vm.deal(owner, 100 ether);
        vm.deal(payer, 100 ether);
        vm.deal(minter, 100 ether);

        // Deploy and configure the token.
        token = _deployERC1155SeaDrop();
        seadropToken = IERC1155SeaDrop(address(token));
        token.setMaxSupply(5, 100);
        _setSingleCreatorPayout(address(token), creator);
        seadropToken.updateAllowedFeeRecipient(feeRecipient, true);

        // Add signer.
        seadropToken.updateSigner(signer, true);
    }

    function _mintParams() internal view returns (MintParams memory) {
        return
            MintParams({
                startPrice: 0.1 ether,
                endPrice: 0.1 ether,
                startTime: block.timestamp - 1000,
                endTime: block.timestamp + 1000,
                paymentToken: address(0),
                fromTokenId: 5,
                toTokenId: 5,
                maxTotalMintableByWallet: 10,
                maxTotalMintableByWalletPerToken: 9,
                maxTokenSupplyForStage: 100,
                dropStageIndex: 1,
                feeBps: 1000,
                restrictFeeRecipients: true
            });
    }

    /// @dev Signed mint order for token id 5 on `token`.
    function _order(
        uint256 quantity,
        address feeRecipient_,
        address minter_,
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature
    ) internal view returns (AdvancedOrder memory, uint256) {
        return
            _signedMintOrder(
                address(token),
                _single(5),
                _single(quantity),
                feeRecipient_,
                mintParams.feeBps,
                mintParams.startPrice,
                minter_,
                mintParams,
                salt,
                signature
            );
    }

    function _assertSigners(address[] memory expected) internal {
        address[] memory signers = seadropToken.getSigners();
        assertEq(signers.length, expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(signers[i], expected[i]);
        }
    }

    function testMintSignedMint(uint256 salt) public {
        MintParams memory mintParams = _mintParams();

        // Mint signed with payer for minter.
        (bytes memory signature, bytes32 digest) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            mintParams,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            3,
            feeRecipient,
            minter,
            mintParams,
            salt,
            signature
        );

        assertFalse(seadropToken.getDigestIsUsed(digest));

        _expectPreviewRevert(
            payer,
            order,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );
        _fulfillExpectingInvalidContractOrder(payer, order, value);

        assertFalse(seadropToken.getDigestIsUsed(digest));

        // Allow the payer.
        seadropToken.updatePayer(payer, true);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(payer, mintParams.dropStageIndex);
        _fulfill(payer, order, value);

        assertEq(token.balanceOf(minter, 5), 3);
        assertEq(token.totalSupply(5), 3);
        assertTrue(seadropToken.getDigestIsUsed(digest));

        // Ensure a signature can only be used once.
        // Mint again with the same params.
        _expectPreviewRevert(
            payer,
            order,
            abi.encodeWithSelector(SignatureAlreadyUsed.selector)
        );
        _fulfillExpectingInvalidContractOrder(payer, order, value);

        assertTrue(seadropToken.getDigestIsUsed(digest));

        // Mint signed with minter being payer.
        // Change the salt to use a new digest.
        uint256 newSalt = uint256(keccak256(abi.encode(salt, "newSalt")));
        (signature, digest) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            mintParams,
            newSalt
        );
        (order, value) = _order(
            3,
            feeRecipient,
            minter,
            mintParams,
            newSalt,
            signature
        );

        assertFalse(seadropToken.getDigestIsUsed(digest));

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(minter, order, value);

        assertEq(token.balanceOf(minter, 5), 6);
        assertEq(token.totalSupply(5), 6);
        assertTrue(seadropToken.getDigestIsUsed(digest));
    }

    function testCannotMintSignedMintWithDifferentParams(uint256 salt) public {
        MintParams memory mintParams = _mintParams();

        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter, // sign mint for minter
            feeRecipient,
            mintParams,
            salt
        );

        // Split into steps to avoid stack too deep.
        _differentMinterAndFeeRecipientFail(mintParams, salt, signature);
        IERC1155SeaDrop tokenSeaDropInterface2 = _differentTokenContractFails(
            mintParams,
            salt,
            signature
        );
        address signer2 = _signerNotAllowedFails(
            mintParams,
            salt,
            tokenSeaDropInterface2
        );
        _differentMintParamsAndSaltFail(salt, signature);

        // Ensure that the zero address cannot be added as a signer.
        vm.expectRevert(SignerCannotBeZeroAddress.selector);
        seadropToken.updateSigner(address(0), true);

        // Remove the original signer for branch coverage.
        seadropToken.updateSigner(signer, false);
        _assertSigners(new address[](0));

        // Add two signers and remove the second for branch coverage.
        seadropToken.updateSigner(signer, true);
        _assertSigners(_addresses(signer));
        seadropToken.updateSigner(signer2, true);
        _assertSigners(_addresses(signer, signer2));
        seadropToken.updateSigner(signer2, false);
        _assertSigners(_addresses(signer));
    }

    function _differentMinterAndFeeRecipientFail(
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature
    ) internal {
        // Test with different minter address.
        (AdvancedOrder memory order, uint256 value) = _order(
            3,
            feeRecipient,
            payer,
            mintParams,
            salt,
            signature
        );

        // NOTE: the spec comment names InvalidSignature, but the order is
        // fulfilled by `minter` for a different minter (`payer`), and
        // `minter` is not an allowed payer yet. The payer check runs before
        // signature recovery, so it fails with PayerNotAllowed.
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(PayerNotAllowed.selector, minter)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);

        // Test with different fee recipient.
        seadropToken.updateAllowedFeeRecipient(payer, true);
        seadropToken.updatePayer(payer, true);

        (order, value) = _order(
            3,
            payer, // different fee recipient
            minter,
            mintParams,
            salt,
            signature
        );

        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function _differentTokenContractFails(
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature
    ) internal returns (IERC1155SeaDrop tokenSeaDropInterface2) {
        // Test with different token contract.
        ERC1155SeaDrop token2 = _deployERC1155SeaDrop();
        tokenSeaDropInterface2 = IERC1155SeaDrop(address(token2));
        token2.setMaxSupply(5, 100);
        _setSingleCreatorPayout(address(token2), creator);
        tokenSeaDropInterface2.updateAllowedFeeRecipient(feeRecipient, true);

        // Test coverage for error SignerNotPresent().
        vm.expectRevert(SignerNotPresent.selector);
        tokenSeaDropInterface2.updateSigner(
            0x8888888888888888888888888888888888888888,
            false
        );

        // The spec omits tokenIds here, so createMintOrder uses token id 0.
        (AdvancedOrder memory order, uint256 value) = _signedMintOrder(
            address(token2),
            _single(0),
            _single(3),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            salt,
            signature
        );

        // NOTE: the spec comment names InvalidSignature, but token id 0 is
        // outside the signed stage's range (5 to 5), which is checked first.
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents
                    .TokenIdNotWithinDropStageRange
                    .selector,
                0,
                5,
                5
            )
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function _signerNotAllowedFails(
        MintParams memory mintParams,
        uint256 salt,
        IERC1155SeaDrop tokenSeaDropInterface2
    ) internal returns (address signer2) {
        // Test with signer that is not allowed.
        signer2 = makeAddr("signer2");
        seadropToken.updateSigner(signer2, true);
        seadropToken.updateSigner(signer2, false);
        assertEq(tokenSeaDropInterface2.getSigners().length, 0);
        (bytes memory signature2, ) = _signMint(
            "signer2",
            address(token),
            minter, // sign mint for minter
            feeRecipient,
            mintParams,
            salt
        );
        (AdvancedOrder memory order, uint256 value) = _order(
            3,
            feeRecipient,
            minter,
            mintParams,
            salt,
            signature2
        );
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function _differentMintParamsAndSaltFail(
        uint256 salt,
        bytes memory signature
    ) internal {
        // Test with different mint params.
        MintParams memory differentMintParams = _mintParams();
        differentMintParams.maxTokenSupplyForStage = 10000;
        (AdvancedOrder memory order, uint256 value) = _order(
            3,
            feeRecipient,
            minter,
            differentMintParams,
            salt,
            signature
        );
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);

        // Test with different salt.
        (order, value) = _order(
            3,
            feeRecipient,
            minter,
            differentMintParams,
            uint256(keccak256(abi.encode(salt, "differentSalt"))),
            signature
        );
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testCannotMintSignedMintAfterExceedingMaxMintsPerWallet(
        uint256 salt
    ) public {
        MintParams memory mintParams = _mintParams();

        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            mintParams,
            salt
        );

        // Max mints per wallet per token is 9. Mint 9.
        (AdvancedOrder memory order, uint256 value) = _order(
            9,
            feeRecipient,
            minter,
            mintParams,
            salt,
            signature
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(minter, order, value);

        // Try to mint one more.
        (order, value) = _order(
            1,
            feeRecipient,
            minter,
            mintParams,
            salt,
            signature
        );

        // NOTE: the spec comment names MintQuantityExceedsMaxMintedPerWallet,
        // but this reuses the same salt and signature, so the digest is
        // already used and it fails with SignatureAlreadyUsed first.
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(SignatureAlreadyUsed.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);

        // Try to mint one more with manipulated mintParams.
        MintParams memory manipulatedMintParams = _mintParams();
        manipulatedMintParams.maxTotalMintableByWalletPerToken = 10;
        (order, value) = _order(
            1,
            feeRecipient,
            minter,
            manipulatedMintParams,
            salt,
            signature
        );

        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testMintSignedMintWithFeeRoundingDownToZero(uint256 salt) public {
        MintParams memory mintParamsZeroFee = _mintParams();
        mintParamsZeroFee.startPrice = 1;
        mintParamsZeroFee.endPrice = 1;
        mintParamsZeroFee.feeBps = 1;

        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            mintParamsZeroFee,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            3,
            feeRecipient,
            minter,
            mintParamsZeroFee,
            salt,
            signature
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParamsZeroFee.dropStageIndex);
        _fulfill(minter, order, value);

        assertEq(token.balanceOf(minter, 5), 3);
        assertEq(token.totalSupply(5), 3);
    }

    function testCannotMintWithInvalidFeeBps(uint256 salt) public {
        MintParams memory mintParams = _mintParams();
        MintParams memory mintParamsInvalidFeeBps = _mintParams();
        mintParamsInvalidFeeBps.feeBps = 11_000;

        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            mintParamsInvalidFeeBps,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _signedMintOrder(
            address(token),
            _single(5),
            _single(1),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParamsInvalidFeeBps,
            salt,
            signature
        );

        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(InvalidFeeBps.selector, 11_000)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    /// @dev The spec has this case twice with the same title and body; both
    ///      map here.
    function testDelegatedPayerCanMint(uint256 salt) public {
        MintParams memory mintParams = _mintParams();

        _setTwoCreatorPayouts(creator, owner);

        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            mintParams,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            3,
            feeRecipient,
            minter,
            mintParams,
            salt,
            signature
        );

        _expectPreviewRevert(
            payer,
            order,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );
        _fulfillExpectingInvalidContractOrder(payer, order, value);

        // Delegate payer for minter.
        vm.prank(minter);
        IDelegationRegistry(DELEGATION_REGISTRY).delegateForAll(payer, true);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(payer, mintParams.dropStageIndex);
        _fulfill(payer, order, value);

        // Remove delegation.
        vm.prank(minter);
        IDelegationRegistry(DELEGATION_REGISTRY).delegateForAll(payer, false);
    }

    function testPreviewOrderReturnsExpectedOfferAndConsideration(
        uint256 salt
    ) public {
        MintParams memory mintParams = _mintParams();

        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            mintParams,
            salt
        );

        (AdvancedOrder memory order, ) = _order(
            1,
            feeRecipient,
            minter,
            mintParams,
            salt,
            signature
        );

        _assertPreviewOrderMatches(minter, order);
    }

    function testSignersCanDisallowThemselves() public {
        address signer2 = makeAddr("signer2");

        _assertSigners(_addresses(signer));

        // A signer should be able to disallow themselves.
        vm.prank(signer);
        seadropToken.updateSigner(signer, false);
        _assertSigners(new address[](0));

        // A signer should not be able to re-allow themselves.
        vm.prank(signer);
        vm.expectRevert(Ownable.Unauthorized.selector);
        seadropToken.updateSigner(signer, true);
        _assertSigners(new address[](0));

        seadropToken.updateSigner(signer, true);

        // A signer should not be able to allow or disallow another signer.
        vm.prank(signer);
        vm.expectRevert(Ownable.Unauthorized.selector);
        seadropToken.updateSigner(signer2, true);
        vm.prank(signer);
        vm.expectRevert(Ownable.Unauthorized.selector);
        seadropToken.updateSigner(signer2, false);
        vm.prank(signer2);
        vm.expectRevert(Ownable.Unauthorized.selector);
        seadropToken.updateSigner(signer, true);
        vm.prank(signer2);
        vm.expectRevert(Ownable.Unauthorized.selector);
        seadropToken.updateSigner(signer, false);

        _assertSigners(_addresses(signer));
    }

    /// @dev The Hardhat version patched Hardhat internals to change the
    ///      chain id and no longer runs, so this is the only coverage of the
    ///      branch: the token derives its EIP-712 domain separator from
    ///      block.chainid, so a mint signed on one chain fails on another.
    function testRevertsOnChangedChainId(uint256 salt) public {
        MintParams memory mintParams = _mintParams();

        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            mintParams,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            3,
            feeRecipient,
            minter,
            mintParams,
            salt,
            signature
        );

        // The order is valid on the chain it was signed for.
        assertTrue(block.chainid != 1);
        _assertPreviewOrderMatches(minter, order);

        // Change the chain id after signing.
        vm.chainId(1);

        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);

        assertEq(token.balanceOf(minter, 5), 0);
    }
}
