// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    ITransferValidator721
} from "seadrop/interfaces/ITransferValidator.sol";

import { MockTransferValidator } from "seadrop/test/MockTransferValidator.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

contract ERC721SeaDropWithMint is ERC721SeaDrop {
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract ERC721TransferValidatorTest is TestHelper {
    MockTransferValidator transferValidatorAlwaysSucceeds =
        new MockTransferValidator(false);
    MockTransferValidator transferValidatorAlwaysReverts =
        new MockTransferValidator(true);

    ERC721SeaDropWithMint token_;

    event TransferValidatorUpdated(address oldValidator, address newValidator);

    function setUp() public {
        token_ = new ERC721SeaDropWithMint("", "", new address[](0));
    }

    function testOnlyOwnerCanSetTransferValidator() public {
        assertEq(token_.getTransferValidator(), address(0));

        vm.prank(address(token_));
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token_.setTransferValidator(address(transferValidatorAlwaysSucceeds));

        token_.setTransferValidator(address(transferValidatorAlwaysSucceeds));
        assertEq(
            token_.getTransferValidator(),
            address(transferValidatorAlwaysSucceeds)
        );
    }

    function testTransferValidatorIsCalledOnTransfer() public {
        token_.mint(address(this), 2);

        vm.expectEmit(true, true, true, true);
        emit TransferValidatorUpdated(
            address(0),
            address(transferValidatorAlwaysSucceeds)
        );
        token_.setTransferValidator(address(transferValidatorAlwaysSucceeds));
        token_.safeTransferFrom(address(this), msg.sender, 1);

        vm.expectEmit(true, true, true, true);
        emit TransferValidatorUpdated(
            address(transferValidatorAlwaysSucceeds),
            address(transferValidatorAlwaysReverts)
        );
        token_.setTransferValidator(address(transferValidatorAlwaysReverts));
        vm.expectRevert("MockTransferValidator: always reverts");
        token_.safeTransferFrom(address(this), msg.sender, 2);

        // When set to null address, transfer should succeed without calling the validator
        vm.expectEmit(true, true, true, true);
        emit TransferValidatorUpdated(
            address(transferValidatorAlwaysReverts),
            address(0)
        );
        token_.setTransferValidator(address(0));
        token_.safeTransferFrom(address(this), msg.sender, 2);
    }

    function testGetTransferValidationFunction() public {
        (bytes4 functionSignature, bool isViewFunction) = token_
            .getTransferValidationFunction();
        assertEq(
            functionSignature,
            ITransferValidator721.validateTransfer.selector
        );
        assertEq(isViewFunction, false);
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
