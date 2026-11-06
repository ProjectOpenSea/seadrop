// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./utils/SeaDrop1155Test.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "seadrop/lib/ERC1155SeaDropErrorsAndEvents.sol";

import { MintParams } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

import { ECDSA } from "solady/src/utils/ECDSA.sol";

/**
 * @dev Server-signed (SIP-12 substandard 2) mints of token id 5. The salt is
 *      fuzzed. Failed mints assert both Seaport's InvalidContractOrder and
 *      the SeaDrop error behind it.
 */
contract ERC1155SeaDropMintSignedTest is SeaDrop1155Test {
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
        token = _deployToken();
        token.setMaxSupply(5, 100);
        _setSingleCreatorPayout(address(token), creator);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);

        // Add signer.
        _seaDrop().updateSigner(signer, true);
    }

    function _mintParams() internal view returns (MintParams memory) {
        return MintParams({
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
        return _signedMintOrder(
            address(token),
            _uints(5),
            _uints(quantity),
            feeRecipient_,
            mintParams.feeBps,
            mintParams.startPrice,
            minter_,
            mintParams,
            salt,
            signature
        );
    }

    function testMintSignedMint(uint256 salt) public {
        MintParams memory mintParams = _mintParams();

        // Mint signed with payer for minter.
        (bytes memory signature, bytes32 digest) = _signMint(
            "signer", address(token), minter, feeRecipient, mintParams, salt
        );

        (AdvancedOrder memory order, uint256 value) =
            _order(3, feeRecipient, minter, mintParams, salt, signature);

        assertFalse(_seaDrop().getDigestIsUsed(digest));

        _assertMintReverts(
            order,
            payer,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );

        assertFalse(_seaDrop().getDigestIsUsed(digest));

        // Allow the payer.
        _seaDrop().updatePayer(payer, true);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(payer, mintParams.dropStageIndex);
        _fulfill(order, payer, value);

        assertEq(token.balanceOf(minter, 5), 3);
        assertEq(token.totalSupply(5), 3);
        assertTrue(_seaDrop().getDigestIsUsed(digest));

        // Ensure a signature can only be used once.
        // Mint again with the same params.
        _assertMintReverts(
            order,
            payer,
            value,
            abi.encodeWithSelector(SignatureAlreadyUsed.selector)
        );

        assertTrue(_seaDrop().getDigestIsUsed(digest));

        // Mint signed with minter being payer.
        // Change the salt to use a new digest.
        uint256 newSalt = uint256(keccak256(abi.encode(salt, "newSalt")));
        (signature, digest) = _signMint(
            "signer", address(token), minter, feeRecipient, mintParams, newSalt
        );
        (order, value) =
            _order(3, feeRecipient, minter, mintParams, newSalt, signature);

        assertFalse(_seaDrop().getDigestIsUsed(digest));

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(order, minter, value);

        assertEq(token.balanceOf(minter, 5), 6);
        assertEq(token.totalSupply(5), 6);
        assertTrue(_seaDrop().getDigestIsUsed(digest));
    }

    function testCannotMintSignedMintWithDifferentParams(uint256 salt) public {
        MintParams memory mintParams = _mintParams();

        (bytes memory signature,) = _signMint(
            "signer",
            address(token),
            minter, // sign mint for minter
            feeRecipient,
            mintParams,
            salt
        );

        // Split into steps to avoid stack too deep.
        _differentMinterAndFeeRecipientFail(mintParams, salt, signature);
        IERC1155SeaDrop tokenSeaDropInterface2 =
            _differentTokenContractFails(mintParams, salt, signature);
        address signer2 =
            _signerNotAllowedFails(mintParams, salt, tokenSeaDropInterface2);
        _differentMintParamsAndSaltFail(salt, signature);

        // Ensure that the zero address cannot be added as a signer.
        vm.expectRevert(SignerCannotBeZeroAddress.selector);
        _seaDrop().updateSigner(address(0), true);

        // Remove the original signer for branch coverage.
        _seaDrop().updateSigner(signer, false);
        _assertEq(_seaDrop().getSigners(), new address[](0), "signers");

        // Add two signers and remove the second for branch coverage.
        _seaDrop().updateSigner(signer, true);
        _assertEq(_seaDrop().getSigners(), _addrs(signer), "signers");
        _seaDrop().updateSigner(signer2, true);
        _assertEq(_seaDrop().getSigners(), _addrs(signer, signer2), "signers");
        _seaDrop().updateSigner(signer2, false);
        _assertEq(_seaDrop().getSigners(), _addrs(signer), "signers");
    }

    function _differentMinterAndFeeRecipientFail(
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature
    ) internal {
        // Test with different minter address.
        (AdvancedOrder memory order, uint256 value) =
            _order(3, feeRecipient, payer, mintParams, salt, signature);

        // Fulfilled by `minter` for a different minter (`payer`): `minter` is
        // not an allowed payer yet, and the payer check runs before
        // signature recovery.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, minter)
        );

        // Test with different fee recipient.
        _seaDrop().updateAllowedFeeRecipient(payer, true);
        _seaDrop().updatePayer(payer, true);

        (order, value) = _order(
            3,
            payer, // different fee recipient
            minter,
            mintParams,
            salt,
            signature
        );

        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );
    }

    function _differentTokenContractFails(
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature
    ) internal returns (IERC1155SeaDrop tokenSeaDropInterface2) {
        // Test with different token contract.
        ERC1155SeaDrop token2 = _deployToken();
        tokenSeaDropInterface2 = IERC1155SeaDrop(address(token2));
        token2.setMaxSupply(5, 100);
        _setSingleCreatorPayout(address(token2), creator);
        tokenSeaDropInterface2.updateAllowedFeeRecipient(feeRecipient, true);

        // Test coverage for error SignerNotPresent().
        vm.expectRevert(SignerNotPresent.selector);
        tokenSeaDropInterface2.updateSigner(
            0x8888888888888888888888888888888888888888, false
        );

        (AdvancedOrder memory order, uint256 value) = _signedMintOrder(
            address(token2),
            _uints(0),
            _uints(3),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            salt,
            signature
        );

        // Token id 0 is outside the signed stage's range (5 to 5), which is
        // checked before the signature.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.TokenIdNotWithinDropStageRange
                .selector,
                0,
                5,
                5
            )
        );
    }

    function _signerNotAllowedFails(
        MintParams memory mintParams,
        uint256 salt,
        IERC1155SeaDrop tokenSeaDropInterface2
    ) internal returns (address signer2) {
        // Test with signer that is not allowed.
        signer2 = makeAddr("signer2");
        _seaDrop().updateSigner(signer2, true);
        _seaDrop().updateSigner(signer2, false);
        assertEq(tokenSeaDropInterface2.getSigners().length, 0);
        (bytes memory signature2,) = _signMint(
            "signer2",
            address(token),
            minter, // sign mint for minter
            feeRecipient,
            mintParams,
            salt
        );
        (AdvancedOrder memory order, uint256 value) =
            _order(3, feeRecipient, minter, mintParams, salt, signature2);
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );
    }

    function _differentMintParamsAndSaltFail(
        uint256 salt,
        bytes memory signature
    ) internal {
        // Test with different mint params.
        MintParams memory differentMintParams = _mintParams();
        differentMintParams.maxTokenSupplyForStage = 10000;
        (AdvancedOrder memory order, uint256 value) = _order(
            3, feeRecipient, minter, differentMintParams, salt, signature
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );

        // Test with different salt.
        (order, value) = _order(
            3,
            feeRecipient,
            minter,
            differentMintParams,
            uint256(keccak256(abi.encode(salt, "differentSalt"))),
            signature
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );
    }

    function testCannotMintSignedMintAfterExceedingMaxMintsPerWallet(uint256 salt)
        public
    {
        MintParams memory mintParams = _mintParams();

        (bytes memory signature,) = _signMint(
            "signer", address(token), minter, feeRecipient, mintParams, salt
        );

        // Max mints per wallet per token is 9. Mint 9.
        (AdvancedOrder memory order, uint256 value) =
            _order(9, feeRecipient, minter, mintParams, salt, signature);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(order, minter, value);

        // Try to mint one more.
        (order, value) =
            _order(1, feeRecipient, minter, mintParams, salt, signature);

        // The same salt and signature: the digest is already used.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(SignatureAlreadyUsed.selector)
        );

        // Try to mint one more with manipulated mintParams.
        MintParams memory manipulatedMintParams = _mintParams();
        manipulatedMintParams.maxTotalMintableByWalletPerToken = 10;
        (order, value) = _order(
            1, feeRecipient, minter, manipulatedMintParams, salt, signature
        );

        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );
    }

    function testMintSignedMintWithFeeRoundingDownToZero(uint256 salt) public {
        MintParams memory mintParamsZeroFee = _mintParams();
        mintParamsZeroFee.startPrice = 1;
        mintParamsZeroFee.endPrice = 1;
        mintParamsZeroFee.feeBps = 1;

        (bytes memory signature,) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            mintParamsZeroFee,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            3, feeRecipient, minter, mintParamsZeroFee, salt, signature
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParamsZeroFee.dropStageIndex);
        _fulfill(order, minter, value);

        assertEq(token.balanceOf(minter, 5), 3);
        assertEq(token.totalSupply(5), 3);
    }

    function testCannotMintWithInvalidFeeBps(uint256 salt) public {
        MintParams memory mintParams = _mintParams();
        MintParams memory mintParamsInvalidFeeBps = _mintParams();
        mintParamsInvalidFeeBps.feeBps = 11_000;

        (bytes memory signature,) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            mintParamsInvalidFeeBps,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _signedMintOrder(
            address(token),
            _uints(5),
            _uints(1),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParamsInvalidFeeBps,
            salt,
            signature
        );

        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidFeeBps.selector, 11_000)
        );
    }

    /// @dev Should allow delegated payers to mint via the
    ///      DelegationRegistry.
    function testDelegatedPayerCanMint(uint256 salt) public {
        MintParams memory mintParams = _mintParams();

        _seaDrop().updateCreatorPayouts(_payouts(creator, 5_000, owner, 5_000));

        (bytes memory signature,) = _signMint(
            "signer", address(token), minter, feeRecipient, mintParams, salt
        );

        (AdvancedOrder memory order, uint256 value) =
            _order(3, feeRecipient, minter, mintParams, salt, signature);

        _assertMintReverts(
            order,
            payer,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );

        // Delegate payer for minter.
        vm.prank(minter);
        DELEGATION_REGISTRY.delegateForAll(payer, true);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(payer, mintParams.dropStageIndex);
        _fulfill(order, payer, value);

        // Remove delegation.
        vm.prank(minter);
        DELEGATION_REGISTRY.delegateForAll(payer, false);
    }

    function testPreviewOrderReturnsExpectedOfferAndConsideration(uint256 salt)
        public
    {
        MintParams memory mintParams = _mintParams();

        (bytes memory signature,) = _signMint(
            "signer", address(token), minter, feeRecipient, mintParams, salt
        );

        (AdvancedOrder memory order,) =
            _order(1, feeRecipient, minter, mintParams, salt, signature);

        _assertPreviewOrderMatches(order, minter);
    }

    function testSignersCanDisallowThemselves() public {
        address signer2 = makeAddr("signer2");

        _assertEq(_seaDrop().getSigners(), _addrs(signer), "signers");

        // A signer should be able to disallow themselves.
        vm.prank(signer);
        _seaDrop().updateSigner(signer, false);
        _assertEq(_seaDrop().getSigners(), new address[](0), "signers");

        // A signer should not be able to re-allow themselves.
        vm.prank(signer);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateSigner(signer, true);
        _assertEq(_seaDrop().getSigners(), new address[](0), "signers");

        _seaDrop().updateSigner(signer, true);

        // A signer should not be able to allow or disallow another signer.
        vm.prank(signer);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateSigner(signer2, true);
        vm.prank(signer);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateSigner(signer2, false);
        vm.prank(signer2);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateSigner(signer, true);
        vm.prank(signer2);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateSigner(signer, false);

        _assertEq(_seaDrop().getSigners(), _addrs(signer), "signers");
    }

    /// @dev The token derives its EIP-712 domain separator from
    ///      block.chainid, so a mint signed on one chain fails on another.
    function testRevertsOnChangedChainId(uint256 salt) public {
        MintParams memory mintParams = _mintParams();

        (bytes memory signature,) = _signMint(
            "signer", address(token), minter, feeRecipient, mintParams, salt
        );

        (AdvancedOrder memory order, uint256 value) =
            _order(3, feeRecipient, minter, mintParams, salt, signature);

        // The order is valid on the chain it was signed for.
        assertTrue(block.chainid != 1);
        _assertPreviewOrderMatches(order, minter);

        // Change the chain id after signing.
        vm.chainId(1);

        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );

        assertEq(token.balanceOf(minter, 5), 0);
    }
}
