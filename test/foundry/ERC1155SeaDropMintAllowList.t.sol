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

/**
 * @dev Allow list (SIP-12 substandard 1) mints of token id 10. The fee bps
 *      and quantities are fuzzed. Failed mints assert both Seaport's
 *      InvalidContractOrder and the SeaDrop error behind it.
 */
contract ERC1155SeaDropMintAllowListTest is SeaDrop1155Test {
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
        token = _deployToken();
        token.setMaxSupply(10, 1000);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);
        _setSingleCreatorPayout(address(token), creator);
    }

    /// @dev Allow list mint params for token id 10 with a fuzzed feeBps.
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

    /// @dev A quantity below maxTotalMintableByWalletPerToken (9).
    function _quantity(uint256 quantitySeed) internal pure returns (uint256) {
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
            _uints(10),
            _uints(quantity),
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
        (root, proof) = _allowListRootAndProof(_addrs(minter), mintParams, 0);
        _updateAllowList(address(token), root);
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
        _fulfill(order, minter, value);
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
        assertEq(_seaDrop().getAllowListMerkleRoot(), root);

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
        _fulfill(order, minter, value);
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
        _assertMintReverts(
            order,
            owner,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, owner)
        );

        // Allow the payer.
        _seaDrop().updatePayer(owner, true);

        // Mint an allow list stage with a different payer than minter.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(owner, mintParams.dropStageIndex);
        _fulfill(order, owner, value);
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

        // The order names `minter`, whose proof is valid, so it fails
        // because nonMinter is not an allowed payer for minter.
        _assertMintReverts(
            order,
            nonMinter,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, nonMinter)
        );

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

        _assertMintReverts(
            order,
            nonMinter,
            value,
            abi.encodeWithSelector(InvalidProof.selector)
        );
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

        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                FeeRecipientNotAllowed.selector, invalidFeeRecipient
            )
        );
    }

    function testCannotMintWithDifferentTokenContract(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        // Deploy a new ERC1155SeaDrop.
        ERC1155SeaDrop differentToken = _deployToken();

        // Update the fee recipient and creator payout address for the new
        // token.
        differentToken.setMaxSupply(10, 1000);
        IERC1155SeaDrop(address(differentToken))
            .updateAllowedFeeRecipient(feeRecipient, true);
        _setSingleCreatorPayout(address(differentToken), creator);

        (AdvancedOrder memory order, uint256 value) = _allowListMintOrder(
            address(differentToken),
            _uints(0),
            _uints(quantity),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            proof
        );

        _assertMintReverts(
            order, minter, value, abi.encodeWithSelector(InvalidProof.selector)
        );
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

        _assertMintReverts(
            order, minter, value, abi.encodeWithSelector(InvalidProof.selector)
        );
    }

    function testCannotMintAfterExceedingMaxMintsPerWallet(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        // A quantity below maxTotalMintableByWalletPerToken - 1.
        uint256 quantity = bound(quantitySeed, 1, 7);
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        (AdvancedOrder memory order, uint256 value) = _order(
            quantity, feeRecipient, minter, mintParams, mintParams.feeBps, proof
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(order, minter, value);

        // Attempt to mint maxTotalMintableByWalletPerToken to the minter.
        (order, value) = _order(
            mintParams.maxTotalMintableByWalletPerToken,
            feeRecipient,
            minter,
            mintParams,
            mintParams.feeBps,
            proof
        );

        // The per-token limit (9) is checked before the wallet limit (10).
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWalletForTokenId
                    .selector,
                10,
                mintParams.maxTotalMintableByWalletPerToken + quantity,
                mintParams.maxTotalMintableByWalletPerToken
            )
        );
    }

    function testCannotMintAfterExceedingMaxTokenSupplyForStage(uint256 feeBpsSeed)
        public
    {
        MintParams memory mintParams = _mintParams(feeBpsSeed);

        // Create the second minter that will call the transaction exceeding
        // the drop stage supply.
        address secondMinter = makeAddr("secondMinter");
        vm.deal(secondMinter, 100 ether);

        address[] memory minters = _addrs(minter, secondMinter);
        (bytes32 root, bytes32[] memory proof) =
            _allowListRootAndProof(minters, mintParams, 0);
        (, bytes32[] memory proofSecondMinter) =
            _allowListRootAndProof(minters, mintParams, 1);
        _updateAllowList(address(token), root);

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
        _fulfill(order, minter, value);

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
        _assertMintReverts(
            order,
            secondMinter,
            value,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxTokenSupplyForStage.selector,
                2 * mintParams.maxTotalMintableByWalletPerToken,
                mintParams.maxTokenSupplyForStage
            )
        );
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

        address[] memory minters = _addrs(minter, secondMinter);
        (bytes32 root, bytes32[] memory proof) =
            _allowListRootAndProof(minters, mintParams, 0);
        (, bytes32[] memory proofSecondMinter) =
            _allowListRootAndProof(minters, mintParams, 1);
        _updateAllowList(address(token), root);

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
        _fulfill(order, minter, value);

        (order, value) = _order(
            1,
            feeRecipient,
            secondMinter,
            mintParams,
            mintParams.feeBps,
            proofSecondMinter
        );

        // `minter` is not an allowed payer for secondMinter.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, minter)
        );

        // Fulfilled by secondMinter, 9 + 2 exceeds the max supply of 10.
        (order, value) = _order(
            2,
            feeRecipient,
            secondMinter,
            mintParams,
            mintParams.feeBps,
            proofSecondMinter
        );
        _assertMintReverts(
            order,
            secondMinter,
            value,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxSupply.selector, 11, 10
            )
        );
    }

    function testCannotMintWithUninitializedAllowList(
        uint256 feeBpsSeed,
        uint256 quantitySeed
    ) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        uint256 quantity = _quantity(quantitySeed);

        (, bytes32[] memory proof) =
            _allowListRootAndProof(_addrs(minter), mintParams, 0);

        // We are skipping updating the allow list, the root should be zero.
        assertEq(_seaDrop().getAllowListMerkleRoot(), bytes32(0));

        (AdvancedOrder memory order, uint256 value) = _order(
            quantity, feeRecipient, minter, mintParams, mintParams.feeBps, proof
        );

        _assertMintReverts(
            order, minter, value, abi.encodeWithSelector(InvalidProof.selector)
        );

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

        _assertMintReverts(
            order, minter, value, abi.encodeWithSelector(InvalidProof.selector)
        );
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

        // ...but the order carries the valid mintParams.
        (AdvancedOrder memory order, uint256 value) = _order(
            quantity, feeRecipient, minter, mintParams, mintParams.feeBps, proof
        );

        // The order's mintParams don't match the allow list leaf, so it fails
        // with InvalidProof. testCannotMintWithFeeBpsOver10000 covers
        // InvalidFeeBps.
        _assertMintReverts(
            order, minter, value, abi.encodeWithSelector(InvalidProof.selector)
        );
    }

    function testDelegatedPayerCanMint(uint256 feeBpsSeed) public {
        MintParams memory mintParams = _mintParams(feeBpsSeed);

        address payer = makeAddr("payer");
        vm.deal(payer, 100 ether);

        _seaDrop().updateCreatorPayouts(_payouts(creator, 5_000, owner, 5_000));

        // Allow list mint.
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        (AdvancedOrder memory order, uint256 value) = _order(
            1, feeRecipient, minter, mintParams, mintParams.feeBps, proof
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

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(payer, mintParams.dropStageIndex);
        _fulfill(order, payer, value);

        // Remove delegation.
        vm.prank(minter);
        DELEGATION_REGISTRY.delegateForAll(payer, false);
    }

    function testPreviewOrderReturnsExpectedOfferAndConsideration(uint256 feeBpsSeed)
        public
    {
        MintParams memory mintParams = _mintParams(feeBpsSeed);
        (, bytes32[] memory proof) = _allowOnlyMinter(mintParams);

        (AdvancedOrder memory order,) = _order(
            1, feeRecipient, minter, mintParams, mintParams.feeBps, proof
        );

        _assertPreviewOrderMatches(order, minter);
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

        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidFeeBps.selector, 10_001)
        );
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
            _uints(0, 1),
            _uints(1, 1),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            proof
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(order, minter, value);

        assertEq(token.balanceOf(minter, 0), 1);
        assertEq(token.balanceOf(minter, 1), 1);
        uint256[] memory balances =
            token.balanceOfBatch(_addrs(minter, minter), _uints(0, 1));
        assertEq(balances.length, 2);
        assertEq(balances[0], 1);
        assertEq(balances[1], 1);

        // Should revert if duplicate tokenIds are provided.
        (order, value) = _allowListMintOrder(
            address(token),
            _uints(0, 1, 1),
            _uints(1, 1, 1),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            proof
        );

        // Token id 0 is checked first and is already at its max supply of 1,
        // so the order fails with MintQuantityExceedsMaxSupply(2, 1) before
        // the duplicate id is reached.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 2, 1)
        );

        // Ensure we cannot exceed maxTotalMintableByWallet with the total
        // mint quantity. We have already minted 2 tokens.
        assertEq(token.balanceOf(minter, 2), 0);
        assertEq(token.balanceOf(minter, 3), 0);
        (order, value) = _allowListMintOrder(
            address(token),
            _uints(2, 3),
            _uints(1, 1),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            proof
        );

        // Token id 2 already brings the wallet to 1 + 2 minted = 3 > 2.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector, 3, 2
            )
        );

        // Update maxTotalMintableByWallet to 4, the order should now succeed.
        mintParams.maxTotalMintableByWallet = 4;
        (, proof) = _allowOnlyMinter(mintParams);

        (order, value) = _allowListMintOrder(
            address(token),
            _uints(2, 3),
            _uints(1, 1),
            feeRecipient,
            mintParams.feeBps,
            mintParams.startPrice,
            minter,
            mintParams,
            proof
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, mintParams.dropStageIndex);
        _fulfill(order, minter, value);

        assertEq(token.balanceOf(minter, 2), 1);
        assertEq(token.balanceOf(minter, 3), 1);
    }
}
