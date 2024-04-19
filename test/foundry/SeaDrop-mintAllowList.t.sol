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
                args.allowList[i] != address(0) &&
                    args.allowList[i] != args.feeRecipient &&
                    args.allowList[i] != creator &&
                    args.allowList[i] != args.minter
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
            allowListTuples[i] = keccak256(
                abi.encode(allowList[i], mintParams)
            );
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

        (bytes32 root, bytes32[] memory proof) = _createMerkleRootAndProof(
            args.allowList,
            0,
            mintParams
        );

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData = AllowListData(
            root,
            emptyStringArray,
            "test"
        );

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
            allowListTuples[i] = keccak256(
                abi.encode(args.allowList[i], mintParams)
            );
        }

        (bytes32 root, bytes32[] memory proof) = _createMerkleRootAndProof(
            args.allowList,
            0,
            mintParams
        );

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData = AllowListData(
            root,
            emptyStringArray,
            "test"
        );

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
            allowListTuples[i] = keccak256(
                abi.encode(args.allowList[i], mintParams)
            );
        }

        (bytes32 root, bytes32[] memory proof) = _createMerkleRootAndProof(
            args.allowList,
            0,
            mintParams
        );

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData = AllowListData(
            root,
            emptyStringArray,
            "test"
        );

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

    function testMintAllowList_revertFeeRecipientCannotBeZeroAddress(
        FuzzInputs memory args
    ) public validateArgs(args) validateAllowList(args) {
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
            allowListTuples[i] = keccak256(
                abi.encode(args.allowList[i], mintParams)
            );
        }

        (bytes32 root, bytes32[] memory proof) = _createMerkleRootAndProof(
            args.allowList,
            0,
            mintParams
        );

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData = AllowListData(
            root,
            emptyStringArray,
            "test"
        );

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

    function testMintAllowList_revertFeeRecipientNotAllowed(
        FuzzInputs memory args
    ) public validateArgs(args) validateAllowList(args) {
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
            allowListTuples[i] = keccak256(
                abi.encode(args.allowList[i], mintParams)
            );
        }

        (bytes32 root, bytes32[] memory proof) = _createMerkleRootAndProof(
            args.allowList,
            0,
            mintParams
        );

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData = AllowListData(
            root,
            emptyStringArray,
            "test"
        );

        vm.prank(address(token));

        // Set the allow list of the token contract.
        seadrop.updateAllowList(allowListData);

        uint256 mintValue = args.numMints * mintParams.mintPrice;

        hoax(args.allowList[0], 100 ether);

        // Expect the subsequent call to mintAllowList to revert with error
        // FeeRecipientNotAllowed
        vm.expectRevert(
            abi.encodeWithSelector(FeeRecipientNotAllowed.selector)
        );

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

    function testMintAllowList_revertMintQuantityExceedsMaxMintedPerWallet(
        FuzzInputs memory args
    ) public validateArgs(args) validateAllowList(args) {
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
            allowListTuples[i] = keccak256(
                abi.encode(args.allowList[i], mintParams)
            );
        }

        (bytes32 root, bytes32[] memory proof) = _createMerkleRootAndProof(
            args.allowList,
            0,
            mintParams
        );

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData = AllowListData(
            root,
            emptyStringArray,
            "test"
        );

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
            allowListTuples[i] = keccak256(
                abi.encode(args.allowList[i], mintParams)
            );
        }

        (bytes32 root, bytes32[] memory proof) = _createMerkleRootAndProof(
            args.allowList,
            0,
            mintParams
        );

        // Create an empty string array to pass into allowListData.
        string[] memory emptyStringArray;

        // Create allowListData with the merkle root of the allowlist tuples.
        AllowListData memory allowListData = AllowListData(
            root,
            emptyStringArray,
            "test"
        );

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
