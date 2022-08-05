// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { SeaDrop } from "primary-drops/SeaDrop.sol";
import { ERC721SeaDrop } from "primary-drops/ERC721SeaDrop.sol";
import { IERC721SeaDrop } from "primary-drops/interfaces/IERC721SeaDrop.sol";
import {
    SeaDropErrorsAndEvents
} from "primary-drops/lib/SeaDropErrorsAndEvents.sol";
import { PublicDrop } from "primary-drops/lib/SeaDropStructs.sol";

contract ERC721DropTest is Test, SeaDropErrorsAndEvents {
    SeaDrop seadrop;
    ERC721SeaDrop test;
    mapping(address => uint256) privateKeys;
    mapping(bytes => address) seedAddresses;

    struct FuzzInputs {
        uint40 numMints;
        address minter;
        address feeRecipient;
    }

    modifier validateArgs(FuzzInputs memory args) {
        vm.assume(args.numMints > 0 && args.numMints <= 10);
        vm.assume(args.minter != address(0) && args.feeRecipient != address(0));
        _;
    }

    function setUp() public {
        // Deploy SeaDrop.
        seadrop = new SeaDrop();

        // Deploy test ERC721SeaDrop.
        test = new ERC721SeaDrop("", "", address(this), address(seadrop));

        // Create public drop object.
        PublicDrop memory publicDrop = PublicDrop(
            0.1 ether, // mint price
            uint64(block.timestamp), // start time
            10, // max mints per wallet
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Impersonate test erc721 contract.
        vm.prank(address(test));

        // Update the public drop for the erc721 contract.
        seadrop.updatePublicDrop(publicDrop);
    }

    function makeAddr(bytes memory seed) public returns (address) {
        uint256 pk = uint256(keccak256(seed));
        address derived = vm.addr(pk);
        seedAddresses[seed] = derived;
        privateKeys[derived] = pk;
        return derived;
    }

    function testMintSeaDrop(FuzzInputs memory args) public validateArgs(args) {
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(test));

        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        vm.prank(args.minter);
        seadrop.mintPublic{ value: mintValue }(
            address(test),
            args.feeRecipient,
            args.numMints
        );
        assertEq(test.balanceOf(args.minter), args.numMints);
    }

    // function testPublicMint_incorrectPayment() public {
    //     vm.expectRevert(
    //         abi.encodeWithSelector(IncorrectPayment.selector, 1, 2 ether)
    //     );
    //     test.publicMint{ value: 1 wei }(2);
    // }

    receive() external payable {}
}
