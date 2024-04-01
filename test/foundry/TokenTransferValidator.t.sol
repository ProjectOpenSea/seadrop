// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721Test } from "./utils/SeaDrop721Test.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import {
    ITransferValidator721,
    ITransferValidator1155
} from "seadrop/interfaces/ITransferValidator.sol";

import { MockTransferValidator } from "seadrop/test/MockTransferValidator.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

contract ERC721SeaDropWithMint is ERC721SeaDrop {
    constructor(
        address allowedConfigurer,
        address allowedSeaport,
        string memory name,
        string memory symbol
    ) ERC721SeaDrop(allowedConfigurer, allowedSeaport, name, symbol) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract ERC1155SeaDropWithMint is ERC1155SeaDrop {
    constructor(
        address allowedConfigurer,
        address allowedSeaport,
        string memory name_,
        string memory symbol_
    ) ERC1155SeaDrop(allowedConfigurer, allowedSeaport, name_, symbol_) {}

    function mint(address to, uint256 id, uint256 amount) public onlyOwner {
        _mint(to, id, amount, "");
    }
}

contract TokenTransferValidatorTest is SeaDrop721Test {
    MockTransferValidator transferValidatorAlwaysSucceeds =
        new MockTransferValidator(false);
    MockTransferValidator transferValidatorAlwaysReverts =
        new MockTransferValidator(true);

    ERC721SeaDropWithMint token721;
    ERC1155SeaDropWithMint token1155;

    event TransferValidatorUpdated(address oldValidator, address newValidator);

    function setUp() public override {
        super.setUp();

        token721 = new ERC721SeaDropWithMint(
            address(0),
            allowedSeaport,
            "",
            ""
        );
        token721.setMaxSupply(10);

        token1155 = new ERC1155SeaDropWithMint(
            address(0),
            allowedSeaport,
            "",
            ""
        );
        token1155.setMaxSupply(1, 10);
        token1155.setMaxSupply(2, 10);
    }

    function testERC721OnlyOwnerCanSetTransferValidator() public {
        assertEq(token721.getTransferValidator(), address(0));

        vm.prank(address(token721));
        vm.expectRevert(Ownable.Unauthorized.selector);
        token721.setTransferValidator(address(transferValidatorAlwaysSucceeds));

        token721.setTransferValidator(address(transferValidatorAlwaysSucceeds));
        assertEq(
            token721.getTransferValidator(),
            address(transferValidatorAlwaysSucceeds)
        );
    }

    function testERC1155OnlyOwnerCanSetTransferValidator() public {
        assertEq(token1155.getTransferValidator(), address(0));

        vm.prank(address(token1155));
        vm.expectRevert(Ownable.Unauthorized.selector);
        token1155.setTransferValidator(
            address(transferValidatorAlwaysSucceeds)
        );

        token1155.setTransferValidator(
            address(transferValidatorAlwaysSucceeds)
        );
        assertEq(
            token1155.getTransferValidator(),
            address(transferValidatorAlwaysSucceeds)
        );
    }

    function testERC721TransferValidatorIsCalledOnTransfer() public {
        token721.mint(address(this), 2);

        vm.expectEmit(true, true, true, true);
        emit TransferValidatorUpdated(
            address(0),
            address(transferValidatorAlwaysSucceeds)
        );
        token721.setTransferValidator(address(transferValidatorAlwaysSucceeds));
        token721.safeTransferFrom(address(this), msg.sender, 1);

        vm.expectEmit(true, true, true, true);
        emit TransferValidatorUpdated(
            address(transferValidatorAlwaysSucceeds),
            address(transferValidatorAlwaysReverts)
        );
        token721.setTransferValidator(address(transferValidatorAlwaysReverts));
        vm.expectRevert("MockTransferValidator: always reverts");
        token721.safeTransferFrom(address(this), msg.sender, 2);

        // When set to null address, transfer should succeed without calling the validator
        vm.expectEmit(true, true, true, true);
        emit TransferValidatorUpdated(
            address(transferValidatorAlwaysReverts),
            address(0)
        );
        token721.setTransferValidator(address(0));
        token721.safeTransferFrom(address(this), msg.sender, 2);
    }

    function testERC1155TransferValidatorIsCalledOnTransfer() public {
        token1155.mint(address(this), 1, 10);
        token1155.mint(address(this), 2, 10);

        vm.expectEmit(true, true, true, true);
        emit TransferValidatorUpdated(
            address(0),
            address(transferValidatorAlwaysSucceeds)
        );
        token1155.setTransferValidator(
            address(transferValidatorAlwaysSucceeds)
        );
        token1155.safeTransferFrom(address(this), msg.sender, 1, 1, "");
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 2;
        amounts[1] = 2;
        token1155.safeBatchTransferFrom(
            address(this),
            msg.sender,
            ids,
            amounts,
            ""
        );

        vm.expectEmit(true, true, true, true);
        emit TransferValidatorUpdated(
            address(transferValidatorAlwaysSucceeds),
            address(transferValidatorAlwaysReverts)
        );
        token1155.setTransferValidator(address(transferValidatorAlwaysReverts));
        vm.expectRevert("MockTransferValidator: always reverts");
        token1155.safeTransferFrom(address(this), msg.sender, 1, 1, "");
        vm.expectRevert("MockTransferValidator: always reverts");
        token1155.safeBatchTransferFrom(
            address(this),
            msg.sender,
            ids,
            amounts,
            ""
        );

        // When set to null address, transfer should succeed without calling the validator
        vm.expectEmit(true, true, true, true);
        emit TransferValidatorUpdated(
            address(transferValidatorAlwaysReverts),
            address(0)
        );
        token1155.setTransferValidator(address(0));
        token1155.safeTransferFrom(address(this), msg.sender, 1, 1, "");
        token1155.safeBatchTransferFrom(
            address(this),
            msg.sender,
            ids,
            amounts,
            ""
        );
    }

    function testERC721GetTransferValidationFunction() public {
        (bytes4 functionSignature, bool isViewFunction) = token721
            .getTransferValidationFunction();
        assertEq(
            functionSignature,
            ITransferValidator721.validateTransfer.selector
        );
        assertEq(isViewFunction, false);
    }

    function testERC1155GetTransferValidationFunction() public {
        (bytes4 functionSignature, bool isViewFunction) = token1155
            .getTransferValidationFunction();
        assertEq(
            functionSignature,
            ITransferValidator1155.validateTransfer.selector
        );
        assertEq(isViewFunction, true);
    }
}
