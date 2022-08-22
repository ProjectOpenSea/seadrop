// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { MintParams } from "seadrop/lib/SeaDropStructs.sol";

import {
    ECDSA
} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract ERC721DropTest is TestHelper {
    using ECDSA for bytes32;

    struct FuzzInputsSigners {
        address payer;
        address minter;
        uint40 numMints;
        address feeRecipient;
        string signerNameSeed;
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
        vm.assume(args.minter != address(0));
        _;
    }

    function setUp() public {
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", address(this), allowedSeaDrop);

        // Set the max supply to 1000.
        token.setMaxSupply(1000);

        // Set the creator payout address.
        token.updateCreatorPayoutAddress(address(seadrop), creator);
    }

    function _getSignatureComponents(
        string memory name,
        address minter,
        MintParams memory mintParams
    )
        internal
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        (, uint256 pk) = makeAddrAndKey(name);
        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                _DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        _MINT_DATA_TYPEHASH,
                        minter,
                        mintParams.mintPrice,
                        mintParams.maxTotalMintableByWallet,
                        mintParams.startTime,
                        mintParams.endTime,
                        mintParams.dropStageIndex,
                        mintParams.feeBps,
                        mintParams.restrictFeeRecipients
                    )
                )
            )
        );
        (v, r, s) = vm.sign(pk, digest);
    }

    function _deriveDomainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(seadrop)
            )
        );
    }

    function testMintSigned(FuzzInputsSigners memory args)
        public
        validateFuzzInputsSigners(args)
    {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint64(block.timestamp), // start time
            uint64(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Get the signature components.
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            args.signerNameSeed,
            args.minter,
            mintParams
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Imperonate the token contract to update the signers.
        vm.prank(address(token));

        // Update the approved signers of the token contract.
        address[] memory signers = new address[](1);
        signers[0] = makeAddr(args.signerNameSeed);
        seadrop.updateSigners(signers);

        hoax(args.payer, 100 ether);

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * mintParams.mintPrice;

        seadrop.mintSigned{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints,
            mintParams,
            signature
        );

        assertEq(token.balanceOf(args.minter), args.numMints);
    }
}
// testMintSigned
// testMintSigned_unknownSigner
// testMintSigned_differentPayerThanMinter
// testMintSigned_freeMint
// testMintSigned_revertFeeRecipientNotAllowed
