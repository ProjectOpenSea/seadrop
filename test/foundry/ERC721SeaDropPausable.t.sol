// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import {
    ERC721SeaDropPausable
} from "seadrop/extensions/ERC721SeaDropPausable.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

contract ERC721SeaDropPausableWithMint is ERC721SeaDropPausable {
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) ERC721SeaDropPausable(name, symbol, allowedSeaDrop) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract ERC721SeaDropSoulboundTest is TestHelper {
    ERC721SeaDropPausableWithMint token_;

    address greg = makeAddr("greg");

    function setUp() public {
        token_ = new ERC721SeaDropPausableWithMint("", "", new address[](0));
    }

    function testCannotSetApprovalWhenPaused() public {
        token_.mint(address(this), 1);

        vm.expectRevert(ERC721SeaDropPausable.TransfersPaused.selector);
        token_.approve(greg, 1);

        vm.expectRevert(ERC721SeaDropPausable.TransfersPaused.selector);
        token_.setApprovalForAll(greg, true);

        // Unpause transfers
        token_.updateTransfersPaused(false);

        // Now approval should succeed
        token_.approve(greg, 1);
        token_.setApprovalForAll(greg, true);
    }

    function testCannotTransferWhenPaused() public {
        token_.mint(address(this), 1);

        vm.expectRevert(ERC721SeaDropPausable.TransfersPaused.selector);
        token_.transferFrom(address(this), greg, 1);

        vm.expectRevert(ERC721SeaDropPausable.TransfersPaused.selector);
        token_.safeTransferFrom(address(this), greg, 1);

        vm.expectRevert(ERC721SeaDropPausable.TransfersPaused.selector);
        token_.safeTransferFrom(address(this), greg, 1, "");

        // Unpause transfers
        token_.updateTransfersPaused(false);

        // Now transfer should succeed
        token_.safeTransferFrom(address(this), greg, 1);
        assertEq(token_.ownerOf(1), greg);

        vm.prank(greg);
        token_.transferFrom(greg, address(this), 1);
    }

    function testOnlyOwnerCanSetPaused() public {
        // Ensure only the owner can pause transfers
        vm.prank(greg);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token_.updateTransfersPaused(false);

        // Ensure owner can toggle transfersPaused
        token_.updateTransfersPaused(false);
        assertEq(token_.transfersPaused(), false);

        token_.updateTransfersPaused(true);
        assertEq(token_.transfersPaused(), true);
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
