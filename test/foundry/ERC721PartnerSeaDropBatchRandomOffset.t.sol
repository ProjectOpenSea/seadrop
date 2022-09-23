// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import {
    ERC721PartnerSeaDropBatchRandomOffset
} from "seadrop/ERC721PartnerSeaDropBatchRandomOffset.sol";
import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";
import { IERC721A } from "ERC721A/IERC721A.sol";

contract ERC721PartnerSeaDropBatchRandomOffsetTestImpl is
    ERC721PartnerSeaDropBatchRandomOffset
{
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, allowed SeaDrop addresses, and default tokenURI.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop,
        string memory _defaultURI
    )
        ERC721PartnerSeaDropBatchRandomOffset(
            name,
            symbol,
            administrator,
            allowedSeaDrop,
            _defaultURI
        )
    {}

    function calculateOffsetId(BatchOffset memory offset, uint256 tokenId)
        public
        pure
        returns (uint256)
    {
        return _calculateOffsetId(offset, tokenId);
    }
}

contract TestERC721PartnerSeaDropBatchRandomOffset is TestHelper {
    ERC721PartnerSeaDropBatchRandomOffsetTestImpl test;

    function setUp() public {
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(this);
        test = new ERC721PartnerSeaDropBatchRandomOffsetTestImpl(
            "Test",
            "TEST",
            address(this),
            allowedSeaDrop,
            "default"
        );
        test.setBaseURI("reveal");
        test.setMaxSupply(5000);
    }

    function testSetDefaultURI() public {
        assertEq(test.defaultURI(), "default");
        test.setDefaultURI("newDefault");
        assertEq(test.defaultURI(), "newDefault");
    }

    function testSetDefaultURI_onlyOwner() public {
        vm.startPrank(makeAddr("not owner"));
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        test.setDefaultURI("newDefault");
    }

    function testRevealBatch_tooSmall_noMints() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721PartnerSeaDropBatchRandomOffset
                    .BatchSizeTooSmall
                    .selector,
                0
            )
        );
        test.revealBatch();
    }

    function testRevealBatch_tooSmall_999() public {
        test.mintSeaDrop(address(this), 999);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721PartnerSeaDropBatchRandomOffset
                    .BatchSizeTooSmall
                    .selector,
                999
            )
        );
        test.revealBatch();
    }

    function testRevealBatch_first() public {
        test.mintSeaDrop(address(this), 1001);
        vm.difficulty(69);
        test.revealBatch();
        (
            uint64 inclusiveStartId,
            uint64 exclusiveEndId,
            uint64 randomOffset
        ) = test.batchOffsets(0);
        assertEq(inclusiveStartId, 1);
        assertEq(exclusiveEndId, 1002);
        assertEq(randomOffset, 69);
    }

    function testRevealBatch_first(uint256 difficulty) public {
        test.mintSeaDrop(address(this), 1001);
        vm.difficulty(difficulty);
        test.revealBatch();
        (
            uint64 inclusiveStartId,
            uint64 exclusiveEndId,
            uint64 randomOffset
        ) = test.batchOffsets(0);
        assertEq(inclusiveStartId, 1);
        assertEq(exclusiveEndId, 1002);
        assertEq(randomOffset, difficulty % 1001);
    }

    function testRevealBatch_second() public {
        test.mintSeaDrop(address(this), 1001);
        vm.difficulty(42);
        test.revealBatch();
        test.mintSeaDrop(address(this), 2345);
        vm.difficulty(69);
        test.revealBatch();
        (
            uint64 inclusiveStartId,
            uint64 exclusiveEndId,
            uint64 randomOffset
        ) = test.batchOffsets(1);
        assertEq(inclusiveStartId, 1002);
        assertEq(exclusiveEndId, 3347);
        assertEq(randomOffset, 69);
    }

    function testRevealBatch_allRevealed() public {
        test.mintSeaDrop(address(this), 1001);
        vm.difficulty(42);
        test.revealBatch();
        test.mintSeaDrop(address(this), 2345);
        vm.difficulty(69);
        test.revealBatch();
        test.mintSeaDrop(address(this), 1654);
        test.revealBatch();
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721PartnerSeaDropBatchRandomOffset
                    .AllBatchesRevealed
                    .selector
            )
        );
        test.revealBatch();
    }

    function testRevealBatch_lastBatchSmallerThanMin() public {
        test.mintSeaDrop(address(this), 1001);
        vm.difficulty(42);
        test.revealBatch();
        test.mintSeaDrop(address(this), 2345);
        vm.difficulty(69);
        test.revealBatch();
        test.mintSeaDrop(address(this), 1600);
        test.revealBatch();
        test.mintSeaDrop(address(this), 54);
        vm.difficulty(420);
        test.revealBatch();
        (
            uint64 inclusiveStartId,
            uint64 exclusiveEndId,
            uint64 randomOffset
        ) = test.batchOffsets(3);

        assertEq(inclusiveStartId, 4947);
        assertEq(exclusiveEndId, 5001);
        assertEq(randomOffset, 420 % 54);
    }

    function testTokenURI_nonexistent() public {
        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        test.tokenURI(1);
    }

    function testTokenURI_noneRevealed() public {
        test.mintSeaDrop(address(this), 1);
        assertEq(test.tokenURI(1), "default");
    }

    function testTokenURI_someRevealedNotQueried() public {
        test.mintSeaDrop(address(this), 1001);
        test.revealBatch();
        test.mintSeaDrop(address(this), 1);
        assertEq(test.tokenURI(1002), "default");
    }

    function testTokenURI_someRevealed_firstBatch() public {
        test.mintSeaDrop(address(this), 1001);
        test.revealBatch();
        test.mintSeaDrop(address(this), 1);
        assertEq(test.tokenURI(1), "reveal/1");
    }

    function testTokenURI_someRevealed_secondBatch() public {
        test.mintSeaDrop(address(this), 1001);
        test.revealBatch();
        test.mintSeaDrop(address(this), 1001);
        test.revealBatch();
        assertEq(test.tokenURI(1002), "reveal/1002");
    }

    function testTokenURI_allRevealed() public {
        test.mintSeaDrop(address(this), 1001);
        test.revealBatch();
        test.mintSeaDrop(address(this), 3999);
        test.revealBatch();
        assertEq(test.tokenURI(5000), "reveal/5000");
    }

    function testTokenURI_allRevealed_lastBatchSmallerThanMin() public {
        test.mintSeaDrop(address(this), 4950);
        test.revealBatch();
        test.mintSeaDrop(address(this), 50);
        test.revealBatch();
        assertEq(test.tokenURI(5000), "reveal/5000");
    }

    function testCalculateOffsetId(uint64 randomOffset, uint64 tokenId) public {
        // bound upper bound is inclusive
        tokenId = uint64(bound(tokenId, 543, 1233));
        uint256 batchSize = 1234 - 543;
        ERC721PartnerSeaDropBatchRandomOffset.BatchOffset
            memory offset = ERC721PartnerSeaDropBatchRandomOffset.BatchOffset({
                inclusiveStartId: 543,
                exclusiveEndId: 1234,
                randomOffset: uint64(randomOffset % batchSize)
            });

        uint256 offsetId = test.calculateOffsetId(offset, tokenId);
        // no gte, so swap the order
        assertLt(offsetId, 1234);
        assertLt(542, offsetId);
    }
}
