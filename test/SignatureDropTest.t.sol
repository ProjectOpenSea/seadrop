// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {SignatureDrop} from "primary-drops/SignatureDrop.sol";

contract SignatureDropTest is Test {
    SignatureDrop test;
    mapping(address => uint256) privateKeys;
    mapping(bytes => address) seedAddresses;

    function setUp() public {
        address signer = makeAddr("signer");
        address badSigner = makeAddr("bad signer");
        vm.label(signer, "Signer");
        vm.label(badSigner, "Bad Signer");
        test = new SignatureDrop("", "", 10, address(this), signer);
    }

    function makeAddr(bytes memory seed) public returns (address) {
        uint256 pk = uint256(keccak256(seed));
        address derived = vm.addr(pk);
        seedAddresses[seed] = derived;
        privateKeys[derived] = pk;
        return derived;
    }

    function getSignatureComponents(
        address signer,
        address caller,
        SignatureDrop.MintData memory mintData
    )
        internal
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        uint256 pk = privateKeys[signer];
        if (pk == 0) {
            revert("Signer not found");
        }
        bytes32 mintDataTypeHash = test.MINT_DATA_TYPEHASH();
        bytes32 structHash = keccak256(
            abi.encode(
                mintDataTypeHash,
                caller,
                mintData.allowList,
                mintData.mintPrice,
                mintData.maxNumberMinted,
                mintData.startTimestamp,
                mintData.endTimestamp,
                mintData.feeBps
            )
        );
        (v, r, s) = vm.sign(
            pk,
            keccak256(
                abi.encodePacked(
                    bytes2(0x1901),
                    test.DOMAIN_SEPARATOR(),
                    structHash
                )
            )
        );
    }

    function test_snapshotValidSignatureBoilerplate() public {
        SignatureDrop.MintData memory mintData = SignatureDrop.MintData(
            true,
            0,
            10,
            0,
            type(uint256).max,
            0
        );
        (bytes32 r, bytes32 s, uint8 v) = getSignatureComponents(
            seedAddresses["signer"],
            address(this),
            mintData
        );
        bytes memory signature = abi.encodePacked(r, s, v);
    }

    function test_snapshotValidSignature() public {
        SignatureDrop.MintData memory mintData = SignatureDrop.MintData(
            true,
            0,
            10,
            0,
            type(uint256).max,
            0
        );
        (bytes32 r, bytes32 s, uint8 v) = getSignatureComponents(
            seedAddresses["signer"],
            address(this),
            mintData
        );
        bytes memory signature = abi.encodePacked(r, s, v);
        test.mint(1, mintData, signature);
    }

    function testSignature_invalid() public {
        SignatureDrop.MintData memory mintData = SignatureDrop.MintData(
            true,
            0,
            10,
            0,
            type(uint256).max,
            0
        );
        (bytes32 r, bytes32 s, uint8 v) = getSignatureComponents(
            seedAddresses["bad signer"],
            address(this),
            mintData
        );
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.expectRevert(
            abi.encodeWithSelector(
                SignatureDrop.InvalidSignature.selector,
                seedAddresses["bad signer"],
                seedAddresses["signer"]
            )
        );
        test.mint(1, mintData, signature);
    }
}
