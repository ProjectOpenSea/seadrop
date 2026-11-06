// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { SeaDrop } from "seadrop/SeaDrop.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { AllowListData, MintParams } from "seadrop/lib/SeaDropStructs.sol";

import { Merkle } from "murky/Merkle.sol";

contract ERC721DropTest is TestHelper {
    modifier validateAllowList(FuzzInputs memory args) {
        for (uint256 i = 0; i < 10; i++) {
            vm.assume(
                args.allowList[i] != address(0)
                    && args.allowList[i] != args.feeRecipient
                    && args.allowList[i] != creator
                    && args.allowList[i] != args.minter
            );
        }
        _;
    }

    function setUp() public {
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", allowedSeaDrop);

        // Set the max supply to 1000.
        token.setMaxSupply(1000);

        // Set the creator payout address.
        token.updateCreatorPayoutAddress(address(seadrop), creator);
    }

    function _createMerkleRootAndProof(
        address[10] memory allowList,
        uint256 proofIndex,
        MintParams memory mintParams
    ) internal returns (bytes32 root, bytes32[] memory proof) {
        require(proofIndex < allowList.length);

        // Declare a bytes32 array for the allowlist tuples.
        bytes32[] memory allowListTuples = new bytes32[](allowList.length);

        // Create allowList tuples using allowList addresses and mintParams.
        for (uint256 i = 0; i < allowList.length; i++) {
            allowListTuples[i] = keccak256(abi.encode(allowList[i], mintParams));
        }

        // Initialize Merkle.
        Merkle m = new Merkle();

        // Get the merkle root of the allowlist tuples.
        root = m.getRoot(allowListTuples);

        // Get the merkle proof of the tuple at proofIndex.
        proof = m.getProof(allowListTuples, proofIndex);

        // Verify that the merkle root can be obtained from the proof.
        bool verified = m.verifyProof(root, proof, allowListTuples[proofIndex]);
        assertTrue(verified);
    }

    function testMintAllowList(FuzzInputs memory args)
        public
        validateArgs(args)
        validateAllowList(args)
    {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        (bytes32 root, bytes32[] memory proof) =
            _createMerkleRootAndProof(args.allowList, 0, mintParams);

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData =
            AllowListData(root, emptyStringArray, "test");

        vm.prank(address(token));

        // Set the allow list of the token contract.
        seadrop.updateAllowList(allowListData);

        uint256 mintValue = args.numMints * mintParams.mintPrice;

        // Mint a token to the first address of the allowList.
        hoax(args.allowList[0], 100 ether);
        seadrop.mintAllowList{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.allowList[0],
            args.numMints,
            mintParams,
            proof
        );

        assertEq(token.balanceOf(args.allowList[0]), args.numMints);
    }

    function testMintAllowList_revertUnauthorizedMinter(FuzzInputs memory args)
        public
        validateArgs(args)
        validateAllowList(args)
    {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        bytes32[] memory allowListTuples = new bytes32[](10);

        // Create allowList tuples using allowList addresses and mintParams.
        for (uint256 i = 0; i < 10; i++) {
            allowListTuples[i] =
                keccak256(abi.encode(args.allowList[i], mintParams));
        }

        (bytes32 root, bytes32[] memory proof) =
            _createMerkleRootAndProof(args.allowList, 0, mintParams);

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData =
            AllowListData(root, emptyStringArray, "test");

        vm.prank(address(token));

        // Set the allow list of the token contract.
        seadrop.updateAllowList(allowListData);

        uint256 mintValue = args.numMints * mintParams.mintPrice;

        hoax(args.minter, 100 ether);

        vm.expectRevert(abi.encodeWithSelector(InvalidProof.selector));

        // Attempt to mint a token to a non-allowlist address.
        seadrop.mintAllowList{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter, // fuzzed minter is not on allowList
            args.numMints,
            mintParams,
            proof
        );
    }

    function testMintAllowList_revertInvalidProof(FuzzInputs memory args)
        public
        validateArgs(args)
        validateAllowList(args)
    {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        bytes32[] memory allowListTuples = new bytes32[](10);

        // Create allowList tuples using allowList addresses and mintParams.
        for (uint256 i = 0; i < 10; i++) {
            allowListTuples[i] =
                keccak256(abi.encode(args.allowList[i], mintParams));
        }

        (bytes32 root, bytes32[] memory proof) =
            _createMerkleRootAndProof(args.allowList, 0, mintParams);

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData =
            AllowListData(root, emptyStringArray, "test");

        vm.prank(address(token));

        // Set the allow list of the token contract.
        seadrop.updateAllowList(allowListData);

        uint256 mintValue = args.numMints * mintParams.mintPrice;

        // Allow the payer.
        token.updatePayer(address(seadrop), args.allowList[0], true);
        hoax(args.allowList[0], 100 ether);

        // Proof refers to address at allowList[0], so assume
        // it is not the same address as minting for allowList[4]
        vm.assume(args.allowList[0] != args.allowList[4]);

        // Expect the subsequent call to mintAllowList to revert with error
        // InvalidProof
        vm.expectRevert(abi.encodeWithSelector(InvalidProof.selector));

        // Attempt to mint a token to allowList[4]
        // with a proof for allowList[0].
        seadrop.mintAllowList{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.allowList[4], // proof refers to address at allowList[0]
            args.numMints,
            mintParams,
            proof
        );
    }

    function testMintAllowList_revertFeeRecipientCannotBeZeroAddress(FuzzInputs memory args)
        public
        validateArgs(args)
        validateAllowList(args)
    {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        bytes32[] memory allowListTuples = new bytes32[](10);

        // Create allowList tuples using allowList addresses and mintParams.
        for (uint256 i = 0; i < 10; i++) {
            allowListTuples[i] =
                keccak256(abi.encode(args.allowList[i], mintParams));
        }

        (bytes32 root, bytes32[] memory proof) =
            _createMerkleRootAndProof(args.allowList, 0, mintParams);

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData =
            AllowListData(root, emptyStringArray, "test");

        vm.prank(address(token));

        // Set the allow list of the token contract.
        seadrop.updateAllowList(allowListData);

        uint256 mintValue = args.numMints * mintParams.mintPrice;

        hoax(args.allowList[0], 100 ether);

        // Expect the subsequent call to mintAllowList to revert with error
        // FeeRecipientCannotBeZeroAddress
        vm.expectRevert(
            abi.encodeWithSelector(FeeRecipientCannotBeZeroAddress.selector)
        );

        // Attempt to call mintAllowList with the zero address as the fee recipient.
        seadrop.mintAllowList{ value: mintValue }(
            address(token),
            address(0),
            args.allowList[0],
            args.numMints,
            mintParams,
            proof
        );
    }

    function testMintAllowList_revertFeeRecipientNotAllowed(FuzzInputs memory args)
        public
        validateArgs(args)
        validateAllowList(args)
    {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            true // if true, only allowed fee recipients
        );

        bytes32[] memory allowListTuples = new bytes32[](10);

        // Create allowList tuples using allowList addresses and mintParams.
        for (uint256 i = 0; i < 10; i++) {
            allowListTuples[i] =
                keccak256(abi.encode(args.allowList[i], mintParams));
        }

        (bytes32 root, bytes32[] memory proof) =
            _createMerkleRootAndProof(args.allowList, 0, mintParams);

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData =
            AllowListData(root, emptyStringArray, "test");

        vm.prank(address(token));

        // Set the allow list of the token contract.
        seadrop.updateAllowList(allowListData);

        uint256 mintValue = args.numMints * mintParams.mintPrice;

        hoax(args.allowList[0], 100 ether);

        // Expect the subsequent call to mintAllowList to revert with error
        // FeeRecipientNotAllowed
        vm.expectRevert(abi.encodeWithSelector(FeeRecipientNotAllowed.selector));

        // Attempt to call mintAllowList with an unauthorized fee recipient.
        seadrop.mintAllowList{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.allowList[0],
            args.numMints,
            mintParams,
            proof
        );
    }

    function testMintAllowList_revertMintQuantityExceedsMaxMintedPerWallet(FuzzInputs memory args)
        public
        validateArgs(args)
        validateAllowList(args)
    {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        bytes32[] memory allowListTuples = new bytes32[](10);

        // Create allowList tuples using allowList addresses and mintParams.
        for (uint256 i = 0; i < 10; i++) {
            allowListTuples[i] =
                keccak256(abi.encode(args.allowList[i], mintParams));
        }

        (bytes32 root, bytes32[] memory proof) =
            _createMerkleRootAndProof(args.allowList, 0, mintParams);

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData =
            AllowListData(root, emptyStringArray, "test");

        vm.prank(address(token));

        // Set the allow list of the token contract.
        seadrop.updateAllowList(allowListData);

        uint256 mintValue = 100 * mintParams.mintPrice;

        hoax(args.allowList[0], 100 ether);

        // Expect the subsequent call to mintAllowList to revert with error
        // MintQuantityExceedsMaxMintedPerWallet
        vm.expectRevert(
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector,
                100,
                mintParams.maxTotalMintableByWallet
            )
        );

        // Attempt to mint more than the maxTotalMintableByWallet.
        seadrop.mintAllowList{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.allowList[0],
            100,
            mintParams,
            proof
        );
    }

    function testMintAllowList_freeMint(FuzzInputs memory args)
        public
        validateArgs(args)
        validateAllowList(args)
    {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0 ether, // mint price (free)
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        bytes32[] memory allowListTuples = new bytes32[](10);

        // Create allowList tuples using allowList addresses and mintParams.
        for (uint256 i = 0; i < 10; i++) {
            allowListTuples[i] =
                keccak256(abi.encode(args.allowList[i], mintParams));
        }

        (bytes32 root, bytes32[] memory proof) =
            _createMerkleRootAndProof(args.allowList, 0, mintParams);

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData =
            AllowListData(root, emptyStringArray, "test");

        vm.prank(address(token));

        // Set the allow list of the token contract.
        seadrop.updateAllowList(allowListData);

        hoax(args.allowList[0], 100 ether);

        // Attempt to mint more than the maxTotalMintableByWallet.
        seadrop.mintAllowList(
            address(token),
            args.feeRecipient,
            args.allowList[0],
            args.numMints,
            mintParams,
            proof
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.allowList[0]), args.numMints);
    }
}

/// @dev Allow list mint scenarios against a fully configured token: max
///      supply 1000, creator payout set, one allowed fee recipient, and
///      mint params that restrict fee recipients. The Hardhat spec picked a
///      random fee bps and mint quantity per run; both are fuzzed here.
contract SeaDropMintAllowListScenarioTest is TestHelper {
    address minter = makeAddr("minter");
    address feeRecipient = makeAddr("feeRecipient");

    MintParams mintParams;

    function setUp() public {
        // Use a realistic timestamp so stage start times in the past are
        // representable.
        vm.warp(1_700_000_000);

        vm.deal(minter, 10_000 ether);

        // Deploy the ERC721SeaDrop token. The test contract is the owner.
        token = _deployToken();

        // Set the allow list mint params. The fee bps is set per test.
        mintParams = MintParams(
            10000000000000, // mint price
            10, // max mints per wallet
            block.timestamp - 100, // start time
            block.timestamp + 100, // end time
            1, // drop stage index
            11, // max token supply for stage
            0, // fee bps (set per test)
            true // restrict fee recipients
        );
    }

    /// @dev Set a fee bps between 1 and 9_999, as the Hardhat spec did.
    modifier withFeeBps(uint256 feeBps) {
        mintParams.feeBps = bound(feeBps, 1, 9_999);
        _;
    }

    function _deployToken() internal returns (ERC721SeaDrop newToken) {
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        newToken = new ERC721SeaDrop("", "", allowedSeaDrop);

        // Update the fee recipient and creator payout address for the token.
        newToken.setMaxSupply(1000);
        newToken.updateAllowedFeeRecipient(address(seadrop), feeRecipient, true);
        newToken.updateCreatorPayoutAddress(address(seadrop), creator);
    }

    /// @dev Set a mint quantity between 1 and 9, as the Hardhat spec did.
    function _mintQuantity(uint256 seed) internal pure returns (uint256) {
        return bound(seed, 1, 9);
    }

    function _leaf(address minter_, MintParams memory params)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(minter_, params));
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b
            ? keccak256(abi.encodePacked(a, b))
            : keccak256(abi.encodePacked(b, a));
    }

    function _proof(bytes32 sibling) internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = sibling;
        return proof;
    }

    /// @dev Store a single-leaf allow list for `minter_` and return the
    ///      (empty) proof. The root of a single-leaf tree is the leaf.
    function _setSingleLeafAllowList(address minter_, MintParams memory params)
        internal
        returns (bytes32 root, bytes32[] memory proof)
    {
        root = _leaf(minter_, params);
        proof = new bytes32[](0);
        _setAllowList(root);
    }

    function _setAllowList(bytes32 root) internal {
        token.updateAllowList(
            address(seadrop), AllowListData(root, new string[](0), "")
        );
    }

    function _expectSeaDropMint(
        address minter_,
        address payer,
        uint256 quantity,
        MintParams memory params
    ) internal {
        vm.expectEmit(true, true, true, true, address(seadrop));
        emit SeaDropMint(
            address(token),
            minter_,
            feeRecipient,
            payer,
            quantity,
            params.mintPrice,
            params.feeBps,
            params.dropStageIndex
        );
    }

    function testMintAllowList_emitsSeaDropMint(
        uint256 feeBps,
        uint256 quantitySeed
    ) public withFeeBps(feeBps) {
        uint256 mintQuantity = _mintQuantity(quantitySeed);
        MintParams memory params = mintParams;
        (, bytes32[] memory proof) = _setSingleLeafAllowList(minter, params);

        uint256 value = params.mintPrice * mintQuantity;

        _expectSeaDropMint(minter, minter, mintQuantity, params);
        vm.prank(minter);
        seadrop.mintAllowList{ value: value }(
            address(token), feeRecipient, minter, mintQuantity, params, proof
        );
    }

    function testMintAllowList_freeMintEmitsSeaDropMint(
        uint256 feeBps,
        uint256 quantitySeed
    ) public withFeeBps(feeBps) {
        // Create mint params with a mint price of 0.
        MintParams memory params = mintParams;
        params.mintPrice = 0;

        uint256 mintQuantity = _mintQuantity(quantitySeed);
        (bytes32 root, bytes32[] memory proof) =
            _setSingleLeafAllowList(minter, params);

        assertEq(seadrop.getAllowListMerkleRoot(address(token)), root);

        _expectSeaDropMint(minter, minter, mintQuantity, params);
        vm.prank(minter);
        seadrop.mintAllowList(
            address(token),
            feeRecipient,
            address(0),
            mintQuantity,
            params,
            proof
        );
    }

    function testMintAllowList_differentPayerThanMinter(
        uint256 feeBps,
        uint256 quantitySeed
    ) public withFeeBps(feeBps) {
        uint256 mintQuantity = _mintQuantity(quantitySeed);
        MintParams memory params = mintParams;
        (, bytes32[] memory proof) = _setSingleLeafAllowList(minter, params);

        uint256 value = params.mintPrice * mintQuantity;

        // The payer (the owner, this contract) needs to be allowed first.
        vm.expectRevert(PayerNotAllowed.selector);
        seadrop.mintAllowList{ value: value }(
            address(token), feeRecipient, minter, mintQuantity, params, proof
        );

        // Allow the payer.
        token.updatePayer(address(seadrop), address(this), true);

        // Mint an allow list stage with a different payer than minter.
        _expectSeaDropMint(minter, address(this), mintQuantity, params);
        seadrop.mintAllowList{ value: value }(
            address(token), feeRecipient, minter, mintQuantity, params, proof
        );
    }

    function testMintAllowList_revertMinterNotOnAllowList(
        uint256 feeBps,
        uint256 quantitySeed
    ) public withFeeBps(feeBps) {
        uint256 mintQuantity = _mintQuantity(quantitySeed);
        MintParams memory params = mintParams;
        (, bytes32[] memory proof) = _setSingleLeafAllowList(minter, params);

        uint256 value = params.mintPrice * mintQuantity;

        address nonMinter = makeAddr("nonMinter");
        vm.deal(nonMinter, 10_000 ether);

        vm.prank(nonMinter);
        vm.expectRevert(InvalidProof.selector);
        seadrop.mintAllowList{ value: value }(
            address(token), feeRecipient, nonMinter, mintQuantity, params, proof
        );

        vm.prank(nonMinter);
        vm.expectRevert(InvalidProof.selector);
        seadrop.mintAllowList{ value: value }(
            address(token),
            feeRecipient,
            address(0),
            mintQuantity,
            params,
            proof
        );
    }

    function testMintAllowList_revertDifferentTokenContract(
        uint256 feeBps,
        uint256 quantitySeed
    ) public withFeeBps(feeBps) {
        uint256 mintQuantity = _mintQuantity(quantitySeed);
        MintParams memory params = mintParams;
        (, bytes32[] memory proof) = _setSingleLeafAllowList(minter, params);

        uint256 value = params.mintPrice * mintQuantity;

        // Deploy and configure a new ERC721SeaDrop.
        ERC721SeaDrop differentToken = _deployToken();

        vm.prank(minter);
        vm.expectRevert(InvalidProof.selector);
        seadrop.mintAllowList{ value: value }(
            address(differentToken),
            feeRecipient,
            address(0),
            mintQuantity,
            params,
            proof
        );
    }

    function testMintAllowList_revertDifferentMintParams(
        uint256 feeBps,
        uint256 quantitySeed
    ) public withFeeBps(feeBps) {
        uint256 mintQuantity = _mintQuantity(quantitySeed);
        MintParams memory params = mintParams;
        (, bytes32[] memory proof) = _setSingleLeafAllowList(minter, params);

        // Create different mint params to include in the mint.
        MintParams memory differentMintParams = mintParams;
        differentMintParams.feeBps = params.feeBps + 100;

        uint256 value = params.mintPrice * mintQuantity;

        vm.prank(minter);
        vm.expectRevert(InvalidProof.selector);
        seadrop.mintAllowList{ value: value }(
            address(token),
            feeRecipient,
            minter,
            mintQuantity,
            differentMintParams,
            proof
        );
    }

    function testMintAllowList_revertExceedsMaxMintsPerWallet(
        uint256 feeBps,
        uint256 quantitySeed
    ) public withFeeBps(feeBps) {
        // Set a mint quantity between 1 and maxTotalMintableByWallet - 2.
        uint256 mintQuantity = bound(quantitySeed, 1, 8);
        MintParams memory params = mintParams;
        (, bytes32[] memory proof) = _setSingleLeafAllowList(minter, params);

        uint256 value = params.mintPrice * mintQuantity;

        _expectSeaDropMint(minter, minter, mintQuantity, params);
        vm.prank(minter);
        seadrop.mintAllowList{ value: value }(
            address(token), feeRecipient, minter, mintQuantity, params, proof
        );

        uint256 maxTotalMintableByWalletMintValue =
            params.mintPrice * params.maxTotalMintableByWallet;

        // Attempt to mint the maxTotalMintableByWallet to the minter.
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector,
                params.maxTotalMintableByWallet + mintQuantity,
                params.maxTotalMintableByWallet
            )
        );
        seadrop.mintAllowList{ value: maxTotalMintableByWalletMintValue }(
            address(token),
            feeRecipient,
            minter,
            params.maxTotalMintableByWallet,
            params,
            proof
        );
    }

    /// @dev Set up a two-leaf allow list for `minter` and `secondMinter`.
    function _setTwoLeafAllowList(
        address secondMinter,
        MintParams memory params
    )
        internal
        returns (
            bytes32[] memory proofMinter,
            bytes32[] memory proofSecondMinter
        )
    {
        bytes32 leafMinter = _leaf(minter, params);
        bytes32 leafSecondMinter = _leaf(secondMinter, params);
        _setAllowList(_hashPair(leafMinter, leafSecondMinter));
        proofMinter = _proof(leafSecondMinter);
        proofSecondMinter = _proof(leafMinter);
    }

    function testMintAllowList_revertExceedsMaxTokenSupplyForStage(uint256 feeBps)
        public
        withFeeBps(feeBps)
    {
        // Create the second minter that will call the transaction exceeding
        // the drop stage supply.
        address secondMinter = makeAddr("secondMinter");
        vm.deal(secondMinter, 10_000 ether);

        MintParams memory params = mintParams;
        (bytes32[] memory proofMinter, bytes32[] memory proofSecondMinter) =
            _setTwoLeafAllowList(secondMinter, params);

        uint256 maxTotalMintableByWalletMintValue =
            params.mintPrice * params.maxTotalMintableByWallet;

        // Mint the maxTotalMintableByWallet to the minter.
        _expectSeaDropMint(
            minter, minter, params.maxTotalMintableByWallet, params
        );
        vm.prank(minter);
        seadrop.mintAllowList{ value: maxTotalMintableByWalletMintValue }(
            address(token),
            feeRecipient,
            minter,
            params.maxTotalMintableByWallet,
            params,
            proofMinter
        );

        // Attempt to mint the maxTotalMintableByWallet to the second minter,
        // exceeding the drop stage supply.
        vm.prank(secondMinter);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintQuantityExceedsMaxTokenSupplyForStage.selector,
                2 * params.maxTotalMintableByWallet,
                params.maxTokenSupplyForStage
            )
        );
        seadrop.mintAllowList{ value: maxTotalMintableByWalletMintValue }(
            address(token),
            feeRecipient,
            secondMinter,
            params.maxTotalMintableByWallet,
            params,
            proofSecondMinter
        );
    }

    function testMintAllowList_revertExceedsMaxSupply(uint256 feeBps)
        public
        withFeeBps(feeBps)
    {
        // Update the max supply.
        token.setMaxSupply(11);

        // Create the second minter that will call the transaction exceeding
        // the max supply.
        address secondMinter = makeAddr("secondMinter");
        vm.deal(secondMinter, 10_000 ether);

        MintParams memory params = mintParams;
        (bytes32[] memory proofMinter, bytes32[] memory proofSecondMinter) =
            _setTwoLeafAllowList(secondMinter, params);

        uint256 maxTotalMintableByWalletMintValue =
            params.mintPrice * params.maxTotalMintableByWallet;

        // Mint the maxTotalMintableByWallet to the minter.
        _expectSeaDropMint(
            minter, minter, params.maxTotalMintableByWallet, params
        );
        vm.prank(minter);
        seadrop.mintAllowList{ value: maxTotalMintableByWalletMintValue }(
            address(token),
            feeRecipient,
            minter,
            params.maxTotalMintableByWallet,
            params,
            proofMinter
        );

        // Attempt to mint the maxTotalMintableByWallet to the second minter,
        // exceeding the max supply.
        vm.prank(secondMinter);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintQuantityExceedsMaxSupply.selector,
                2 * params.maxTotalMintableByWallet,
                11
            )
        );
        seadrop.mintAllowList{ value: maxTotalMintableByWalletMintValue }(
            address(token),
            feeRecipient,
            secondMinter,
            params.maxTotalMintableByWallet,
            params,
            proofSecondMinter
        );
    }

    function testMintAllowList_revertUninitializedAllowList(
        uint256 feeBps,
        uint256 quantitySeed
    ) public withFeeBps(feeBps) {
        uint256 mintQuantity = _mintQuantity(quantitySeed);
        MintParams memory params = mintParams;

        // The proof for a single-leaf tree is empty. The allow list is not
        // updated, so the root should be zero.
        bytes32[] memory proof = new bytes32[](0);
        assertEq(seadrop.getAllowListMerkleRoot(address(token)), bytes32(0));

        uint256 value = params.mintPrice * mintQuantity;

        vm.prank(minter);
        vm.expectRevert(InvalidProof.selector);
        seadrop.mintAllowList{ value: value }(
            address(token), feeRecipient, minter, mintQuantity, params, proof
        );

        // Try with a proof of zero.
        vm.prank(minter);
        vm.expectRevert(InvalidProof.selector);
        seadrop.mintAllowList{ value: value }(
            address(token),
            feeRecipient,
            minter,
            mintQuantity,
            params,
            _proof(bytes32(0))
        );
    }

    function testMintAllowList_revertFeeBpsAboveMax(
        uint256 feeBps,
        uint256 quantitySeed
    ) public withFeeBps(feeBps) {
        uint256 mintQuantity = _mintQuantity(quantitySeed);
        MintParams memory params = mintParams;
        params.feeBps = 10_100;
        (, bytes32[] memory proof) = _setSingleLeafAllowList(minter, params);

        uint256 value = params.mintPrice * mintQuantity;

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(InvalidFeeBps.selector, 10_100));
        seadrop.mintAllowList{ value: value }(
            address(token), feeRecipient, minter, mintQuantity, params, proof
        );
    }
}
