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

/**
 * @dev Port of test/ERC1155SeaDrop-mintAllowList.spec.ts.
 *
 *      The spec draws feeBps with randomInt(1, 10_000) in beforeEach and
 *      some quantities with randomInt(1, n); those become fuzz inputs bounded
 *      to the same ranges (randomInt's upper bound is exclusive).
 *
 *      Where the spec only asserts Seaport's InvalidContractOrder and names
 *      the token's inner error in a comment, the port also asserts the inner
 *      error through previewOrder. Where the comment names the wrong inner
 *      error, the port asserts the actual one and says so.
 */
contract ERC1155SeaDropMintAllowListTest is SeaDrop1155MintHelpers {
    IERC1155SeaDrop seadropToken;

    address owner;
    address creator;
    address minter;
    address feeRecipient;

    function setUp() public override {
        super.setUp();

        owner = address(this);
        creator = makeAddr("creator");
        minter = makeAddr("minter");
        feeRecipient = makeAddr("feeRecipient");
        vm.deal(owner, 100 ether);
        vm.deal(minter, 100 ether);

        // Deploy and configure the token.
        token = _deployERC1155SeaDrop();
        seadropToken = IERC1155SeaDrop(address(token));
        token.setMaxSupply(10, 1000);
        seadropToken.updateAllowedFeeRecipient(feeRecipient, true);
        _setSingleCreatorPayout(address(token), creator);
    }

    /// @dev The spec's allow list mint params with a random feeBps.
    function _mintParams(uint256 feeBpsSeed)
        internal
        view
        returns (MintParams memory)
    {
        return MintParams({
            startPrice: 0.1 ether,
            endPrice: 0.1 ether,
            startTime: block.timestamp - 1000,
            endTime: block.timestamp + 1000,
            paymentToken: address(0),
            fromTokenId: 10,
            toTokenId: 10,
            maxTotalMintableByWallet: 10,
            maxTotalMintableByWalletPerToken: 9,
            maxTokenSupplyForStage: 11,
            dropStageIndex: 1,
            feeBps: bound(feeBpsSeed, 1, 9_999),
            restrictFeeRecipients: true
        });
    }

    /// @dev randomInt(1, maxTotalMintableByWalletPerToken) = [1, 8].
    function _quantity(uint256 quantitySeed) internal view returns (uint256) {
        return bound(quantitySeed, 1, 8);
    }

    /// @dev Allow list order for token id 10.
    function _order(
        uint256 quantity,
        address feeRecipient_,
        address minter_,
        MintParams memory mintParams,
        uint256 feeBps,
        bytes32[] memory proof
    ) internal view returns (AdvancedOrder memory, uint256) {
        return _allowListMintOrder(
            address(token),
            _single(10),
            _single(quantity),
            feeRecipient_,
            feeBps,
            mintParams.startPrice,
            minter_,
            mintParams,
            proof
        );
    }

    /// @dev Sets an allow list of only `minter` and returns the proof.
    function _allowOnlyMinter(MintParams memory mintParams)
        internal
        returns (bytes32 root, bytes32[] memory proof)
    {
        (root, proof) =
            _allowListRootAndProof(_addresses(minter), mintParams, 0);
        _updateAllowList(root);
    }

    function testMintToMinterOnAllowList(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        (AdvancedOrder memory order, uint256 value) = _order(
            quantity, feeRecipient, minter, mintParams, mintParams.feeBps, proof
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(minter, order, value);
    }

    function testMintFreeAllowListStage(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        // Create mint params with a price of 0.
        MintParams memory mintParamsFreeMint = _mintParams(feeBpsSeed);
        mintParamsFreeMint.startPrice = 0;
        mintParamsFreeMint.endPrice = 0;
        uint256 quantity = _quantity(quantitySeed);

        (bytes32 root, bytes32[] memory proof) =
            _allowOnlyMinter(mintParamsFreeMint);
        assertEq(seadropToken.getAllowListMerkleRoot(), root);

        (AdvancedOrder memory order, uint256 value) = _order(
            quantity,
            feeRecipient,
            minter,
            mintParamsFreeMint,
            mintParams.feeBps,
            proof
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(minter, order, value);
    }

    function testMintWithDifferentPayerThanMinter(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        (AdvancedOrder memory order, uint256 value) = _order(
            quantity, feeRecipient, minter, mintParams, mintParams.feeBps, proof
        );

        // The payer needs to be allowed first.
        _expectPreviewRevert(
            owner,
            order,
            abi.encodeWithSelector(PayerNotAllowed.selector, owner)
        );
        _fulfillExpectingInvalidContractOrder(owner, order, value);

        // Allow the payer.
        seadropToken.updatePayer(owner, true);

        // Mint an allow list stage with a different payer than minter.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(owner, mintParams.dropStageIndex);
        _fulfill(owner, order, value);
    }

    function testCannotMintWhenMinterNotOnAllowList(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        (AdvancedOrder memory order, uint256 value) = _order(
            quantity, feeRecipient, minter, mintParams, mintParams.feeBps, proof
        );

        address nonMinter = makeAddr("nonMinter");
        vm.deal(nonMinter, 100 ether);

        // NOTE: the spec comment names InvalidProof, but this order names
        // `minter`, whose proof is valid. It fails because nonMinter is not
        // an allowed payer for minter.
        _expectPreviewRevert(
            nonMinter,
            order,
            abi.encodeWithSelector(PayerNotAllowed.selector, nonMinter)
        );
        _fulfillExpectingInvalidContractOrder(nonMinter, order, value);

        // With a zero minter, the minter defaults to the fulfiller
        // (nonMinter), who is not on the allow list.
        (order, value) = _order(
            quantity,
            feeRecipient,
            address(0),
            mintParams,
            mintParams.feeBps,
            proof
        );

        _expectPreviewRevert(
            nonMinter, order, abi.encodeWithSelector(InvalidProof.selector)
        );
        _fulfillExpectingInvalidContractOrder(nonMinter, order, value);
    }

    function testCannotMintWithUnknownFeeRecipient(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        address invalidFeeRecipient = makeAddr("invalidFeeRecipient");

        (AdvancedOrder memory order, uint256 value) = _order(
            quantity,
            invalidFeeRecipient,
            minter,
            mintParams,
            mintParams.feeBps,
            proof
        );

        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(
                FeeRecipientNotAllowed.selector, invalidFeeRecipient
            )
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testCannotMintWithDifferentTokenContract(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        // Deploy a new ERC1155SeaDrop.
        ERC1155SeaDrop differentToken = _deployERC1155SeaDrop();

        // Update the fee recipient and creator payout address for the new
        // token.
        differentToken.setMaxSupply(10, 1000);
        IERC1155SeaDrop(address(differentToken))
            .updateAllowedFeeRecipient(feeRecipient, true);
        _setSingleCreatorPayout(address(differentToken), creator);

        // The spec omits tokenIds here, so createMintOrder uses token id 0.
        (AdvancedOrder memory order, uint256 value) = _allowListMintOrder(
            address(differentToken),
            _single(0),
            _single(quantity),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            proof
        );

        _expectPreviewRevert(
            minter, order, abi.encodeWithSelector(InvalidProof.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testCannotMintWithDifferentMintParams(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        // Create different mint params to include in the mint.
        MintParams memory differentMintParams = _mintParams(feeBpsSeed);
        differentMintParams.feeBps = mintParams.feeBps + 100;

        (AdvancedOrder memory order, uint256 value) = _order(
            quantity,
            feeRecipient,
            minter,
            differentMintParams,
            mintParams.feeBps,
            proof
        );

        _expectPreviewRevert(
            minter, order, abi.encodeWithSelector(InvalidProof.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testCannotMintAfterExceedingMaxMintsPerWallet(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        // randomInt(1, maxTotalMintableByWalletPerToken - 1) = [1, 7].
        uint256 quantity = bound(quantitySeed, 1, 7);
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        (AdvancedOrder memory order, uint256 value) = _order(
            quantity, feeRecipient, minter, mintParams, mintParams.feeBps, proof
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(minter, order, value);

        // Attempt to mint maxTotalMintableByWalletPerToken to the minter.
        (order, value) = _order(
            mintParams.maxTotalMintableByWalletPerToken,
            feeRecipient,
            minter,
            mintParams,
            mintParams.feeBps,
            proof
        );

        // The spec comment's withArgs names maxTotalMintableByWallet as the
        // limit; the token reports the per-token limit (9).
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWalletForTokenId
                    .selector,
                10,
                mintParams.maxTotalMintableByWalletPerToken + quantity,
                mintParams.maxTotalMintableByWalletPerToken
            )
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testCannotMintAfterExceedingMaxTokenSupplyForStage(uint256 feeBpsSeed)
        public
    {
        MintParams memory mintParams = _mintParams(feeBpsSeed);

        // Create the second minter that will call the transaction exceeding
        // the drop stage supply.
        address secondMinter = makeAddr("secondMinter");
        vm.deal(secondMinter, 100 ether);

        address[] memory minters = _addresses(minter, secondMinter);
        (bytes32 root, bytes32[] memory proof) =
            _allowListRootAndProof(minters, mintParams, 0);
        (, bytes32[] memory proofSecondMinter) =
            _allowListRootAndProof(minters, mintParams, 1);
        _updateAllowList(root);

        (AdvancedOrder memory order, uint256 value) = _order(
            mintParams.maxTotalMintableByWalletPerToken,
            feeRecipient,
            minter,
            mintParams,
            mintParams.feeBps,
            proof
        );

        // Mint the maxTotalMintableByWalletPerToken to the minter.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(minter, order, value);

        (order, value) = _order(
            mintParams.maxTotalMintableByWalletPerToken,
            feeRecipient,
            secondMinter,
            mintParams,
            mintParams.feeBps,
            proofSecondMinter
        );

        // Attempt to mint the maxTotalMintableByWalletPerToken to the second
        // minter, exceeding the drop stage supply.
        _expectPreviewRevert(
            secondMinter,
            order,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxTokenSupplyForStage.selector,
                2 * mintParams.maxTotalMintableByWalletPerToken,
                mintParams.maxTokenSupplyForStage
            )
        );
        _fulfillExpectingInvalidContractOrder(secondMinter, order, value);
    }

    function testCannotMintAfterExceedingMaxTokenSupply(uint256 feeBpsSeed)
        public
    {
        MintParams memory mintParams = _mintParams(feeBpsSeed);

        // Update the max supply.
        token.setMaxSupply(10, 10);

        // Create the second minter.
        address secondMinter = makeAddr("secondMinter");
        vm.deal(secondMinter, 100 ether);

        address[] memory minters = _addresses(minter, secondMinter);
        (bytes32 root, bytes32[] memory proof) =
            _allowListRootAndProof(minters, mintParams, 0);
        (, bytes32[] memory proofSecondMinter) =
            _allowListRootAndProof(minters, mintParams, 1);
        _updateAllowList(root);

        (AdvancedOrder memory order, uint256 value) = _order(
            mintParams.maxTotalMintableByWalletPerToken,
            feeRecipient,
            minter,
            mintParams,
            mintParams.feeBps,
            proof
        );

        // Mint the maxTotalMintableByWalletPerToken to the minter.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(minter, order, value);

        (order, value) = _order(
            1,
            feeRecipient,
            secondMinter,
            mintParams,
            mintParams.feeBps,
            proofSecondMinter
        );

        // NOTE: the spec comment names a max supply error, but this order
        // mints 1 more (9 + 1 = 10, within the max supply of 10) and is
        // fulfilled by `minter`, who is not an allowed payer for
        // secondMinter. So it fails with PayerNotAllowed, and the spec never
        // reaches the max supply check.
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(PayerNotAllowed.selector, minter)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testCannotMintWithUninitializedAllowList(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        (, bytes32[] memory proof) =
            _allowListRootAndProof(_addresses(minter), mintParams, 0);

        // We are skipping updating the allow list, the root should be zero.
        assertEq(seadropToken.getAllowListMerkleRoot(), bytes32(0));

        (AdvancedOrder memory order, uint256 value) = _order(
            quantity, feeRecipient, minter, mintParams, mintParams.feeBps, proof
        );

        _expectPreviewRevert(
            minter, order, abi.encodeWithSelector(InvalidProof.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);

        // Try with proof of zero.
        bytes32[] memory zeroProof = new bytes32[](1);
        (order, value) = _order(
            quantity,
            feeRecipient,
            minter,
            mintParams,
            mintParams.feeBps,
            zeroProof
        );

        _expectPreviewRevert(
            minter, order, abi.encodeWithSelector(InvalidProof.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testCannotMintWithFeeBpsAbove10000(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        MintParams memory mintParamsInvalidFeeBps = _mintParams(feeBpsSeed);
        mintParamsInvalidFeeBps.feeBps = 10_100;

        // The allow list is built from the invalid feeBps params...
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParamsInvalidFeeBps);

        // ...but, as in the spec, the order carries the valid mintParams.
        (AdvancedOrder memory order, uint256 value) = _order(
            quantity, feeRecipient, minter, mintParams, mintParams.feeBps, proof
        );

        // NOTE: the spec comment names InvalidFeeBps(10100), but the order's
        // mintParams don't match the allow list leaf, so it fails with
        // InvalidProof. testCannotMintWithFeeBpsOver10000 covers
        // InvalidFeeBps.
        _expectPreviewRevert(
            minter, order, abi.encodeWithSelector(InvalidProof.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testDelegatedPayerCanMint(uint256 feeBpsSeed) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);

        address payer = makeAddr("payer");
        vm.deal(payer, 100 ether);

        _setTwoCreatorPayouts(creator, owner);

        // Allow list mint.
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        (AdvancedOrder memory order, uint256 value) = _order(
            1, feeRecipient, minter, mintParams, mintParams.feeBps, proof
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

    function testPreviewOrderReturnsExpectedOfferAndConsideration(uint256 feeBpsSeed)
        public
    {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        (AdvancedOrder memory order,) = _order(
            1, feeRecipient, minter, mintParams, mintParams.feeBps, proof
        );

        _assertPreviewOrderMatches(minter, order);
    }

    function testCannotMintWithFeeBpsOver10000(uint256 feeBpsSeed) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        MintParams memory mintParamsFeeBpsOver10k = _mintParams(feeBpsSeed);
        mintParamsFeeBpsOver10k.feeBps = 10_001;

        (, bytes32[] memory proof) = _allowOnlyMinter(mintParamsFeeBpsOver10k);

        (AdvancedOrder memory order, uint256 value) = _order(
            1,
            feeRecipient,
            minter,
            mintParamsFeeBpsOver10k,
            mintParams.feeBps,
            proof
        );

        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(InvalidFeeBps.selector, 10_001)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testMintMultipleTokenIdsInSameOrder(uint256 feeBpsSeed) public {
        token.setMaxSupply(0, 1);
        token.setMaxSupply(1, 1);
        token.setMaxSupply(2, 1);
        token.setMaxSupply(3, 1);

        MintParams memory mintParams = _mintParams(feeBpsSeed);
        mintParams.fromTokenId = 0;
        mintParams.toTokenId = 3;
        mintParams.maxTotalMintableByWallet = 2;

        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        (AdvancedOrder memory order, uint256 value) = _allowListMintOrder(
            address(token),
            _pair(0, 1),
            _pair(1, 1),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            proof
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(minter, order, value);

        assertEq(token.balanceOf(minter, 0), 1);
        assertEq(token.balanceOf(minter, 1), 1);
        uint256[] memory balances =
            token.balanceOfBatch(_addresses(minter, minter), _pair(0, 1));
        assertEq(balances.length, 2);
        assertEq(balances[0], 1);
        assertEq(balances[1], 1);

        // Should revert if duplicate tokenIds are provided.
        (order, value) = _allowListMintOrder(
            address(token),
            _triple(0, 1, 1),
            _triple(1, 1, 1),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            proof
        );

        // NOTE: the spec comment names OfferContainsDuplicateTokenId, but
        // token id 0 is checked first and is already at its max supply of 1,
        // so the order fails with MintQuantityExceedsMaxSupply(2, 1) before
        // the duplicate id is reached.
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 2, 1)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);

        // Ensure we cannot exceed maxTotalMintableByWallet with the total
        // mint quantity. We have already minted 2 tokens.
        assertEq(token.balanceOf(minter, 2), 0);
        assertEq(token.balanceOf(minter, 3), 0);
        (order, value) = _allowListMintOrder(
            address(token),
            _pair(2, 3),
            _pair(1, 1),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            proof
        );

        // NOTE: the spec comment says withArgs(4, 2). The token checks each
        // non-final item on its own quantity, so token id 2 already fails
        // with (1 + 2 minted = 3, 2).
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector, 3, 2
            )
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);

        // Update maxTotalMintableByWallet to 4, the order should now succeed.
        mintParams.maxTotalMintableByWallet = 4;
        (, proof) = _allowOnlyMinter(mintParams);

        (order, value) = _allowListMintOrder(
            address(token),
            _pair(2, 3),
            _pair(1, 1),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            proof
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(minter, order, value);

        assertEq(token.balanceOf(minter, 2), 1);
        assertEq(token.balanceOf(minter, 3), 1);
    }
}
