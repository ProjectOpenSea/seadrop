// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import {
    ERC721SeaDropSoulbound
} from "seadrop/extensions/ERC721SeaDropSoulbound.sol";

contract ERC721SeaDropSoulboundWithMint is ERC721SeaDropSoulbound {
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) ERC721SeaDropSoulbound(name, symbol, allowedSeaDrop) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract ERC721SeaDropSoulboundTest is TestHelper {
    ERC721SeaDropSoulboundWithMint token_;

    address greg = makeAddr("greg");

    function setUp() public {
        token_ = new ERC721SeaDropSoulboundWithMint("", "", new address[](0));
    }

    function testCannotSetApproval() public {
        token_.mint(address(this), 1);

        vm.expectRevert(
            ERC721SeaDropSoulbound.SoulboundNotTransferable.selector
        );
        token_.approve(greg, 1);

        vm.expectRevert(
            ERC721SeaDropSoulbound.SoulboundNotTransferable.selector
        );
        token_.setApprovalForAll(greg, true);
    }

    function testCannotTransfer() public {
        token_.mint(address(this), 1);

        vm.expectRevert(
            ERC721SeaDropSoulbound.SoulboundNotTransferable.selector
        );
        token_.transferFrom(address(this), greg, 1);

        vm.expectRevert(
            ERC721SeaDropSoulbound.SoulboundNotTransferable.selector
        );
        token_.safeTransferFrom(address(this), greg, 1);

        vm.expectRevert(
            ERC721SeaDropSoulbound.SoulboundNotTransferable.selector
        );
        token_.safeTransferFrom(address(this), greg, 1, "");
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
