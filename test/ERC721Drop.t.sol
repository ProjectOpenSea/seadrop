// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import { ERC721Drop } from "primary-drops/ERC721Drop.sol";
// import { IERC721Drop } from "primary-drops/interfaces/IERC721Drop.sol";
// import { DropEventsAndErrors } from "primary-drops/DropEventsAndErrors.sol";

// contract ERC721DropTest is Test, DropEventsAndErrors {
//     ERC721Drop test;
//     mapping(address => uint256) privateKeys;
//     mapping(bytes => address) seedAddresses;

//     function setUp() public {
//         test = new ERC721Drop(
//             "",
//             "",
//             address(42),
//             IERC721Drop.PublicDrop({
//                 mintPrice: 1 ether,
//                 startTime: 0,
//                 endTime: type(uint64).max,
//                 maxMintsPerWallet: 10,
//                 maxMintsPerTransaction: 10,
//                 feeBps: 250
//             }),
//             address(0)
//         );
//     }

//     function makeAddr(bytes memory seed) public returns (address) {
//         uint256 pk = uint256(keccak256(seed));
//         address derived = vm.addr(pk);
//         seedAddresses[seed] = derived;
//         privateKeys[derived] = pk;
//         return derived;
//     }

//     function testPublicMint() public {
//         test.publicMint{ value: 1 ether }(1);
//         assertEq(test.balanceOf(address(this)), 1);
//         test.publicMint{ value: 2 ether }(2);
//     }

//     function testPublicMint_incorrectPayment() public {
//         vm.expectRevert(
//             abi.encodeWithSelector(IncorrectPayment.selector, 1, 2 ether)
//         );
//         test.publicMint{ value: 1 wei }(2);
//     }

//     receive() external payable {}
// }
