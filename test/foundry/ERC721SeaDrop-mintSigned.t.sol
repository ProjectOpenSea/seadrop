// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { SeaDrop } from "seadrop/SeaDrop.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { PublicDrop, MintParams } from "seadrop/lib/SeaDropStructs.sol";

import {
    ECDSA
} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract ERC721DropTest is TestHelper {
    using ECDSA for bytes32;

    struct FuzzInputsSigners {
        address caller;
        uint40 numMints;
        address feeRecipient;
        string[2] nameSeeds;
    }

    /// @notice Internal constants for EIP-712: Typed structured
    ///         data hashing and signing
    bytes32 internal constant _MINT_DATA_TYPEHASH =
        keccak256(
            "MintParams(address minter,uint256 mintPrice,uint256 maxTotalMintableByWallet,uint256 startTime,uint256 endTime,uint256 dropStageIndex,uint256 feeBps,bool restrictFeeRecipients)"
        );
    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
    bytes32 internal constant _NAME_HASH = keccak256("SeaDrop");
    bytes32 internal constant _VERSION_HASH = keccak256("1.0");
    uint256 internal immutable _CHAIN_ID = block.chainid;
    bytes32 internal immutable _DOMAIN_SEPARATOR = _deriveDomainSeparator();

    modifier validateFuzzInputsSigners(FuzzInputsSigners memory args) {
        vm.assume(args.numMints > 0 && args.numMints <= 10);
        vm.assume(
            args.feeRecipient.code.length == 0 && args.feeRecipient > address(9)
        );
        // vm.assume(bytes(args.nameSeeds[0]) != bytes(args.nameSeeds[1]));
        vm.assume(
            args.caller != args.feeRecipient &&
                args.caller != creator &&
                args.feeRecipient != creator
        );
        _;
    }

    function setUp() public {
        // Deploy SeaDrop.
        seadrop = new SeaDrop();

        // Deploy test ERC721SeaDrop.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", address(this), allowedSeaDrop);

        // Set maxSupply to 1000.
        token.setMaxSupply(1000);

        // Set creator payout address.
        token.updateCreatorPayoutAddress(address(seadrop), creator);

        // Create public drop object.
        PublicDrop memory publicDrop = PublicDrop(
            0.1 ether, // mint price
            uint64(block.timestamp), // start time
            10, // max mints per wallet
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Impersonate test erc721 contract.
        vm.prank(address(token));

        // Set the public drop for the erc721 contract.
        seadrop.updatePublicDrop(publicDrop);
    }

    function getSignatureComponents(
        string memory name,
        address caller,
        MintParams memory mintParams
    )
        internal
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v,
            bytes32 structHash
        )
    {
        (address signer, uint256 pk) = makeAddrAndKey(name);
        bytes32 mintDataTypeHash = _MINT_DATA_TYPEHASH;
        structHash = keccak256(
            abi.encode(
                mintDataTypeHash,
                caller,
                mintParams.mintPrice,
                mintParams.maxTotalMintableByWallet,
                mintParams.startTime,
                mintParams.endTime,
                mintParams.dropStageIndex,
                mintParams.feeBps,
                mintParams.restrictFeeRecipients
            )
        );
        (v, r, s) = vm.sign(
            pk,
            keccak256(
                abi.encodePacked(bytes2(0x1901), _DOMAIN_SEPARATOR, structHash)
            )
        );
    }

    function _deriveDomainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    function testMintSigned(FuzzInputsSigners memory args)
        public
        validateFuzzInputsSigners(args)
    {
        uint256 numSigners = args.nameSeeds.length;

        // Get the PublicDrop data for the test ERC721SeaDrop.
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(token));

        // Create a MintParams object with the PublicDrop object.
        MintParams memory mintParams = MintParams(
            publicDrop.mintPrice,
            publicDrop.maxMintsPerWallet,
            publicDrop.startTime,
            publicDrop.startTime + 1000,
            1,
            1000,
            publicDrop.feeBps,
            publicDrop.restrictFeeRecipients
        );

        bytes[] memory signatures = new bytes[](numSigners);

        address[] memory signers = new address[](numSigners);

        address[] memory minters = new address[](numSigners);

        for (uint256 i = 0; i < numSigners; i++) {
            string memory name = args.nameSeeds[i];

            // Create minter address.
            address minter = makeAddr(name);

            // Get signature components.
            (
                bytes32 r,
                bytes32 s,
                uint8 v,
                bytes32 structHash
            ) = getSignatureComponents(name, minter, mintParams);

            // Create the signature from the components.
            bytes memory signature = abi.encodePacked(r, s, v);

            signatures[i] = signature;

            // Use the recover method to see what address was used to create
            // the signature on this data.
            address recoveredAddress = structHash.recover(signature);

            assertEq(signers[i], recoveredAddress);

            // Add the recovered address to the array.
            signers[i] = recoveredAddress;
        }

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * mintParams.mintPrice;

        // Set the test erc721 contract as msg.sender of the subsequent call to update the signers.
        vm.prank(address(token));

        // Update the approved signers of the test erc721 contract.
        seadrop.updateSigners(signers);

        hoax(args.caller, 100 ether);

        for (uint256 i = 0; i < numSigners; i++) {
            // Mint a token to the address at index i of the allowList.
            seadrop.mintSigned{ value: mintValue }(
                address(token),
                args.feeRecipient,
                minters[i],
                args.numMints,
                mintParams,
                signatures[i]
            );

            assertEq(token.balanceOf(minters[i]), args.numMints);
        }
    }
}
// testMintSigned
// testMintSigned_unknownSigner
// testMintSigned_differentPayerThanMinter
// testMintSigned_freeMint
// testMintSigned_revertFeeRecipientNotAllowed
