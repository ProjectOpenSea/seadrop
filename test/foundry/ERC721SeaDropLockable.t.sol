// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721Test } from "./utils/SeaDrop721Test.sol";

import { LockEvent, LockEvents } from "./utils/LockEvents.sol";

import {
    ERC721SeaDropLockable
} from "seadrop/extensions/ERC721SeaDropLockable.sol";

import { ERC8451Lockable, LockMode } from "seadrop/lib/ERC8451Lockable.sol";

import { IERC6982 } from "seadrop/interfaces/IERC6982.sol";

import { IERC8451 } from "seadrop/interfaces/IERC8451.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { PublicDrop } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { MockTransferValidator } from "seadrop/test/MockTransferValidator.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

import { IERC721A } from "ERC721A/IERC721A.sol";

contract ERC721SeaDropLockableWithMint is ERC721SeaDropLockable {
    constructor(
        address allowedConfigurer,
        address allowedSeaport,
        string memory name,
        string memory symbol,
        LockMode lockMode
    )
        ERC721SeaDropLockable(
            allowedConfigurer, allowedSeaport, name, symbol, lockMode
        )
    { }

    function mint(address to, uint256 quantity) public onlyOwner {
        _mint(to, quantity);
    }
}

contract ERC721SeaDropLockableTest is SeaDrop721Test {
    /// @dev The OpenSea conduit, which ERC721SeaDrop preapproves.
    address constant CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    ERC721SeaDropLockableWithMint token_;

    address holder = makeAddr("holder");
    address operator = makeAddr("operator");
    address recipient = makeAddr("recipient");

    function _deploy(LockMode lockMode)
        internal
        returns (ERC721SeaDropLockableWithMint)
    {
        return new ERC721SeaDropLockableWithMint(
            address(configurer), allowedSeaport, "", "", lockMode
        );
    }

    /// @dev Deploy with the given lock mode and mint tokens 1 to 3 to the
    ///      holder.
    function _setUp(LockMode lockMode) internal {
        token_ = _deploy(lockMode);
        token = token_;
        token_.mint(holder, 3);
    }

    function _lockEvents() internal view returns (LockEvent[] memory) {
        return LockEvents.decode(vm.getRecordedLogs());
    }

    function _assertLockEvents(
        LockEvent[] memory actual,
        LockEvent[] memory expected
    ) internal pure {
        assertEq(actual.length, expected.length, "lock event count");
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(actual[i].topic, expected[i].topic, "lock event topic");
            assertEq(
                actual[i].tokenId, expected[i].tokenId, "lock event token id"
            );
            assertEq(
                actual[i].isLocked, expected[i].isLocked, "lock event status"
            );
        }
    }

    function _events(LockEvent memory a)
        internal
        pure
        returns (LockEvent[] memory events)
    {
        events = new LockEvent[](1);
        events[0] = a;
    }

    function _events(LockEvent memory a, LockEvent memory b)
        internal
        pure
        returns (LockEvent[] memory events)
    {
        events = new LockEvent[](2);
        events[0] = a;
        events[1] = b;
    }

    function _events(LockEvent memory a, LockEvent memory b, LockEvent memory c)
        internal
        pure
        returns (LockEvent[] memory events)
    {
        events = new LockEvent[](3);
        events[0] = a;
        events[1] = b;
        events[2] = c;
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

    function _asArray(uint256 a, uint256 b)
        internal
        pure
        returns (uint256[] memory arr)
    {
        arr = new uint256[](2);
        arr[0] = a;
        arr[1] = b;
    }

    /// @dev Expect every holder transfer of `tokenId` to revert with
    ///      `TokenLocked(tokenId)`, from the holder, from approved operators,
    ///      and from the preapproved OpenSea conduit.
    function _assertHolderTransfersRevert(uint256 tokenId) internal {
        vm.startPrank(holder);
        vm.expectRevert(_tokenLocked(tokenId));
        token_.transferFrom(holder, recipient, tokenId);
        vm.expectRevert(_tokenLocked(tokenId));
        token_.safeTransferFrom(holder, recipient, tokenId);
        vm.expectRevert(_tokenLocked(tokenId));
        token_.safeTransferFrom(holder, recipient, tokenId, "");
        // A transfer to yourself is still a holder transfer.
        vm.expectRevert(_tokenLocked(tokenId));
        token_.transferFrom(holder, holder, tokenId);
        vm.stopPrank();

        if (token_.isApprovedForAll(holder, operator)) {
            vm.prank(operator);
            vm.expectRevert(_tokenLocked(tokenId));
            token_.transferFrom(holder, recipient, tokenId);
        }

        address approved = token_.getApproved(tokenId);
        if (approved != address(0)) {
            vm.prank(approved);
            vm.expectRevert(_tokenLocked(tokenId));
            token_.safeTransferFrom(holder, recipient, tokenId);
        }

        // A Seaport sale transfers through the conduit.
        vm.prank(CONDUIT);
        vm.expectRevert(_tokenLocked(tokenId));
        token_.transferFrom(holder, recipient, tokenId);

        assertEq(token_.ownerOf(tokenId), holder);
    }

    function _assertTransferSucceeds(uint256 tokenId) internal {
        vm.prank(holder);
        token_.transferFrom(holder, recipient, tokenId);
        assertEq(token_.ownerOf(tokenId), recipient);

        vm.prank(CONDUIT);
        token_.transferFrom(recipient, holder, tokenId);
        assertEq(token_.ownerOf(tokenId), holder);
    }

    function testInterfaceIds() public pure {
        assertEq(type(IERC8451).interfaceId, bytes4(0x9051c597));
        assertEq(type(IERC6982).interfaceId, bytes4(0x6b61a747));
    }

    function testSupportsInterface() public {
        _setUp(LockMode.Unlocked);
        assertTrue(token_.supportsInterface(0x9051c597)); // ERC-8451
        assertTrue(token_.supportsInterface(0x6b61a747)); // ERC-6982
        assertTrue(token_.supportsInterface(0x80ac58cd)); // ERC-721
        assertTrue(token_.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(token_.supportsInterface(0x2a55205a)); // ERC-2981
        assertTrue(token_.supportsInterface(type(IERC721SeaDrop).interfaceId));
        assertFalse(token_.supportsInterface(0xd9b67a26)); // ERC-1155
        assertFalse(token_.supportsInterface(0xffffffff));
    }

    function testConstructorUnlocked() public {
        vm.recordLogs();
        _setUp(LockMode.Unlocked);
        _assertLockEvents(
            _lockEvents(), _events(LockEvents.defaultLocked(false))
        );

        assertFalse(token_.defaultLocked());
        assertFalse(token_.permanentlyLocked());
        assertFalse(token_.locked(1));
        _assertTransferSucceeds(1);
    }

    function testConstructorLocked() public {
        vm.recordLogs();
        _setUp(LockMode.Locked);

        // The base contract starts unlocked, then the lock mode applies.
        _assertLockEvents(
            _lockEvents(),
            _events(
                LockEvents.defaultLocked(false), LockEvents.defaultLocked(true)
            )
        );

        assertTrue(token_.defaultLocked());
        assertFalse(token_.permanentlyLocked());
        assertTrue(token_.locked(1));
        _assertHolderTransfersRevert(1);
    }

    function testConstructorPermanentlyLocked() public {
        vm.recordLogs();
        _setUp(LockMode.PermanentlyLocked);

        // The base contract starts unlocked, then the lock mode applies.
        // DefaultLocked(true) must come before PermanentlyLocked().
        _assertLockEvents(
            _lockEvents(),
            _events(
                LockEvents.defaultLocked(false),
                LockEvents.defaultLocked(true),
                LockEvents.permanentlyLocked()
            )
        );

        assertTrue(token_.defaultLocked());
        assertTrue(token_.permanentlyLocked());
        assertTrue(token_.locked(1));
        _assertHolderTransfersRevert(1);
    }

    function testConstructorRejectsInvalidLockMode() public {
        // The same init code deploys with the highest valid lock mode, so
        // the failure below comes from the lock mode alone.
        assertTrue(_create(2) != address(0));
        assertEq(_create(3), address(0));
    }

    function _create(uint256 lockMode) internal returns (address deployed) {
        bytes memory initCode = abi.encodePacked(
            type(ERC721SeaDropLockableWithMint).creationCode,
            abi.encode(address(configurer), allowedSeaport, "", "", lockMode)
        );
        assembly {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
    }

    function testMintWhileLocked() public {
        _setUp(LockMode.Locked);
        assertEq(token_.balanceOf(holder), 3);

        token_.lockPermanently();

        token_.mint(recipient, 1);
        assertEq(token_.ownerOf(4), recipient);
        assertTrue(token_.locked(4));
    }

    function testMintThroughSeaportWhileLocked() public {
        _setUp(LockMode.Locked);

        address feeRecipient = makeAddr("feeRecipient");
        IERC721SeaDrop(address(token_))
            .updateAllowedFeeRecipient(feeRecipient, true);
        token_.setMaxSupply(10);
        setSingleCreatorPayout(makeAddr("creator"));
        PublicDrop memory publicDrop = PublicDrop({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + 500),
            paymentToken: address(0),
            maxTotalMintableByWallet: 5,
            feeBps: 500,
            restrictFeeRecipients: true
        });
        IERC721SeaDrop(address(token_)).updatePublicDrop(publicDrop);

        addSeaDropOfferItem(2);
        addSeaDropConsiderationItems(feeRecipient, 500, 2 ether);
        configureSeaDropOrderParameters();

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: bytes.concat(
                bytes1(0x00), // SIP-6 version byte
                bytes1(0x00), // substandard version byte: public mint
                bytes20(feeRecipient),
                bytes20(address(this))
            )
        });

        vm.deal(address(this), 4 ether);
        consideration.fulfillAdvancedOrder{ value: 2 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token_.ownerOf(4), address(this));
        assertEq(token_.ownerOf(5), address(this));
        assertTrue(token_.locked(4));

        vm.expectRevert(_tokenLocked(4));
        token_.transferFrom(address(this), holder, 4);

        // Minting through Seaport continues after the lock is permanent.
        token_.lockPermanently();
        consideration.fulfillAdvancedOrder{ value: 2 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token_.ownerOf(6), address(this));
        assertEq(token_.ownerOf(7), address(this));
        assertTrue(token_.locked(7));

        vm.expectRevert(_tokenLocked(7));
        token_.transferFrom(address(this), holder, 7);
    }

    function testHolderAndOperatorTransfersRevertWhileLocked() public {
        _setUp(LockMode.Locked);

        // Approvals still work while the lock is temporary.
        vm.startPrank(holder);
        token_.setApprovalForAll(operator, true);
        token_.approve(recipient, 1);
        vm.stopPrank();
        assertTrue(token_.isApprovedForAll(holder, operator));
        assertEq(token_.getApproved(1), recipient);

        _assertHolderTransfersRevert(1);
        _assertHolderTransfersRevert(2);
    }

    function testLockLifecycle() public {
        _setUp(LockMode.Locked);
        _assertHolderTransfersRevert(1);

        // Unlock.
        vm.recordLogs();
        token_.setDefaultLocked(false);
        _assertLockEvents(
            _lockEvents(), _events(LockEvents.defaultLocked(false))
        );
        assertFalse(token_.defaultLocked());
        assertFalse(token_.locked(1));
        _assertTransferSucceeds(1);

        // Lock again.
        vm.recordLogs();
        token_.setDefaultLocked(true);
        _assertLockEvents(
            _lockEvents(), _events(LockEvents.defaultLocked(true))
        );
        assertTrue(token_.locked(1));
        _assertHolderTransfersRevert(1);

        // Unlock token 2 on its own while the default stays locked.
        vm.recordLogs();
        token_.setTokensLocked(_asArray(2), false);
        _assertLockEvents(_lockEvents(), _events(LockEvents.locked(2, false)));
        assertFalse(token_.locked(2));
        assertTrue(token_.locked(1));
        _assertTransferSucceeds(2);

        // Make the lock permanent. Token 2 is locked again first.
        vm.recordLogs();
        token_.lockPermanently();
        _assertLockEvents(
            _lockEvents(),
            _events(LockEvents.locked(2, true), LockEvents.permanentlyLocked())
        );

        assertTrue(token_.defaultLocked());
        assertTrue(token_.permanentlyLocked());
        assertTrue(token_.locked(1));
        assertTrue(token_.locked(2));
        _assertHolderTransfersRevert(1);
        _assertHolderTransfersRevert(2);
    }

    function testLockPermanentlyFromUnlocked() public {
        _setUp(LockMode.Unlocked);

        // Lock tokens 1 and 2 on their own, then unlock token 2 again.
        token_.setTokensLocked(_asArray(1, 2), true);
        token_.setTokensLocked(_asArray(2), false);
        _assertHolderTransfersRevert(1);
        _assertTransferSucceeds(2);
        _assertTransferSucceeds(3);

        // The default is locked before PermanentlyLocked is emitted, and
        // only token 2 needs a new Locked event.
        vm.recordLogs();
        token_.lockPermanently();
        _assertLockEvents(
            _lockEvents(),
            _events(
                LockEvents.defaultLocked(true),
                LockEvents.locked(2, true),
                LockEvents.permanentlyLocked()
            )
        );

        assertTrue(token_.defaultLocked());
        assertTrue(token_.permanentlyLocked());
        _assertHolderTransfersRevert(1);
        _assertHolderTransfersRevert(2);
        _assertHolderTransfersRevert(3);
    }

    function testTokensLockedAgainBeforePermanenceAreNotReemitted() public {
        _setUp(LockMode.Locked);

        token_.setTokensLocked(_asArray(1, 2), false);
        token_.setTokensLocked(_asArray(1), true);
        // Unlocking the same token twice tracks it once.
        token_.setTokensLocked(_asArray(2), false);

        vm.recordLogs();
        token_.lockPermanently();
        _assertLockEvents(
            _lockEvents(),
            _events(LockEvents.locked(2, true), LockEvents.permanentlyLocked())
        );
    }

    function testLockPermanentlyRelocksEveryUnlockedId() public {
        _setUp(LockMode.Locked);
        token_.mint(holder, 2);

        // Unlock tokens 1 to 5, then lock token 3 again.
        uint256[] memory ids = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            ids[i] = i + 1;
        }
        token_.setTokensLocked(ids, false);
        token_.setTokensLocked(_asArray(3), true);

        vm.recordLogs();
        token_.lockPermanently();
        LockEvent[] memory events = _lockEvents();

        // Tokens 1, 2, 4, and 5 are each locked again, in any order, before
        // PermanentlyLocked.
        assertEq(events.length, 5, "lock event count");
        bool[6] memory relocked;
        for (uint256 i = 0; i < 4; i++) {
            assertEq(events[i].topic, LockEvents.LOCKED, "lock event topic");
            assertTrue(events[i].isLocked, "lock event status");
            assertFalse(relocked[events[i].tokenId], "duplicate token id");
            relocked[events[i].tokenId] = true;
        }
        assertTrue(relocked[1] && relocked[2] && relocked[4] && relocked[5]);
        assertFalse(relocked[3]);
        assertEq(
            events[4].topic, LockEvents.PERMANENTLY_LOCKED, "last lock event"
        );

        for (uint256 id = 1; id <= 5; id++) {
            assertTrue(token_.locked(id));
        }
    }

    function testPerTokenLockWhileDefaultUnlocked() public {
        _setUp(LockMode.Unlocked);

        token_.setTokensLocked(_asArray(1), true);
        assertTrue(token_.locked(1));
        assertFalse(token_.locked(2));
        _assertHolderTransfersRevert(1);
        _assertTransferSucceeds(2);

        // A token's own status outlasts changes to the default.
        token_.setDefaultLocked(true);
        token_.setDefaultLocked(false);
        assertTrue(token_.locked(1));
        _assertHolderTransfersRevert(1);
    }

    function testCannotUnlockAfterPermanent() public {
        _setUp(LockMode.Locked);
        token_.setTokensLocked(_asArray(1), false);
        token_.lockPermanently();

        vm.recordLogs();

        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.setDefaultLocked(false);

        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.setDefaultLocked(true);

        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.setTokensLocked(_asArray(1), false);

        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.setTokensLocked(_asArray(2), true);

        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.lockPermanently();

        // No lock events were emitted.
        _assertLockEvents(_lockEvents(), new LockEvent[](0));

        assertTrue(token_.permanentlyLocked());
        assertTrue(token_.defaultLocked());
        assertTrue(token_.locked(1));
        _assertHolderTransfersRevert(1);
    }

    function testCannotUnlockAfterPermanentFromDeploy() public {
        _setUp(LockMode.PermanentlyLocked);

        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.setDefaultLocked(false);

        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.setTokensLocked(_asArray(1), false);

        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.lockPermanently();
    }

    function testApprovalRevocationAfterPermanence() public {
        _setUp(LockMode.Locked);

        // Grant approvals while the lock is temporary.
        vm.startPrank(holder);
        token_.setApprovalForAll(operator, true);
        token_.approve(recipient, 1);
        token_.approve(recipient, 2);
        vm.stopPrank();

        token_.lockPermanently();

        // New approvals revert.
        vm.startPrank(holder);
        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.setApprovalForAll(recipient, true);
        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.approve(operator, 3);
        vm.stopPrank();

        // An operator cannot grant approvals either.
        vm.prank(operator);
        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.approve(recipient, 3);

        // The holder can clear a token approval.
        vm.prank(holder);
        token_.approve(address(0), 1);
        assertEq(token_.getApproved(1), address(0));

        // An approved operator can clear a token approval.
        vm.prank(operator);
        token_.approve(address(0), 2);
        assertEq(token_.getApproved(2), address(0));

        // The holder can revoke an operator.
        vm.prank(holder);
        token_.setApprovalForAll(operator, false);
        assertFalse(token_.isApprovedForAll(holder, operator));

        // Revoking an approval that does not exist does not revert either.
        vm.prank(holder);
        token_.setApprovalForAll(operator, false);
    }

    function testApprovalsRevertWhenPermanentlyLockedFromDeploy() public {
        _setUp(LockMode.PermanentlyLocked);

        vm.startPrank(holder);
        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.setApprovalForAll(operator, true);
        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.approve(operator, 1);

        // Clearing approvals still works.
        token_.setApprovalForAll(operator, false);
        token_.approve(address(0), 1);
        vm.stopPrank();
    }

    function testBurnWhileLocked() public {
        _setUp(LockMode.Locked);

        vm.prank(holder);
        token_.setApprovalForAll(operator, true);

        // The holder burns while the lock is temporary.
        vm.prank(holder);
        token_.burn(1);

        token_.lockPermanently();

        // The holder burns after the lock is permanent.
        vm.prank(holder);
        token_.burn(2);

        // An operator approved before the lock became permanent burns.
        vm.prank(operator);
        token_.burn(3);

        assertEq(token_.balanceOf(holder), 0);
        assertEq(token_.totalSupply(), 0);

        // Burned tokens no longer exist.
        vm.expectRevert(ERC8451Lockable.LockQueryForNonexistentToken.selector);
        token_.locked(1);
    }

    function testBurnWhilePermanentlyLockedFromDeploy() public {
        _setUp(LockMode.PermanentlyLocked);

        vm.prank(holder);
        token_.burn(1);
        assertEq(token_.balanceOf(holder), 2);

        // Without an approval, others cannot burn.
        vm.prank(operator);
        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        token_.burn(2);
    }

    function testBurnedUnlockedTokenIsLockedAgain() public {
        _setUp(LockMode.Locked);

        // Unlock token 1, then burn it.
        token_.setTokensLocked(_asArray(1), false);
        vm.prank(holder);
        token_.burn(1);

        vm.expectRevert(ERC8451Lockable.LockQueryForNonexistentToken.selector);
        token_.locked(1);

        // Token 1 no longer exists, but its last Locked event unlocked it,
        // so it is locked again before PermanentlyLocked.
        vm.recordLogs();
        token_.lockPermanently();
        _assertLockEvents(
            _lockEvents(),
            _events(LockEvents.locked(1, true), LockEvents.permanentlyLocked())
        );
    }

    function testLockedRevertsForNonexistentToken() public {
        _setUp(LockMode.Locked);

        vm.expectRevert(ERC8451Lockable.LockQueryForNonexistentToken.selector);
        token_.locked(0);

        vm.expectRevert(ERC8451Lockable.LockQueryForNonexistentToken.selector);
        token_.locked(4);

        // Tokens that do not exist yet can have their own status.
        token_.setTokensLocked(_asArray(4), false);
        token_.mint(holder, 1);
        assertFalse(token_.locked(4));
        _assertTransferSucceeds(4);
    }

    function testOnlyOwnerCanUpdateLock() public {
        _setUp(LockMode.Locked);

        vm.startPrank(holder);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token_.setDefaultLocked(false);

        vm.expectRevert(Ownable.Unauthorized.selector);
        token_.setTokensLocked(_asArray(1), false);

        vm.expectRevert(Ownable.Unauthorized.selector);
        token_.lockPermanently();
        vm.stopPrank();

        assertTrue(token_.defaultLocked());
        assertFalse(token_.permanentlyLocked());
    }

    function testLockCheckedBeforeTransferValidator() public {
        _setUp(LockMode.Locked);
        token_.setTransferValidator(address(new MockTransferValidator(true)));

        // The lock reverts first, with TokenLocked.
        _assertHolderTransfersRevert(1);

        // Once unlocked, the transfer validator still runs.
        token_.setDefaultLocked(false);
        vm.prank(holder);
        vm.expectRevert("MockTransferValidator: always reverts");
        token_.transferFrom(holder, recipient, 1);

        token_.setTransferValidator(address(new MockTransferValidator(false)));
        _assertTransferSucceeds(1);
    }

    function testFuzzLockedMatchesLastEvent(
        bool defaultIsLocked,
        bool tokenOverrideSet,
        bool tokenIsLocked,
        bool lockPermanently
    ) public {
        _setUp(LockMode.Unlocked);

        token_.setDefaultLocked(defaultIsLocked);
        if (tokenOverrideSet) {
            token_.setTokensLocked(_asArray(1), tokenIsLocked);
        }
        if (lockPermanently) {
            token_.lockPermanently();
        }

        bool expected = lockPermanently
            || (tokenOverrideSet ? tokenIsLocked : defaultIsLocked);
        assertEq(token_.locked(1), expected);
        assertEq(token_.locked(2), lockPermanently || defaultIsLocked);

        if (expected) {
            _assertHolderTransfersRevert(1);
        } else {
            _assertTransferSucceeds(1);
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        public
        pure
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
