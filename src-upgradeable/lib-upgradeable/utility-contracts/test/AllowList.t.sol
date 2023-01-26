// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Test} from "forge-std/Test.sol";
import {AllowList} from "../src/AllowList.sol";
import {TwoStepOwnable} from "../src/TwoStepOwnable.sol";

contract AllowListImpl is AllowList(bytes32(0)) {
    function redeem(bytes32[] calldata _proof)
        external
        onlyAllowListed(_proof)
    {}
}

contract AllowListTest is Test {
    AllowListImpl list;
    bytes32[] proof;
    bytes32 root;

    function setUp() public {
        list = new AllowListImpl();
        root = bytes32(
            0x0e3c89b8f8b49ac3672650cebf004f2efec487395927033a7de99f85aec9387c
        );
        list.setMerkleRoot(root);
        ///@notice this proof assumes DAPP_TEST_ADDRESS is its default value, 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84
        proof = [
            bytes32(
                0x042a8fd902455b847ec9e1fc2b056c101d23fcb859025672809c57e41981b518
            ),
            bytes32(
                0x9280e7972fa86597b2eadadce706966b57123d3c9ec8da4ba4a4ad94da59f6bf
            ),
            bytes32(
                0xfd669bf3d776ba18645619d460a223f8354d8efa5369f99805c2164fd9e63504
            )
        ];
    }

    function testUpdateRoot() public {
        assertEq(root, list.merkleRoot());
        list.setMerkleRoot(bytes32(0));
        assertEq(bytes32(0), list.merkleRoot());
    }

    function testOnlyOwnerCanUpdateRoot() public {
        list.transferOwnership(address(1));
        vm.prank(address(1));
        list.acceptOwnership();
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        list.setMerkleRoot(bytes32(0));
    }

    function testIsAllowListed() public {
        assertTrue(list.isAllowListed(proof, abi.encodePacked(address(this))));
        assertTrue(list.isAllowListed(proof, address(this)));
    }

    function testIsAllowListedModifierReverts() public {
        list.setMerkleRoot(0);
        vm.expectRevert(abi.encodeWithSignature("NotAllowListed()"));
        list.redeem(proof);
    }
}
