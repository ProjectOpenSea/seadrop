// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { ERC721AllowListedDrop } from "primary-drops/ERC721AllowListedDrop.sol";
import { IERC721Drop } from "primary-drops/interfaces/IERC721Drop.sol";

import {
    IERC721AllowListedDrop
} from "primary-drops/interfaces/IERC721AllowListedDrop.sol";
import { DropEventsAndErrors } from "primary-drops/DropEventsAndErrors.sol";

contract ERC721AllowListedDropTest is Test, DropEventsAndErrors {
    ERC721AllowListedDrop test;
    mapping(address => uint256) privateKeys;
    mapping(bytes => address) seedAddresses;
    IERC721AllowListedDrop.AllowListMint mintData;
    bytes32[] EMPTY_BYTES32_ARRAY; // = new bytes32[](0);

    function setUp() public {
        test = new ERC721AllowListedDrop(
            "",
            "",
            IERC721Drop.PublicDrop({
                mintPrice: 1 ether,
                startTime: 0,
                endTime: type(uint64).max,
                maxMintsPerWallet: 10,
                maxMintsPerTransaction: 10,
                feeBps: 250
            }),
            address(0),
            address(42),
            bytes32(0),
            address(0),
            ""
        );

        mintData = IERC721AllowListedDrop.AllowListMint({
            option: 0,
            numToMint: 2,
            mintPrice: 1 ether,
            maxNumberMinted: 10,
            startTime: 0,
            endTime: type(uint64).max,
            allowListIndex: 0,
            feeBps: 250
        });

        test.setMerkleRoot(
            // set root to be the hash of this address + mint data, requiring no proof
            keccak256(abi.encode(address(this), mintData)),
            address(0),
            ""
        );
    }

    function makeAddr(bytes memory seed) public returns (address) {
        uint256 pk = uint256(keccak256(seed));
        address derived = vm.addr(pk);
        seedAddresses[seed] = derived;
        privateKeys[derived] = pk;
        return derived;
    }

    function testMintAllowList() public {
        IERC721AllowListedDrop.AllowListMint memory _mintData = mintData;

        test.mintAllowList{ value: 2 ether }(_mintData, EMPTY_BYTES32_ARRAY);
        assertEq(test.balanceOf(address(this)), 2);
    }

    function testMintAllowList_incorrectProof() public {
        IERC721AllowListedDrop.AllowListMint memory _mintData = mintData;
        _mintData.feeBps = 1;

        vm.expectRevert(
            abi.encodeWithSelector(ERC721AllowListedDrop.InvalidProof.selector)
        );
        test.mintAllowList{ value: 2 ether }(_mintData, EMPTY_BYTES32_ARRAY);
    }

    receive() external payable {}
}
