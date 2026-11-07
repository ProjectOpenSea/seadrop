// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721Test } from "./utils/SeaDrop721Test.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { MintParams } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ECDSA } from "solady/src/utils/ECDSA.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

/**
 * @dev Server-signed (SIP-12 substandard 2) mints. The test contract deploys
 *      the token, so it is the owner. The salt is fuzzed. Failed mints assert
 *      the SeaDrop error from both previewOrder and the Seaport fulfillment.
 */
contract ERC721SeaDropMintSignedTest is SeaDrop721Test {
    address creator = makeAddr("creator");
    address payer = makeAddr("payer");
    address minter = makeAddr("minter");
    address feeRecipient = makeAddr("feeRecipient");
    address signer = makeAddr("signer");
    address signer2 = makeAddr("signer2");

    MintParams mintParams;

    function setUp() public override {
        super.setUp();

        token = _deployToken();

        vm.deal(payer, 100 ether);
        vm.deal(minter, 100 ether);

        // Configure the token.
        token.setMaxSupply(100);
        _setSingleCreatorPayout(address(token), creator);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);

        mintParams = MintParams({
            startPrice: 0.1 ether,
            endPrice: 0.1 ether,
            startTime: block.timestamp - 1000,
            endTime: block.timestamp + 1000,
            paymentToken: address(0),
            maxTotalMintableByWallet: 10,
            maxTokenSupplyForStage: 100,
            dropStageIndex: 1,
            feeBps: 1000,
            restrictFeeRecipients: true
        });

        // Add signer.
        _seaDrop().updateSigner(signer, true);
    }

    function _order(
        address tokenAddress,
        uint256 quantity,
        address orderFeeRecipient,
        address orderMinter,
        MintParams memory params,
        uint256 salt,
        bytes memory signature
    ) internal view returns (AdvancedOrder memory, uint256) {
        return _signedMintOrder(
            tokenAddress,
            quantity,
            orderFeeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            orderMinter,
            params,
            salt,
            signature
        );
    }

    function _otherSalt(uint256 salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(salt, "other salt")));
    }

    /// @dev Should mint a signed mint.
    function testMintSigned(uint256 salt) public {
        // Mint signed with payer for minter.
        MintParams memory params = mintParams;
        (bytes memory signature, bytes32 digest) = _signMint(
            "signer", address(token), minter, feeRecipient, params, salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token), 3, feeRecipient, minter, params, salt, signature
        );

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

        _fulfillAndExpectMint(order, payer, value, params.dropStageIndex);

        assertEq(token.balanceOf(minter), 3);
        assertEq(token.totalSupply(), 3);
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
        uint256 newSalt = _otherSalt(salt);
        (signature, digest) = _signMint(
            "signer", address(token), minter, feeRecipient, params, newSalt
        );
        (order, value) = _order(
            address(token), 3, feeRecipient, minter, params, newSalt, signature
        );

        assertFalse(_seaDrop().getDigestIsUsed(digest));

        _fulfillAndExpectMint(order, minter, value, params.dropStageIndex);

        assertEq(token.balanceOf(minter), 6);
        assertEq(token.totalSupply(), 6);
        assertTrue(_seaDrop().getDigestIsUsed(digest));
    }

    /// @dev Should not mint a signed mint with different params.
    function testCannotMintSignedWithDifferentParams(uint256 salt) public {
        MintParams memory params = mintParams;
        bytes memory invalidSignature =
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector);

        // Sign the mint for minter.
        (bytes memory signature,) = _signMint(
            "signer", address(token), minter, feeRecipient, params, salt
        );

        // Test with a different minter address.
        (AdvancedOrder memory order, uint256 value) = _order(
            address(token), 3, feeRecipient, payer, params, salt, signature
        );

        // Fulfilled by `minter`: the payer check runs before the signature
        // check, and minter is not an allowed payer for `payer`.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, minter)
        );

        // Minting for themselves, the different minter fails the signature
        // check.
        _assertMintReverts(order, payer, value, invalidSignature);

        // Test with a different fee recipient.
        _seaDrop().updateAllowedFeeRecipient(payer, true);
        _seaDrop().updatePayer(payer, true);

        (order, value) =
            _order(address(token), 3, payer, minter, params, salt, signature);
        _assertMintReverts(order, minter, value, invalidSignature);

        // Test with a different token contract.
        ERC721SeaDrop token2 = _deployToken();
        token2.setMaxSupply(100);
        _setSingleCreatorPayout(address(token2), creator);
        IERC721SeaDrop(address(token2))
            .updateAllowedFeeRecipient(feeRecipient, true);

        // Test coverage for error SignerNotPresent().
        vm.expectRevert(SignerNotPresent.selector);
        IERC721SeaDrop(address(token2))
            .updateSigner(
                address(0x8888888888888888888888888888888888888888), false
            );

        IERC721SeaDrop(address(token2)).updateSigner(signer, true);
        IERC721SeaDrop(address(token2)).updateSigner(signer, false);
        IERC721SeaDrop(address(token2)).updateSigner(signer, true);

        (order, value) = _order(
            address(token2), 3, feeRecipient, minter, params, salt, signature
        );
        _assertMintReverts(order, minter, value, invalidSignature);

        // Test with a signer that is not allowed.
        _seaDrop().updateSigner(signer2, true);
        _seaDrop().updateSigner(signer2, false);
        _assertEq(
            IERC721SeaDrop(address(token2)).getSigners(),
            _addrs(signer),
            "signers"
        );
        (bytes memory signature2,) = _signMint(
            "signer2", address(token), minter, feeRecipient, params, salt
        );
        (order, value) = _order(
            address(token), 3, feeRecipient, minter, params, salt, signature2
        );
        _assertMintReverts(order, minter, value, invalidSignature);

        // Test with different mint params.
        MintParams memory differentParams = _copyMintParams(params);
        differentParams.maxTokenSupplyForStage = 10_000;
        (order, value) = _order(
            address(token),
            3,
            feeRecipient,
            minter,
            differentParams,
            salt,
            signature
        );
        _assertMintReverts(order, minter, value, invalidSignature);

        // Test with a different salt.
        (order, value) = _order(
            address(token),
            3,
            feeRecipient,
            minter,
            differentParams,
            _otherSalt(salt),
            signature
        );
        _assertMintReverts(order, minter, value, invalidSignature);

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

    /// @dev Should not mint a signed mint after exceeding max mints per
    ///      wallet.
    function testCannotMintSignedAfterExceedingMaxMintsPerWallet(uint256 salt)
        public
    {
        MintParams memory params = mintParams;
        (bytes memory signature,) = _signMint(
            "signer", address(token), minter, feeRecipient, params, salt
        );

        // Max mints per wallet is 10. Mint 10.
        (AdvancedOrder memory order, uint256 value) = _order(
            address(token), 10, feeRecipient, minter, params, salt, signature
        );
        _fulfillAndExpectMint(order, minter, value, params.dropStageIndex);

        // Try to mint one more with the same salt and signature: the used
        // digest is rejected first.
        (order, value) = _order(
            address(token), 1, feeRecipient, minter, params, salt, signature
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(SignatureAlreadyUsed.selector)
        );

        // A fresh signature for the same params exceeds the max mints per
        // wallet.
        uint256 freshSalt = _otherSalt(salt);
        (bytes memory freshSignature,) = _signMint(
            "signer", address(token), minter, feeRecipient, params, freshSalt
        );
        (order, value) = _order(
            address(token),
            1,
            feeRecipient,
            minter,
            params,
            freshSalt,
            freshSignature
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector, 11, 10
            )
        );

        // Try to mint one more with manipulated mintParams.
        MintParams memory manipulatedParams = _copyMintParams(params);
        manipulatedParams.maxTotalMintableByWallet = 11;
        (order, value) = _order(
            address(token),
            1,
            feeRecipient,
            minter,
            manipulatedParams,
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

    /// @dev Should mint a signed mint with fee amount that rounds down to
    ///      zero.
    function testMintSignedWithFeeAmountRoundingToZero(uint256 salt) public {
        MintParams memory zeroFeeParams = _copyMintParams(mintParams);
        zeroFeeParams.startPrice = 1;
        zeroFeeParams.endPrice = 1;
        zeroFeeParams.feeBps = 1;

        (bytes memory signature,) = _signMint(
            "signer", address(token), minter, feeRecipient, zeroFeeParams, salt
        );

        (AdvancedOrder memory order, uint256 value) = _signedMintOrder(
            address(token),
            3,
            feeRecipient,
            zeroFeeParams.feeBps,
            zeroFeeParams.startPrice,
            minter,
            zeroFeeParams,
            salt,
            signature
        );

        _fulfillAndExpectMint(order, minter, value, mintParams.dropStageIndex);

        assertEq(token.balanceOf(minter), 3);
        assertEq(token.totalSupply(), 3);
    }

    /// @dev Should not mint with invalid fee bps.
    function testCannotMintSignedWithInvalidFeeBps(uint256 salt) public {
        MintParams memory invalidFeeBpsParams = _copyMintParams(mintParams);
        invalidFeeBpsParams.feeBps = 11_000;

        (bytes memory signature,) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            invalidFeeBpsParams,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            1,
            feeRecipient,
            minter,
            invalidFeeBpsParams,
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
        _seaDrop()
            .updateCreatorPayouts(
                _payouts(creator, 5_000, address(this), 5_000)
            );

        MintParams memory params = mintParams;
        (bytes memory signature,) = _signMint(
            "signer", address(token), minter, feeRecipient, params, salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token), 3, feeRecipient, minter, params, salt, signature
        );

        _assertMintReverts(
            order,
            payer,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );

        // Delegate payer for minter.
        vm.prank(minter);
        DELEGATION_REGISTRY.delegateForAll(payer, true);

        _fulfillAndExpectMint(order, payer, value, params.dropStageIndex);

        // Remove delegation.
        vm.prank(minter);
        DELEGATION_REGISTRY.delegateForAll(payer, false);
    }

    /// @dev Should return the expected offer and consideration in
    ///      previewOrder.
    function testPreviewOrder(uint256 salt) public {
        MintParams memory params = mintParams;
        (bytes memory signature,) = _signMint(
            "signer", address(token), minter, feeRecipient, params, salt
        );

        (AdvancedOrder memory order,) = _order(
            address(token), 1, feeRecipient, minter, params, salt, signature
        );

        _assertPreviewOrderMatches(order, minter);
    }

    /// @dev Signers should be able to disallow themselves.
    function testSignersCanDisallowThemselves() public {
        IERC721SeaDrop seaDropToken = IERC721SeaDrop(address(token));

        _assertEq(_seaDrop().getSigners(), _addrs(signer), "signers");

        // A signer should be able to disallow themselves.
        vm.prank(signer);
        seaDropToken.updateSigner(signer, false);
        _assertEq(_seaDrop().getSigners(), new address[](0), "signers");

        // A signer should not be able to re-allow themselves.
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(signer);
        seaDropToken.updateSigner(signer, true);
        _assertEq(_seaDrop().getSigners(), new address[](0), "signers");

        seaDropToken.updateSigner(signer, true);

        // A signer should not be able to allow or disallow another signer.
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(signer);
        seaDropToken.updateSigner(signer2, true);
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(signer);
        seaDropToken.updateSigner(signer2, false);
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(signer2);
        seaDropToken.updateSigner(signer, true);
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(signer2);
        seaDropToken.updateSigner(signer, false);

        _assertEq(_seaDrop().getSigners(), _addrs(signer), "signers");
    }

    /**
     * @dev Reverts on changed chainId. The 721 implementation derives the
     *      EIP-712 domain separator from block.chainid on every call (there
     *      is no cached chain id), so a signature made on one chain does not
     *      recover to the signer on another.
     */
    function testRevertsOnChangedChainId(uint256 salt) public {
        MintParams memory params = mintParams;
        (bytes memory signature,) = _signMint(
            "signer", address(token), minter, feeRecipient, params, salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token), 3, feeRecipient, minter, params, salt, signature
        );

        // The signed mint is valid on the chain it was signed for.
        _assertPreviewOrderMatches(order, minter);

        // Change the chain id after signing.
        assertTrue(block.chainid != 1);
        vm.chainId(1);

        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(ECDSA.InvalidSignature.selector)
        );
    }
}
