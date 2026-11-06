// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721MintHelpers } from "./utils/SeaDrop721MintHelpers.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { MintParams } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @dev Port of test/ERC721SeaDrop-mintAllowList.spec.ts.
 *      The test contract deploys the token, so it plays the spec's `owner`.
 *      The spec draws feeBps from [1, 10_000) in beforeEach and quantities
 *      with randomInt; here they are fuzzed over the same ranges.
 *      Where the spec can only see Seaport's InvalidContractOrder, the inner
 *      SeaDrop error is also asserted through previewOrder (see
 *      _assertMintReverts). Where it differs from the error named in the
 *      spec's comment, the test says why.
 */
contract ERC721SeaDropMintAllowListTest is SeaDrop721MintHelpers {
    address creator = makeAddr("creator");
    address minter = makeAddr("minter");
    address feeRecipient = makeAddr("feeRecipient");

    MintParams mintParams;

    function setUp() public override {
        super.setUp();

        token = new ERC721SeaDrop(
            address(configurer),
            allowedSeaport,
            "Test721",
            "T721"
        );

        vm.deal(address(this), 100 ether);
        vm.deal(minter, 100 ether);

        // Update the fee recipient and creator payout address for the token.
        token.setMaxSupply(1000);
        IERC721SeaDrop(address(token)).updateAllowedFeeRecipient(
            feeRecipient,
            true
        );
        setSingleCreatorPayout(creator);

        // Set the allow list mint params. feeBps is set per test.
        mintParams = MintParams({
            startPrice: 0.1 ether,
            endPrice: 0.1 ether,
            startTime: block.timestamp - 1000,
            endTime: block.timestamp + 1000,
            paymentToken: address(0),
            maxTotalMintableByWallet: 10,
            maxTokenSupplyForStage: 11,
            dropStageIndex: 1,
            feeBps: 0,
            restrictFeeRecipients: true
        });
    }

    /// @dev feeBps = randomInt(1, 10_000) in the spec's beforeEach.
    function _mintParamsWithFeeBps(
        uint256 feeBpsSeed
    ) internal returns (MintParams memory) {
        mintParams.feeBps = bound(feeBpsSeed, 1, 9_999);
        return mintParams;
    }

    /// @dev quantity = randomInt(1, maxTotalMintableByWallet) in the spec.
    function _quantity(uint256 quantitySeed) internal view returns (uint256) {
        return bound(quantitySeed, 1, mintParams.maxTotalMintableByWallet - 1);
    }

    function _order(
        address tokenAddress,
        uint256 quantity,
        address orderFeeRecipient,
        address orderMinter,
        MintParams memory params,
        bytes32[] memory proof
    ) internal view returns (AdvancedOrder memory, uint256) {
        return
            _allowListOrder(
                tokenAddress,
                quantity,
                orderFeeRecipient,
                mintParams.feeBps,
                params.startPrice,
                orderMinter,
                params,
                proof
            );
    }

    function _twoMinterAllowList(
        address secondMinter,
        MintParams memory params
    )
        internal
        returns (
            bytes32 root,
            bytes32[] memory proof,
            bytes32[] memory proofSecondMinter
        )
    {
        address[] memory minters = new address[](2);
        minters[0] = minter;
        minters[1] = secondMinter;
        (root, proof) = _createAllowListAndGetProof(minters, params, 0);
        (, proofSecondMinter) = _createAllowListAndGetProof(
            minters,
            params,
            1
        );
    }

    /// @dev "Should mint to a minter on the allow list"
    function testMintAllowList(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            params
        );

        // Update the allow list of the token.
        _updateAllowList(address(token), root);

        // Mint the allow list stage to the minter and verify the expected
        // event was emitted.
        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            quantity,
            feeRecipient,
            minter,
            params,
            proof
        );
        _fulfillAndExpectMint(order, minter, value, params.dropStageIndex);
    }

    /// @dev "Should mint a free mint allow list stage"
    function testMintFreeAllowListStage(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        // Create mintParams with a price of 0.
        MintParams memory freeParams = _copyMintParams(params);
        freeParams.startPrice = 0;
        freeParams.endPrice = 0;

        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            freeParams
        );
        _updateAllowList(address(token), root);

        assertEq(IERC721SeaDrop(address(token)).getAllowListMerkleRoot(), root);

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            quantity,
            feeRecipient,
            minter,
            freeParams,
            proof
        );
        _fulfillAndExpectMint(order, minter, value, params.dropStageIndex);
    }

    /// @dev "Should mint an allow list stage with a different payer than
    ///      minter"
    function testMintAllowListWithDifferentPayer(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            params
        );
        _updateAllowList(address(token), root);

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            quantity,
            feeRecipient,
            minter,
            params,
            proof
        );

        // The payer (the spec's owner) needs to be allowed first.
        _assertMintReverts(
            order,
            address(this),
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, address(this))
        );

        // Allow the payer.
        IERC721SeaDrop(address(token)).updatePayer(address(this), true);

        // Mint an allow list stage with a different payer than minter.
        _fulfillAndExpectMint(
            order,
            address(this),
            value,
            params.dropStageIndex
        );
    }

    /// @dev "Should revert if the minter is not on the allow list"
    function testCannotMintIfNotOnAllowList(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            params
        );
        _updateAllowList(address(token), root);

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            quantity,
            feeRecipient,
            minter,
            params,
            proof
        );

        address nonMinter = makeAddr("nonMinter");
        vm.deal(nonMinter, 100 ether);

        // The spec comments InvalidProof, but this order names `minter`, so
        // the proof verifies; nonMinter fails as a payer that is neither
        // allowed nor delegated.
        _assertMintReverts(
            order,
            nonMinter,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, nonMinter)
        );

        // With a zero minter the minter becomes the fulfiller (nonMinter),
        // who is not on the allow list.
        (order, value) = _order(
            address(token),
            quantity,
            feeRecipient,
            address(0),
            params,
            proof
        );
        _assertMintReverts(
            order,
            nonMinter,
            value,
            abi.encodeWithSelector(InvalidProof.selector)
        );
    }

    /// @dev "Should not mint an allow list stage with an unknown fee
    ///      recipient"
    function testCannotMintWithUnknownFeeRecipient(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            params
        );
        _updateAllowList(address(token), root);

        address invalidFeeRecipient = makeAddr("invalidFeeRecipient");

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            quantity,
            invalidFeeRecipient,
            minter,
            params,
            proof
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                FeeRecipientNotAllowed.selector,
                invalidFeeRecipient
            )
        );
    }

    /// @dev "Should not mint an allow list stage with a different token
    ///      contract"
    function testCannotMintWithDifferentTokenContract(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            params
        );
        _updateAllowList(address(token), root);

        // Deploy a new ERC721SeaDrop.
        ERC721SeaDrop differentToken = new ERC721SeaDrop(
            address(configurer),
            allowedSeaport,
            "Test721",
            "T721"
        );

        // Update the fee recipient and creator payout address for the new
        // token.
        differentToken.setMaxSupply(1000);
        IERC721SeaDrop(address(differentToken)).updateAllowedFeeRecipient(
            feeRecipient,
            true
        );
        _setSingleCreatorPayout(address(differentToken), creator);

        (AdvancedOrder memory order, uint256 value) = _order(
            address(differentToken),
            quantity,
            feeRecipient,
            minter,
            params,
            proof
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidProof.selector)
        );
    }

    /// @dev "Should not mint an allow list stage with different mint params"
    function testCannotMintWithDifferentMintParams(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            params
        );
        _updateAllowList(address(token), root);

        // Create different mint params to include in the mint.
        MintParams memory differentParams = _copyMintParams(params);
        differentParams.feeBps = params.feeBps + 100;

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            quantity,
            feeRecipient,
            minter,
            differentParams,
            proof
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidProof.selector)
        );
    }

    /// @dev "Should not mint an allow list stage after exceeding max mints
    ///      per wallet"
    function testCannotMintAfterExceedingMaxMintsPerWallet(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);
        // quantity = randomInt(1, maxTotalMintableByWallet - 1) in the spec.
        uint256 quantity = bound(
            quantitySeed,
            1,
            params.maxTotalMintableByWallet - 2
        );

        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            params
        );
        _updateAllowList(address(token), root);

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            quantity,
            feeRecipient,
            minter,
            params,
            proof
        );

        // Mint the allow list stage to the minter and verify the expected
        // event was emitted.
        _fulfillAndExpectMint(order, minter, value, params.dropStageIndex);

        // Attempt to mint maxTotalMintableByWallet to the minter.
        (order, value) = _order(
            address(token),
            params.maxTotalMintableByWallet,
            feeRecipient,
            minter,
            params,
            proof
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector,
                params.maxTotalMintableByWallet + quantity,
                params.maxTotalMintableByWallet
            )
        );
    }

    /// @dev "Should not mint an allow list stage after exceeding max token
    ///      supply for stage"
    function testCannotMintAfterExceedingMaxTokenSupplyForStage(
        uint256 feeBpsSeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);

        // Create the second minter that will call the transaction exceeding
        // the drop stage supply.
        address secondMinter = makeAddr("secondMinter");
        vm.deal(secondMinter, 100 ether);

        (
            bytes32 root,
            bytes32[] memory proof,
            bytes32[] memory proofSecondMinter
        ) = _twoMinterAllowList(secondMinter, params);

        // Update the allow list of the token.
        _updateAllowList(address(token), root);

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            params.maxTotalMintableByWallet,
            feeRecipient,
            minter,
            params,
            proof
        );

        // Mint the maxTotalMintableByWallet to the minter and verify the
        // expected event was emitted.
        _fulfillAndExpectMint(order, minter, value, params.dropStageIndex);

        (order, value) = _order(
            address(token),
            params.maxTotalMintableByWallet,
            feeRecipient,
            secondMinter,
            params,
            proofSecondMinter
        );

        // Attempt to mint the maxTotalMintableByWallet to the second minter,
        // exceeding the drop stage supply.
        _assertMintReverts(
            order,
            secondMinter,
            value,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxTokenSupplyForStage.selector,
                2 * params.maxTotalMintableByWallet,
                params.maxTokenSupplyForStage
            )
        );
    }

    /// @dev "Should not mint an allow list stage after exceeding max token
    ///      supply"
    function testCannotMintAfterExceedingMaxTokenSupply(
        uint256 feeBpsSeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);

        // Update the max supply.
        token.setMaxSupply(10);

        // Create the second minter that will call the transaction exceeding
        // the token max supply.
        address secondMinter = makeAddr("secondMinter");
        vm.deal(secondMinter, 100 ether);

        (
            bytes32 root,
            bytes32[] memory proof,
            bytes32[] memory proofSecondMinter
        ) = _twoMinterAllowList(secondMinter, params);

        // Update the allow list of the token.
        _updateAllowList(address(token), root);

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            10,
            feeRecipient,
            minter,
            params,
            proof
        );

        // Mint 10 to the minter and verify the expected event was emitted.
        _fulfillAndExpectMint(order, minter, value, params.dropStageIndex);

        (order, value) = _order(
            address(token),
            1,
            feeRecipient,
            secondMinter,
            params,
            proofSecondMinter
        );

        // The spec fulfills the second minter's order from `minter` and
        // comments QuantityExceedsMaxTokenSupply, but the payer check runs
        // before the supply check, so the inner error is PayerNotAllowed.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, minter)
        );

        // The spec's intent: the second minter minting for themselves
        // exceeds the token max supply.
        _assertMintReverts(
            order,
            secondMinter,
            value,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxSupply.selector,
                11,
                10
            )
        );
    }

    /// @dev "Should not mint with an uninitialized AllowList"
    function testCannotMintWithUninitializedAllowList(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        (, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            params
        );

        // We are skipping updating the allow list, the root should be zero.
        assertEq(
            IERC721SeaDrop(address(token)).getAllowListMerkleRoot(),
            bytes32(0)
        );

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            quantity,
            feeRecipient,
            minter,
            params,
            proof
        );

        // Mint the allow list stage.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidProof.selector)
        );

        // Try with proof of zero.
        bytes32[] memory zeroProof = new bytes32[](1);
        (order, value) = _order(
            address(token),
            quantity,
            feeRecipient,
            minter,
            params,
            zeroProof
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidProof.selector)
        );
    }

    /// @dev "Should not mint with feeBps > 10_000"
    function testCannotMintWithFeeBpsAbove10000(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        MintParams memory invalidFeeBpsParams = _copyMintParams(params);
        invalidFeeBpsParams.feeBps = 10_100;

        // Encode the minter address and mintParams.
        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            invalidFeeBpsParams
        );

        // Update the allow list of the token.
        _updateAllowList(address(token), root);

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            quantity,
            feeRecipient,
            minter,
            params,
            proof
        );

        // The spec comments InvalidFeeBps(10100), but its order carries the
        // valid mintParams, whose leaf is not under the root built from the
        // 10_100 params, so the inner error is InvalidProof.
        // InvalidFeeBps(10_001) is covered by
        // testCannotMintWithFeeBpsOver10000.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidProof.selector)
        );
    }

    /// @dev "Should allow delegated payers to mint via the DelegationRegistry"
    function testDelegatedPayerCanMint(uint256 feeBpsSeed) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);

        address payer = makeAddr("payer");
        vm.deal(payer, 100 ether);

        _setCreatorPayouts(address(token), creator, 5_000, address(this), 5_000);

        // Allow list mint.
        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            params
        );
        _updateAllowList(address(token), root);

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            1,
            feeRecipient,
            minter,
            params,
            proof
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
    function testPreviewOrder(uint256 feeBpsSeed) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);

        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            params
        );
        _updateAllowList(address(token), root);

        (AdvancedOrder memory order, ) = _order(
            address(token),
            1,
            feeRecipient,
            minter,
            params,
            proof
        );

        _assertPreviewOrderEchoesOrder(order, minter);
    }

    /// @dev "Should not allow feeBps over 10_000"
    function testCannotMintWithFeeBpsOver10000(uint256 feeBpsSeed) public {
        MintParams memory params = _mintParamsWithFeeBps(feeBpsSeed);

        MintParams memory feeBpsOver10kParams = _copyMintParams(
            params
        );
        feeBpsOver10kParams.feeBps = 10_001;

        (bytes32 root, bytes32[] memory proof) = _createAllowListAndGetProof(
            minter,
            feeBpsOver10kParams
        );

        // Update the allow list of the token.
        _updateAllowList(address(token), root);

        (AdvancedOrder memory order, uint256 value) = _order(
            address(token),
            1,
            feeRecipient,
            minter,
            feeBpsOver10kParams,
            proof
        );

        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidFeeBps.selector, 10_001)
        );
    }
}
