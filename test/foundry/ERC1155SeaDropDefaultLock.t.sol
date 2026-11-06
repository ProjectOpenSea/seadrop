// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./utils/SeaDrop1155Test.sol";

import { LockEvent, LockEvents } from "./utils/LockEvents.sol";

import { Vm } from "forge-std/Vm.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import { ERC8451Lockable } from "seadrop/lib/ERC8451Lockable.sol";

import { IERC8451 } from "seadrop/interfaces/IERC8451.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import { PublicDrop } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import {
    ERC1155SeaDropCloneFactory
} from "seadrop/clones/ERC1155SeaDropCloneFactory.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

contract ERC1155SeaDropDefaultWithMint is ERC1155SeaDrop {
    constructor(address allowedConfigurer, address allowedSeaport)
        ERC1155SeaDrop(allowedConfigurer, allowedSeaport, "", "")
    { }

    function mint(address to, uint256 id, uint256 amount) public onlyOwner {
        _mint(to, id, amount, "");
    }
}

/// @dev A transfer validator that is also the token owner and locks every
///      token while validating a transfer.
contract DefaultLockingTransferValidator {
    function validateTransfer(address, address, address, uint256, uint256)
        external
    {
        ERC1155SeaDrop token = ERC1155SeaDrop(msg.sender);
        if (!token.defaultLocked()) {
            token.setDefaultLocked(true);
        }
    }
}

/**
 * @dev Locks in the default ERC1155SeaDrop and its clones: they start
 *      unlocked, and the lock can only become permanent before the first
 *      mint. The full lock lifecycle is covered in
 *      ERC1155SeaDropLockable.t.sol.
 */
contract ERC1155SeaDropDefaultLockTest is SeaDrop1155Test {
    ERC1155SeaDropDefaultWithMint token_;

    address holder = makeAddr("holder");
    address recipient = makeAddr("recipient");

    function setUp() public override {
        super.setUp();
        vm.recordLogs();
        token_ = new ERC1155SeaDropDefaultWithMint(
            address(configurer), allowedSeaport
        );
        token = token_;
        token_.setMaxSupply(1, 100);
        token_.setMaxSupply(2, 100);
    }

    function _assertLockEvents(
        LockEvent[] memory actual,
        LockEvent[] memory expected
    ) internal {
        assertEq(actual.length, expected.length, "lock event count");
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(actual[i].topic, expected[i].topic, "lock event topic");
            assertEq(actual[i].tokenId, expected[i].tokenId, "token id");
            assertEq(actual[i].isLocked, expected[i].isLocked, "status");
        }
    }

    function _tokenLocked(uint256 tokenId)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(IERC8451.TokenLocked.selector, tokenId);
    }

    function _asArray(uint256 a) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = a;
    }

    /// @dev Returns the lock events `emitter` emitted since recording began.
    function _lockEventsFrom(address emitter)
        internal
        returns (LockEvent[] memory)
    {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log[] memory fromEmitter = new Vm.Log[](logs.length);
        uint256 count;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == emitter) {
                fromEmitter[count++] = logs[i];
            }
        }
        assembly {
            mstore(fromEmitter, count)
        }
        return LockEvents.decode(fromEmitter);
    }

    /// @dev Mint `amount` of token id 1 to this contract through a Seaport
    ///      public drop on `clone`.
    function _mintThroughSeaport(address clone, uint256 amount) internal {
        token = ERC1155SeaDrop(clone);
        address feeRecipient = makeAddr("feeRecipient");
        IERC1155SeaDrop(clone).updateAllowedFeeRecipient(feeRecipient, true);
        _setSingleCreatorPayout(clone, makeAddr("creator"));
        token.setMaxSupply(1, 100);
        PublicDrop memory publicDrop = PublicDrop({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + 500),
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 1,
            maxTotalMintableByWallet: 10,
            maxTotalMintableByWalletPerToken: 10,
            feeBps: 500,
            restrictFeeRecipients: true
        });
        IERC1155SeaDrop(clone).updatePublicDrop(publicDrop, 0);

        // Token id 1, public drop index 0.
        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            clone, 1, amount, feeRecipient, 500, 1 ether, address(this), 0
        );
        vm.deal(address(this), value);
        _fulfill(order, address(this), value);
    }

    function testDeployStartsUnlocked() public {
        LockEvent[] memory expected = new LockEvent[](1);
        expected[0] = LockEvents.defaultLocked(false);
        _assertLockEvents(_lockEventsFrom(address(token_)), expected);

        assertFalse(token_.defaultLocked());
        assertFalse(token_.permanentlyLocked());
        assertTrue(token_.supportsInterface(0x9051c597)); // ERC-8451
        assertTrue(token_.supportsInterface(0x6b61a747)); // ERC-6982
        assertTrue(token_.supportsInterface(0xd9b67a26)); // ERC-1155

        token_.mint(holder, 1, 1);
        assertFalse(token_.locked(1));
        vm.prank(holder);
        token_.safeTransferFrom(holder, recipient, 1, 1, "");
    }

    function testLockAndUnlock() public {
        token_.mint(holder, 1, 2);
        token_.mint(holder, 2, 2);

        token_.setDefaultLocked(true);
        vm.prank(holder);
        vm.expectRevert(_tokenLocked(1));
        token_.safeTransferFrom(holder, recipient, 1, 1, "");

        token_.setDefaultLocked(false);
        token_.setTokensLocked(_asArray(2), true);
        vm.startPrank(holder);
        token_.safeTransferFrom(holder, recipient, 1, 1, "");
        vm.expectRevert(_tokenLocked(2));
        token_.safeTransferFrom(holder, recipient, 2, 1, "");
        vm.stopPrank();
    }

    function testLockPermanentlyBeforeFirstMint() public {
        vm.recordLogs();
        token_.lockPermanently();

        LockEvent[] memory expected = new LockEvent[](2);
        expected[0] = LockEvents.defaultLocked(true);
        expected[1] = LockEvents.permanentlyLocked();
        _assertLockEvents(_lockEventsFrom(address(token_)), expected);

        // Minting continues, and the minted tokens are locked for good.
        token_.mint(holder, 1, 2);
        assertTrue(token_.locked(1));
        vm.startPrank(holder);
        vm.expectRevert(_tokenLocked(1));
        token_.safeTransferFrom(holder, recipient, 1, 1, "");
        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.setApprovalForAll(recipient, true);
        token_.burn(holder, 1, 1);
        vm.stopPrank();
    }

    function testCannotLockPermanentlyAfterMint() public {
        token_.setDefaultLocked(true);
        token_.mint(holder, 1, 1);

        vm.expectRevert(ERC8451Lockable.CannotLockPermanentlyAfterMint.selector);
        token_.lockPermanently();

        // Burning the whole supply does not reopen it.
        vm.prank(holder);
        token_.burn(holder, 1, 1);
        assertEq(token_.totalSupply(1), 0);
        vm.expectRevert(ERC8451Lockable.CannotLockPermanentlyAfterMint.selector);
        token_.lockPermanently();

        assertFalse(token_.permanentlyLocked());

        // The temporary lock still works.
        token_.mint(holder, 2, 1);
        vm.prank(holder);
        vm.expectRevert(_tokenLocked(2));
        token_.safeTransferFrom(holder, recipient, 2, 1, "");
    }

    function testZeroAmountMintDoesNotStartMinting() public {
        // A mint of zero tokens creates no token, so the lock can still
        // become permanent.
        token_.mint(holder, 1, 0);
        assertEq(token_.totalSupply(1), 0);
        token_.lockPermanently();
        assertTrue(token_.permanentlyLocked());
    }

    function testLockFlagsShareTransferValidatorSlot() public {
        address validator = makeAddr("validator");
        token_.setTransferValidator(validator);
        token_.setDefaultLocked(true);
        token_.setTokensLocked(_asArray(1), false);

        // Slot 0 holds the transfer validator in its low 20 bytes, then
        // defaultLocked, permanentlyLocked, and hasTokenLockOverrides, so a
        // holder transfer reads all of them with one storage read.
        uint256 slot = uint256(vm.load(address(token_), bytes32(0)));
        assertEq(address(uint160(slot)), validator);
        assertEq((slot >> 160) & 0xff, 1, "defaultLocked");
        assertEq((slot >> 168) & 0xff, 0, "permanentlyLocked");
        assertEq((slot >> 176) & 0xff, 1, "hasTokenLockOverrides");
    }

    function testCloneStartsUnlockedAndLocksPermanentlyBeforeMint() public {
        ERC1155SeaDropCloneFactory factory =
            new ERC1155SeaDropCloneFactory(allowedSeaport);

        vm.recordLogs();
        address clone = factory.createClone("", "", bytes32("1"));

        // The clone emits DefaultLocked(false) from its initializer.
        LockEvent[] memory expected = new LockEvent[](1);
        expected[0] = LockEvents.defaultLocked(false);
        _assertLockEvents(_lockEventsFrom(clone), expected);

        ERC1155SeaDrop cloneToken = ERC1155SeaDrop(clone);
        assertFalse(cloneToken.defaultLocked());
        assertFalse(cloneToken.permanentlyLocked());
        assertTrue(cloneToken.supportsInterface(0x9051c597));
        assertTrue(cloneToken.supportsInterface(0x6b61a747));

        // The owner can make the lock permanent before the first mint, and
        // minting through Seaport continues afterwards.
        cloneToken.lockPermanently();
        _mintThroughSeaport(clone, 2);
        assertEq(cloneToken.balanceOf(address(this), 1), 2);
        assertTrue(cloneToken.locked(1));

        vm.expectRevert(_tokenLocked(1));
        cloneToken.safeTransferFrom(address(this), holder, 1, 1, "");
    }

    function testCloneCannotLockPermanentlyAfterMint() public {
        ERC1155SeaDropCloneFactory factory =
            new ERC1155SeaDropCloneFactory(allowedSeaport);
        address clone = factory.createClone("", "", bytes32("2"));
        ERC1155SeaDrop cloneToken = ERC1155SeaDrop(clone);

        _mintThroughSeaport(clone, 1);

        vm.expectRevert(ERC8451Lockable.CannotLockPermanentlyAfterMint.selector);
        cloneToken.lockPermanently();

        // A temporary lock still applies to the clone.
        cloneToken.setDefaultLocked(true);
        vm.expectRevert(_tokenLocked(1));
        cloneToken.safeTransferFrom(address(this), holder, 1, 1, "");
    }

    function _assertLockSetByValidatorApplies(
        ERC1155SeaDrop target,
        address from
    ) internal {
        DefaultLockingTransferValidator validator =
            new DefaultLockingTransferValidator();
        target.setTransferValidator(address(validator));
        target.transferOwnership(address(validator));

        uint256 balance = target.balanceOf(from, 1);
        vm.prank(from);
        vm.expectRevert(_tokenLocked(1));
        target.safeTransferFrom(from, recipient, 1, 1, "");

        // The reverted transfer left the lock and balances unchanged.
        assertFalse(target.defaultLocked());
        assertEq(target.balanceOf(from, 1), balance);
    }

    function testLockSetByTransferValidatorApplies() public {
        token_.mint(holder, 1, 1);
        _assertLockSetByValidatorApplies(token_, holder);
    }

    function testCloneLockSetByTransferValidatorApplies() public {
        ERC1155SeaDropCloneFactory factory =
            new ERC1155SeaDropCloneFactory(allowedSeaport);
        address clone = factory.createClone("", "", bytes32("3"));
        _mintThroughSeaport(clone, 1);
        _assertLockSetByValidatorApplies(ERC1155SeaDrop(clone), address(this));
    }
}
