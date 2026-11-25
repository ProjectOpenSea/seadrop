// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { Test } from "forge-std/Test.sol";
import {
    ERC721SeaDropV3TransferAdapter
} from "seadrop/v3/adapters/ERC721SeaDropV3TransferAdapter.sol";
import { TestExistingERC721 } from "./utils/AdapterMocks.sol";

contract TransferQueueHandler is Test {
    uint256 internal constant INVENTORY = 16;
    TestExistingERC721 internal target;
    ERC721SeaDropV3TransferAdapter internal adapter;
    address internal constant BUYER = address(0xB0B);
    uint256[] internal queue;
    uint256 internal delivered;

    constructor() {
        target = new TestExistingERC721();
        adapter = new ERC721SeaDropV3TransferAdapter(
            address(target), address(this), address(this)
        );
        target.mintUnsafe(address(this), INVENTORY);
        adapter.setMaxSupply(INVENTORY);
    }

    function deposit(uint256 seed, bool safe) external {
        uint256 id = seed % INVENTORY + 1;
        if (target.ownerOf(id) != address(this)) return;
        if (safe) {
            target.safeTransferFrom(address(this), address(adapter), id);
            queue.push(id);
        } else {
            target.transferFrom(address(this), address(adapter), id);
        }
    }

    function mint(uint256 quantitySeed) external {
        uint256 room = adapter.maxSupply() - delivered;
        if (queue.length == 0 || room == 0) return;
        uint256 maxQty = queue.length < room ? queue.length : room;
        uint256 quantity = bound(quantitySeed, 1, maxQty > 3 ? 3 : maxQty);
        uint256[] memory expected = new uint256[](quantity);
        for (uint256 i; i < quantity; ++i) {
            expected[i] = queue[i];
        }
        adapter.mintSeaDrop(BUYER, 0, quantity);
        for (uint256 i; i < quantity; ++i) {
            assertEq(target.ownerOf(expected[i]), BUYER);
            _removeFront();
        }
        delivered += quantity;
    }

    function withdraw(uint256 quantitySeed) external {
        if (queue.length == 0) return;
        uint256 quantity =
            bound(quantitySeed, 1, queue.length > 3 ? 3 : queue.length);
        uint256[] memory expected = new uint256[](quantity);
        for (uint256 i; i < quantity; ++i) {
            expected[i] = queue[queue.length - 1 - i];
        }
        adapter.withdraw(BUYER, quantity);
        for (uint256 i; i < quantity; ++i) {
            assertEq(target.ownerOf(expected[i]), BUYER);
            queue.pop();
        }
    }

    function rejectDuplicateDeposit(uint256 seed) external {
        if (queue.length == 0) return;
        uint256 id = queue[seed % queue.length];
        vm.prank(address(target));
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3TransferAdapter.TokenIsQueued.selector, id
            )
        );
        adapter.onERC721Received(address(this), address(this), id, "");
    }

    function dequeue() external {
        if (queue.length == 0) return;
        adapter.dequeueHead(queue[0]);
        _removeFront();
    }

    function _removeFront() internal {
        for (uint256 i = 1; i < queue.length; ++i) {
            queue[i - 1] = queue[i];
        }
        queue.pop();
    }

    function rescue(uint256 seed) external {
        uint256 id = seed % INVENTORY + 1;
        if (target.ownerOf(id) != address(adapter)) return;
        for (uint256 i; i < queue.length; ++i) {
            if (queue[i] == id) return;
        }
        adapter.rescue(id, BUYER);
        assertEq(target.ownerOf(id), BUYER);
    }

    function setCap(uint256 seed) external {
        adapter.setMaxSupply(bound(seed, delivered, INVENTORY));
    }

    function checkQueue() external view {
        assertEq(adapter.totalMinted(), delivered);
        assertLe(delivered, adapter.maxSupply());
        assertEq(adapter.queuedTokenCount(), queue.length);
        assertEq(adapter.queuedTokenIds(), queue);
        bool[17] memory queued;
        for (uint256 i; i < queue.length; ++i) {
            assertFalse(queued[queue[i]]);
            queued[queue[i]] = true;
        }
        for (uint256 id = 1; id <= INVENTORY; ++id) {
            assertEq(adapter.isQueued(id), queued[id]);
        }
    }
}

contract TransferAdapterInvariantTest is Test {
    TransferQueueHandler internal handler;

    function setUp() public {
        handler = new TransferQueueHandler();
        bytes4[] memory actions = new bytes4[](7);
        actions[0] = handler.deposit.selector;
        actions[1] = handler.mint.selector;
        actions[2] = handler.withdraw.selector;
        actions[3] = handler.dequeue.selector;
        actions[4] = handler.rescue.selector;
        actions[5] = handler.setCap.selector;
        actions[6] = handler.rejectDuplicateDeposit.selector;
        targetSelector(FuzzSelector(address(handler), actions));
        targetContract(address(handler));
    }

    function invariant_queueMatchesInventory() public view {
        handler.checkQueue();
    }
}
