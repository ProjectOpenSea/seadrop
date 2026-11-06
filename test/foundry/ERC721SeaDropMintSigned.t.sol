// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721MintHelpers } from "./utils/SeaDrop721MintHelpers.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { MintParams } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ECDSA } from "solady/src/utils/ECDSA.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

/**
 * @dev Port of test/ERC721SeaDrop-mintSigned.spec.ts.
 *      The test contract deploys the token, so it plays the spec's `owner`.
 *      The spec draws a random salt in beforeEach; here it is fuzzed.
 *      Where the spec can only see Seaport's InvalidContractOrder, the inner
 *      SeaDrop error is also asserted through previewOrder (see
 *      _assertMintReverts). Where it differs from the error named in the
 *      spec's comment, the test says why.
 */
contract ERC721SeaDropMintSignedTest is SeaDrop721MintHelpers {
    address creator = makeAddr("creator");
    address payer = makeAddr("payer");
    address minter = makeAddr("minter");
    address feeRecipient = makeAddr("feeRecipient");
    address signer = makeAddr("signer");
    address signer2 = makeAddr("signer2");

    MintParams mintParams;

    function setUp() public override {
        super.setUp();

        token = new ERC721SeaDrop(
            address(configurer),
            allowedSeaport,
            "Test721",
            "T721"
        );

        vm.deal(payer, 100 ether);
        vm.deal(minter, 100 ether);

        // Configure the token.
        token.setMaxSupply(100);
        setSingleCreatorPayout(creator);
        IERC721SeaDrop(address(token)).updateAllowedFeeRecipient(
            feeRecipient,
            true
        );

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
        IERC721SeaDrop(address(token)).updateSigner(signer, true);
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
        return
            _signedOrder(
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

    function _assertSigners(
        address tokenAddress,
        address[] memory expected
    ) internal {
        address[] memory signers = IERC721SeaDrop(tokenAddress).getSigners();
        assertEq(signers.length, expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(signers[i], expected[i]);
        }
    }

    function _list() internal pure returns (address[] memory list) {}

    function _list(address a) internal pure returns (address[] memory list) {
        list = new address[](1);
        list[0] = a;
    }

    function _list(
        address a,
        address b
    ) internal pure returns (address[] memory list) {
        list = new address[](2);
        list[0] = a;
        list[1] = b;
    }

    /// @dev "Should mint a signed mint"
    function testMintSigned(uint256 salt) public {
        // Mint signed with payer for minter.
        MintParams memory params = mintParams;
        (bytes memory signature, bytes32 digest) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            3,
            feeRecipient,
            minter,
            params,
            salt,
            signature
        );

        assertFalse(IERC721SeaDrop(address(token)).getDigestIsUsed(digest));

        _assertMintReverts(
            order,
            payer,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );

        assertFalse(IERC721SeaDrop(address(token)).getDigestIsUsed(digest));

        // Allow the payer.
        IERC721SeaDrop(address(token)).updatePayer(payer, true);

        _fulfillAndExpectMint(order, payer, value, params.dropStageIndex);

        assertEq(token.balanceOf(minter), 3);
        assertEq(token.totalSupply(), 3);
        assertTrue(IERC721SeaDrop(address(token)).getDigestIsUsed(digest));

        // Ensure a signature can only be used once.
        // Mint again with the same params.
        _assertMintReverts(
            order,
            payer,
            value,
            abi.encodeWithSelector(SignatureAlreadyUsed.selector)
        );

        assertTrue(IERC721SeaDrop(address(token)).getDigestIsUsed(digest));

        // Mint signed with minter being payer.
        // Change the salt to use a new digest.
        uint256 newSalt = _otherSalt(salt);
        (signature, digest) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            newSalt
        );
        (order, value) = _order(
            address(token),
            3,
            feeRecipient,
            minter,
            params,
            newSalt,
            signature
        );

        assertFalse(IERC721SeaDrop(address(token)).getDigestIsUsed(digest));

        _fulfillAndExpectMint(order, minter, value, params.dropStageIndex);

        assertEq(token.balanceOf(minter), 6);
        assertEq(token.totalSupply(), 6);
        assertTrue(IERC721SeaDrop(address(token)).getDigestIsUsed(digest));
    }

    /// @dev "Should not mint a signed mint with different params"
    function testCannotMintSignedWithDifferentParams(uint256 salt) public {
        MintParams memory params = mintParams;
        bytes memory invalidSignature = abi.encodeWithSelector(
            ECDSA.InvalidSignature.selector
        );

        // Sign the mint for minter.
        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            salt
        );

        // Test with a different minter address.
        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            3,
            feeRecipient,
            payer,
            params,
            salt,
            signature
        );

        // The spec fulfills from `minter` and comments InvalidSignature, but
        // the payer check runs before the signature check, and minter is not
        // an allowed payer for `payer`, so the inner error is
        // PayerNotAllowed.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, minter)
        );

        // The spec's intent: minting for themselves, the different minter
        // fails the signature check.
        _assertMintReverts(order, payer, value, invalidSignature);

        // Test with a different fee recipient.
        IERC721SeaDrop(address(token)).updateAllowedFeeRecipient(payer, true);
        IERC721SeaDrop(address(token)).updatePayer(payer, true);

        (order, value) = _order(
            address(token),
            3,
            payer,
            minter,
            params,
            salt,
            signature
        );
        _assertMintReverts(order, minter, value, invalidSignature);

        // Test with a different token contract.
        ERC721SeaDrop token2 = new ERC721SeaDrop(
            address(configurer),
            allowedSeaport,
            "Test721",
            "T721"
        );
        token2.setMaxSupply(100);
        _setSingleCreatorPayout(address(token2), creator);
        IERC721SeaDrop(address(token2)).updateAllowedFeeRecipient(
            feeRecipient,
            true
        );

        // Test coverage for error SignerNotPresent().
        vm.expectRevert(SignerNotPresent.selector);
        IERC721SeaDrop(address(token2)).updateSigner(
            address(0x8888888888888888888888888888888888888888),
            false
        );

        IERC721SeaDrop(address(token2)).updateSigner(signer, true);
        IERC721SeaDrop(address(token2)).updateSigner(signer, false);
        IERC721SeaDrop(address(token2)).updateSigner(signer, true);

        (order, value) = _order(
            address(token2),
            3,
            feeRecipient,
            minter,
            params,
            salt,
            signature
        );
        _assertMintReverts(order, minter, value, invalidSignature);

        // Test with a signer that is not allowed.
        IERC721SeaDrop(address(token)).updateSigner(signer2, true);
        IERC721SeaDrop(address(token)).updateSigner(signer2, false);
        _assertSigners(address(token2), _list(signer));
        (bytes memory signature2, ) = _signMint(
            "signer2",
            address(token),
            minter,
            feeRecipient,
            params,
            salt
        );
        (order, value) = _order(
            address(token),
            3,
            feeRecipient,
            minter,
            params,
            salt,
            signature2
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
        IERC721SeaDrop(address(token)).updateSigner(address(0), true);

        // Remove the original signer for branch coverage.
        IERC721SeaDrop(address(token)).updateSigner(signer, false);
        _assertSigners(address(token), _list());

        // Add two signers and remove the second for branch coverage.
        IERC721SeaDrop(address(token)).updateSigner(signer, true);
        _assertSigners(address(token), _list(signer));
        IERC721SeaDrop(address(token)).updateSigner(signer2, true);
        _assertSigners(address(token), _list(signer, signer2));
        IERC721SeaDrop(address(token)).updateSigner(signer2, false);
        _assertSigners(address(token), _list(signer));
    }

    /// @dev "Should not mint a signed mint after exceeding max mints per
    ///      wallet"
    function testCannotMintSignedAfterExceedingMaxMintsPerWallet(
        uint256 salt
    ) public {
        MintParams memory params = mintParams;
        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            salt
        );

        // Max mints per wallet is 10. Mint 10.
        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            10,
            feeRecipient,
            minter,
            params,
            salt,
            signature
        );
        _fulfillAndExpectMint(order, minter, value, params.dropStageIndex);

        // Try to mint one more. The spec comments
        // MintQuantityExceedsMaxMintedPerWallet, but it reuses the salt and
        // signature, so the used digest is rejected first.
        (order, value) = _order(
            address(token),
            1,
            feeRecipient,
            minter,
            params,
            salt,
            signature
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(SignatureAlreadyUsed.selector)
        );

        // The spec's intent: a fresh signature for the same params exceeds
        // the max mints per wallet.
        uint256 freshSalt = _otherSalt(salt);
        (bytes memory freshSignature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            freshSalt
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
                MintQuantityExceedsMaxMintedPerWallet.selector,
                11,
                10
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

    /// @dev "Should mint a signed mint with fee amount that rounds down to
    ///      zero"
    function testMintSignedWithFeeAmountRoundingToZero(uint256 salt) public {
        MintParams memory zeroFeeParams = _copyMintParams(mintParams);
        zeroFeeParams.startPrice = 1;
        zeroFeeParams.endPrice = 1;
        zeroFeeParams.feeBps = 1;

        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            zeroFeeParams,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _signedOrder(
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

    /// @dev "Should not mint with invalid fee bps"
    function testCannotMintSignedWithInvalidFeeBps(uint256 salt) public {
        MintParams memory invalidFeeBpsParams = _copyMintParams(mintParams);
        invalidFeeBpsParams.feeBps = 11_000;

        (bytes memory signature, ) = _signMint(
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

    /// @dev "Should allow delegated payers to mint via the
    ///      DelegationRegistry". The spec has this case twice with identical
    ///      bodies; this test covers both.
    function testDelegatedPayerCanMint(uint256 salt) public {
        _setCreatorPayouts(address(token), creator, 5_000, address(this), 5_000);

        MintParams memory params = mintParams;
        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            3,
            feeRecipient,
            minter,
            params,
            salt,
            signature
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

    /// @dev "Should return the expected offer and consideration in
    ///      previewOrder"
    function testPreviewOrder(uint256 salt) public {
        MintParams memory params = mintParams;
        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            salt
        );

        (AdvancedOrder memory order, ) = _order(
            address(token),
            1,
            feeRecipient,
            minter,
            params,
            salt,
            signature
        );

        _assertPreviewOrderEchoesOrder(order, minter);
    }

    /// @dev "Signers should be able to disallow themselves"
    function testSignersCanDisallowThemselves() public {
        IERC721SeaDrop seaDropToken = IERC721SeaDrop(address(token));

        _assertSigners(address(token), _list(signer));

        // A signer should be able to disallow themselves.
        vm.prank(signer);
        seaDropToken.updateSigner(signer, false);
        _assertSigners(address(token), _list());

        // A signer should not be able to re-allow themselves.
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(signer);
        seaDropToken.updateSigner(signer, true);
        _assertSigners(address(token), _list());

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

        _assertSigners(address(token), _list(signer));
    }

    /**
     * @dev "Reverts on changed chainId". The Hardhat case patched Hardhat
     *      internals to change the chain id and is now skipped there, so this
     *      is the only coverage. The 721 implementation derives the EIP-712
     *      domain separator from block.chainid on every call (there is no
     *      cached chain id), so a signature made on one chain does not
     *      recover to the signer on another.
     */
    function testRevertsOnChangedChainId(uint256 salt) public {
        MintParams memory params = mintParams;
        (bytes memory signature, ) = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            salt
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            3,
            feeRecipient,
            minter,
            params,
            salt,
            signature
        );

        // The signed mint is valid on the chain it was signed for.
        _assertPreviewOrderEchoesOrder(order, minter);

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
