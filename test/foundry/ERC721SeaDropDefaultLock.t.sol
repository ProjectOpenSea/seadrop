// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721Test } from "./utils/SeaDrop721Test.sol";

import { LockEvent, LockEvents } from "./utils/LockEvents.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { ERC8451Lockable, LockMode } from "seadrop/lib/ERC8451Lockable.sol";

import { IERC8451 } from "seadrop/interfaces/IERC8451.sol";

contract ERC721SeaDropDefaultWithMint is ERC721SeaDrop {
    constructor(address allowedConfigurer, address allowedSeaport)
        ERC721SeaDrop(allowedConfigurer, allowedSeaport, "", "")
    { }

    function mint(address to, uint256 quantity) public onlyOwner {
        _mint(to, quantity);
    }
}

/// @dev Exposes `_initializeLock` so tests can check its guards.
contract ERC721SeaDropInitializeLockHarness is ERC721SeaDropDefaultWithMint {
    constructor(address allowedConfigurer, address allowedSeaport)
        ERC721SeaDropDefaultWithMint(allowedConfigurer, allowedSeaport)
    { }

    function initializeLock(LockMode lockMode) external {
        _initializeLock(lockMode);
    }
}

/**
 * @dev Locks in the default ERC721SeaDrop: it starts unlocked, and the lock
 *      can only become permanent before the first mint. The full lock
 *      lifecycle is covered in ERC721SeaDropLockable.t.sol.
 */
contract ERC721SeaDropDefaultLockTest is SeaDrop721Test {
    ERC721SeaDropDefaultWithMint token_;

    address holder = makeAddr("holder");
    address recipient = makeAddr("recipient");

    function setUp() public override {
        super.setUp();
        vm.recordLogs();
        token_ = new ERC721SeaDropDefaultWithMint(
            address(configurer), allowedSeaport
        );
        token = token_;
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

    function testDeployStartsUnlocked() public {
        LockEvent[] memory expected = new LockEvent[](1);
        expected[0] = LockEvents.defaultLocked(false);
        _assertLockEvents(LockEvents.decode(vm.getRecordedLogs()), expected);

        assertFalse(token_.defaultLocked());
        assertFalse(token_.permanentlyLocked());
        assertTrue(token_.supportsInterface(0x9051c597)); // ERC-8451
        assertTrue(token_.supportsInterface(0x6b61a747)); // ERC-6982
        assertTrue(token_.supportsInterface(0x80ac58cd)); // ERC-721

        token_.mint(holder, 1);
        assertFalse(token_.locked(1));
        vm.prank(holder);
        token_.transferFrom(holder, recipient, 1);
    }

    function testLockAndUnlock() public {
        token_.mint(holder, 2);

        token_.setDefaultLocked(true);
        vm.prank(holder);
        vm.expectRevert(_tokenLocked(1));
        token_.transferFrom(holder, recipient, 1);

        token_.setDefaultLocked(false);
        token_.setTokensLocked(_asArray(2), true);
        vm.startPrank(holder);
        token_.transferFrom(holder, recipient, 1);
        vm.expectRevert(_tokenLocked(2));
        token_.transferFrom(holder, recipient, 2);
        vm.stopPrank();
    }

    function testLockPermanentlyBeforeFirstMint() public {
        vm.recordLogs();
        token_.lockPermanently();

        LockEvent[] memory expected = new LockEvent[](2);
        expected[0] = LockEvents.defaultLocked(true);
        expected[1] = LockEvents.permanentlyLocked();
        _assertLockEvents(LockEvents.decode(vm.getRecordedLogs()), expected);

        // Minting continues, and the minted tokens are locked for good.
        token_.mint(holder, 1);
        assertTrue(token_.locked(1));
        vm.startPrank(holder);
        vm.expectRevert(_tokenLocked(1));
        token_.transferFrom(holder, recipient, 1);
        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.setApprovalForAll(recipient, true);
        token_.burn(1);
        vm.stopPrank();
    }

    function testCannotLockPermanentlyAfterMint() public {
        token_.setDefaultLocked(true);
        token_.mint(holder, 1);

        vm.expectRevert(ERC8451Lockable.CannotLockPermanentlyAfterMint.selector);
        token_.lockPermanently();

        // Burning every token does not reopen it.
        vm.prank(holder);
        token_.burn(1);
        assertEq(token_.totalSupply(), 0);
        vm.expectRevert(ERC8451Lockable.CannotLockPermanentlyAfterMint.selector);
        token_.lockPermanently();

        assertFalse(token_.permanentlyLocked());

        // The temporary lock still works.
        token_.mint(holder, 1);
        vm.prank(holder);
        vm.expectRevert(_tokenLocked(2));
        token_.transferFrom(holder, recipient, 2);
    }

    function testLockFlagsShareTransferValidatorSlot() public {
        address validator = makeAddr("validator");
        token_.setTransferValidator(validator);
        token_.setDefaultLocked(true);
        token_.setTokensLocked(_asArray(1), false);

        // Slot 9 (after ERC721A 4.3's _spotMinted) holds the transfer
        // validator in its low 20 bytes, then defaultLocked,
        // permanentlyLocked, and hasTokenLockOverrides, so a holder transfer
        // reads all of them with one storage read.
        uint256 slot = uint256(vm.load(address(token_), bytes32(uint256(9))));
        assertEq(address(uint160(slot)), validator);
        assertEq((slot >> 160) & 0xff, 1, "defaultLocked");
        assertEq((slot >> 168) & 0xff, 0, "permanentlyLocked");
        assertEq((slot >> 176) & 0xff, 1, "hasTokenLockOverrides");
    }

    function testInitializeLockRevertsOncePermanent() public {
        ERC721SeaDropInitializeLockHarness harness = new ERC721SeaDropInitializeLockHarness(
            address(configurer), allowedSeaport
        );
        harness.lockPermanently();

        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        harness.initializeLock(LockMode.Unlocked);

        assertTrue(harness.defaultLocked());
        assertTrue(harness.permanentlyLocked());
    }

    function testInitializeLockPermanentlyRelocksUnlockedIds() public {
        ERC721SeaDropInitializeLockHarness harness = new ERC721SeaDropInitializeLockHarness(
            address(configurer), allowedSeaport
        );
        harness.setTokensLocked(_asArray(1), false);

        // Starting permanently locked still emits the Locked(id, true)
        // events ERC-8451 requires before PermanentlyLocked.
        vm.recordLogs();
        harness.initializeLock(LockMode.PermanentlyLocked);

        LockEvent[] memory expected = new LockEvent[](3);
        expected[0] = LockEvents.defaultLocked(true);
        expected[1] = LockEvents.locked(1, true);
        expected[2] = LockEvents.permanentlyLocked();
        _assertLockEvents(LockEvents.decode(vm.getRecordedLogs()), expected);
    }
}
