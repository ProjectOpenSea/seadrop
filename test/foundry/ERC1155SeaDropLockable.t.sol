// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./utils/SeaDrop1155Test.sol";

import { LockEvent, LockEvents } from "./utils/LockEvents.sol";

import {
    ERC1155SeaDropLockable
} from "seadrop/extensions/ERC1155SeaDropLockable.sol";

import { ERC8451Lockable, LockMode } from "seadrop/lib/ERC8451Lockable.sol";

import { IERC6982 } from "seadrop/interfaces/IERC6982.sol";

import { IERC8451 } from "seadrop/interfaces/IERC8451.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import { PublicDrop } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import { MockTransferValidator } from "seadrop/test/MockTransferValidator.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

import { ERC1155 } from "solady/src/tokens/ERC1155.sol";

contract ERC1155SeaDropLockableWithMint is ERC1155SeaDropLockable {
    constructor(
        address allowedConfigurer,
        address allowedSeaport,
        string memory name_,
        string memory symbol_,
        LockMode lockMode
    )
        ERC1155SeaDropLockable(
            allowedConfigurer, allowedSeaport, name_, symbol_, lockMode
        )
    { }

    function mint(address to, uint256 id, uint256 amount) public onlyOwner {
        _mint(to, id, amount, "");
    }

    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public onlyOwner {
        _batchMint(to, ids, amounts, "");
    }
}

/// @dev A transfer validator that is also the token owner and makes the
///      lock permanent while validating a transfer.
contract LockingTransferValidator {
    ERC1155SeaDropLockable immutable token;

    constructor(ERC1155SeaDropLockable token_) {
        token = token_;
    }

    function validateTransfer(address, address, address, uint256, uint256)
        external
    {
        if (!token.permanentlyLocked()) {
            token.lockPermanently();
        }
    }
}

contract ERC1155SeaDropLockableTest is SeaDrop1155Test {
    /// @dev The OpenSea conduit, which ERC1155SeaDrop preapproves.
    address constant CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    ERC1155SeaDropLockableWithMint token_;

    address holder = makeAddr("holder");
    address operator = makeAddr("operator");
    address recipient = makeAddr("recipient");

    function _deploy(LockMode lockMode)
        internal
        returns (ERC1155SeaDropLockableWithMint)
    {
        return new ERC1155SeaDropLockableWithMint(
            address(configurer), allowedSeaport, "", "", lockMode
        );
    }

    /// @dev Deploy with the given lock mode and mint 10 of each of token
    ///      ids 1 to 3 to the holder.
    function _setUp(LockMode lockMode) internal {
        token_ = _deploy(lockMode);
        token = token_;
        for (uint256 id = 1; id <= 4; id++) {
            token_.setMaxSupply(id, 1000);
        }
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 10;
        amounts[1] = 10;
        amounts[2] = 10;
        token_.batchMint(holder, _asArray(1, 2, 3), amounts);
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

    /// @dev Rebuild a token's lock status from events the way a consumer
    ///      that only knows ERC-6982 would: the token's most recent
    ///      `Locked` event wins, then the most recent `DefaultLocked`.
    function _replayErc6982(LockEvent[] memory events, uint256 tokenId)
        internal
        pure
        returns (bool)
    {
        bool defaultStatus;
        bool hasOverride;
        bool overrideStatus;
        for (uint256 i = 0; i < events.length; i++) {
            if (events[i].topic == LockEvents.DEFAULT_LOCKED) {
                defaultStatus = events[i].isLocked;
            } else if (
                events[i].topic == LockEvents.LOCKED
                    && events[i].tokenId == tokenId
            ) {
                hasOverride = true;
                overrideStatus = events[i].isLocked;
            }
        }
        return hasOverride ? overrideStatus : defaultStatus;
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

    function _asArray(uint256 a, uint256 b, uint256 c)
        internal
        pure
        returns (uint256[] memory arr)
    {
        arr = new uint256[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
    }

    /// @dev Expect every holder transfer of `id` to revert with
    ///      `TokenLocked(id)`, from the holder, from approved operators, and
    ///      from the preapproved OpenSea conduit, as a single or batch
    ///      transfer. `testBatchTransferRevertsOnFirstLockedId` covers
    ///      batches that mix locked and unlocked ids.
    function _assertHolderTransfersRevert(uint256 id) internal {
        uint256 balance = token_.balanceOf(holder, id);

        vm.startPrank(holder);
        vm.expectRevert(_tokenLocked(id));
        token_.safeTransferFrom(holder, recipient, id, 1, "");
        vm.expectRevert(_tokenLocked(id));
        token_.safeBatchTransferFrom(
            holder, recipient, _asArray(id), _asArray(1), ""
        );
        // A transfer to yourself is still a holder transfer.
        vm.expectRevert(_tokenLocked(id));
        token_.safeTransferFrom(holder, holder, id, 1, "");
        // So is a transfer of zero tokens.
        vm.expectRevert(_tokenLocked(id));
        token_.safeTransferFrom(holder, recipient, id, 0, "");
        vm.stopPrank();

        if (token_.isApprovedForAll(holder, operator)) {
            vm.prank(operator);
            vm.expectRevert(_tokenLocked(id));
            token_.safeTransferFrom(holder, recipient, id, 1, "");
        }

        // A Seaport sale transfers through the conduit.
        vm.prank(CONDUIT);
        vm.expectRevert(_tokenLocked(id));
        token_.safeTransferFrom(holder, recipient, id, 1, "");

        assertEq(token_.balanceOf(holder, id), balance);
    }

    function _assertTransferSucceeds(uint256 id) internal {
        uint256 balance = token_.balanceOf(holder, id);

        vm.prank(holder);
        token_.safeTransferFrom(holder, recipient, id, 1, "");
        assertEq(token_.balanceOf(holder, id), balance - 1);

        vm.prank(CONDUIT);
        token_.safeTransferFrom(recipient, holder, id, 1, "");
        assertEq(token_.balanceOf(holder, id), balance);
    }

    function testInterfaceIds() public pure {
        assertEq(type(IERC8451).interfaceId, bytes4(0x9051c597));
        assertEq(type(IERC6982).interfaceId, bytes4(0x6b61a747));
    }

    function testSupportsInterface() public {
        _setUp(LockMode.Unlocked);
        assertTrue(token_.supportsInterface(0x9051c597)); // ERC-8451
        assertTrue(token_.supportsInterface(0x6b61a747)); // ERC-6982
        assertTrue(token_.supportsInterface(0xd9b67a26)); // ERC-1155
        assertTrue(token_.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(token_.supportsInterface(0x2a55205a)); // ERC-2981
        assertTrue(token_.supportsInterface(type(IERC1155SeaDrop).interfaceId));
        assertFalse(token_.supportsInterface(0x80ac58cd)); // ERC-721
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
            type(ERC1155SeaDropLockableWithMint).creationCode,
            abi.encode(address(configurer), allowedSeaport, "", "", lockMode)
        );
        assembly {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
    }

    function testMintWhileLocked() public {
        _setUp(LockMode.Locked);
        assertEq(token_.balanceOf(holder, 1), 10);

        token_.mint(recipient, 4, 5);
        assertTrue(token_.locked(4));

        token_.lockPermanently();

        token_.mint(recipient, 4, 5);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        token_.batchMint(recipient, _asArray(1, 4), amounts);
        assertEq(token_.balanceOf(recipient, 4), 11);
        assertEq(token_.balanceOf(recipient, 1), 1);
        assertTrue(token_.locked(4));
    }

    function testMintThroughSeaportWhileLocked() public {
        _setUp(LockMode.Locked);

        address feeRecipient = makeAddr("feeRecipient");
        IERC1155SeaDrop(address(token_))
            .updateAllowedFeeRecipient(feeRecipient, true);
        setSingleCreatorPayout(makeAddr("creator"));
        PublicDrop memory publicDrop = PublicDrop({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + 500),
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 4,
            maxTotalMintableByWallet: 6,
            maxTotalMintableByWalletPerToken: 5,
            feeBps: 500,
            restrictFeeRecipients: true
        });
        IERC1155SeaDrop(address(token_)).updatePublicDrop(publicDrop, 0);

        addSeaDropOfferItem(4, 2); // token id 4, 2 mints
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
                bytes20(address(this)),
                bytes1(0x00) // public drop index 0
            )
        });

        vm.deal(address(this), 4 ether);
        consideration.fulfillAdvancedOrder{ value: 2 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token_.balanceOf(address(this), 4), 2);
        assertTrue(token_.locked(4));

        vm.expectRevert(_tokenLocked(4));
        token_.safeTransferFrom(address(this), holder, 4, 1, "");

        // Minting through Seaport continues after the lock is permanent.
        token_.lockPermanently();
        consideration.fulfillAdvancedOrder{ value: 2 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token_.balanceOf(address(this), 4), 4);

        vm.expectRevert(_tokenLocked(4));
        token_.safeTransferFrom(address(this), holder, 4, 1, "");
    }

    function testHolderAndOperatorTransfersRevertWhileLocked() public {
        _setUp(LockMode.Locked);

        // Approvals still work while the lock is temporary.
        vm.prank(holder);
        token_.setApprovalForAll(operator, true);
        assertTrue(token_.isApprovedForAll(holder, operator));

        _assertHolderTransfersRevert(1);
        _assertHolderTransfersRevert(2);
    }

    function testBatchTransferRevertsOnFirstLockedId() public {
        _setUp(LockMode.Unlocked);
        token_.setTokensLocked(_asArray(2, 3), true);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        // Token id 1 is unlocked, so the batch reverts on token id 2.
        vm.prank(holder);
        vm.expectRevert(_tokenLocked(2));
        token_.safeBatchTransferFrom(
            holder, recipient, _asArray(1, 2, 3), amounts, ""
        );

        // A batch of only unlocked token ids succeeds.
        token_.setTokensLocked(_asArray(2), false);
        vm.prank(holder);
        token_.safeBatchTransferFrom(
            holder, recipient, _asArray(1, 2), _asArray(1, 1), ""
        );
        assertEq(token_.balanceOf(recipient, 1), 1);
        assertEq(token_.balanceOf(recipient, 2), 1);
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

        // Unlock token id 2 on its own while the default stays locked.
        vm.recordLogs();
        token_.setTokensLocked(_asArray(2), false);
        _assertLockEvents(_lockEvents(), _events(LockEvents.locked(2, false)));
        assertFalse(token_.locked(2));
        assertTrue(token_.locked(1));
        _assertTransferSucceeds(2);

        // Make the lock permanent. Token id 2 is locked again first.
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

        // Lock token ids 1 and 2 on their own, then unlock token id 2 again.
        token_.setTokensLocked(_asArray(1, 2), true);
        token_.setTokensLocked(_asArray(2), false);
        _assertHolderTransfersRevert(1);
        _assertTransferSucceeds(2);
        _assertTransferSucceeds(3);

        // The default is locked before PermanentlyLocked is emitted, and
        // only token id 2 needs a new Locked event.
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

    function testLockPermanentlyRelocksEveryUnlockedId() public {
        _setUp(LockMode.Locked);
        token_.mint(holder, 4, 1);
        token_.setMaxSupply(5, 1000);
        token_.mint(holder, 5, 1);

        // Unlock token ids 1 to 5, then lock token id 3 again.
        uint256[] memory ids = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            ids[i] = i + 1;
        }
        token_.setTokensLocked(ids, false);
        token_.setTokensLocked(_asArray(3), true);

        vm.recordLogs();
        token_.lockPermanently();
        LockEvent[] memory events = _lockEvents();

        // Token ids 1, 2, 4, and 5 are each locked again, in any order, before
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

        // Grant an approval while the lock is temporary.
        vm.prank(holder);
        token_.setApprovalForAll(operator, true);

        token_.lockPermanently();

        // New approvals revert.
        vm.prank(holder);
        vm.expectRevert(ERC8451Lockable.LockIsPermanent.selector);
        token_.setApprovalForAll(recipient, true);

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

        // Clearing approvals still works.
        token_.setApprovalForAll(operator, false);
        vm.stopPrank();
    }

    function testBurnWhileLocked() public {
        _setUp(LockMode.Locked);

        vm.prank(holder);
        token_.setApprovalForAll(operator, true);

        // The holder burns while the lock is temporary.
        vm.prank(holder);
        token_.burn(holder, 1, 4);

        token_.lockPermanently();

        // The holder burns after the lock is permanent.
        vm.prank(holder);
        token_.burn(holder, 1, 6);

        // An operator approved before the lock became permanent burns.
        vm.prank(operator);
        token_.batchBurn(holder, _asArray(2, 3), _asArray(10, 10));

        assertEq(token_.totalSupply(1), 0);
        assertEq(token_.totalSupply(2), 0);
        assertEq(token_.totalSupply(3), 0);

        // Token ids with no supply do not exist.
        vm.expectRevert(ERC8451Lockable.LockQueryForNonexistentToken.selector);
        token_.locked(1);
    }

    function testBurnWhilePermanentlyLockedFromDeploy() public {
        _setUp(LockMode.PermanentlyLocked);

        vm.prank(holder);
        token_.burn(holder, 1, 1);
        assertEq(token_.balanceOf(holder, 1), 9);

        // Without an approval, others cannot burn.
        vm.prank(operator);
        vm.expectRevert(ERC1155.NotOwnerNorApproved.selector);
        token_.burn(holder, 1, 1);
    }

    function testLockedRevertsForNonexistentToken() public {
        _setUp(LockMode.Locked);

        vm.expectRevert(ERC8451Lockable.LockQueryForNonexistentToken.selector);
        token_.locked(0);

        vm.expectRevert(ERC8451Lockable.LockQueryForNonexistentToken.selector);
        token_.locked(4);

        // Token ids that do not exist yet can have their own status.
        token_.setTokensLocked(_asArray(4), false);
        token_.mint(holder, 4, 2);
        assertFalse(token_.locked(4));
        _assertTransferSucceeds(4);
    }

    /// @dev The lifecycle from the Test Cases section of ERC-8451: a token
    ///      id is unlocked, its whole supply is burned, the contract is
    ///      locked permanently, and the token id is minted again.
    function testBurnWholeSupplyThenRemint() public {
        vm.recordLogs();

        // 1. The contract emits DefaultLocked(true) and mints token id 1.
        token_ = _deploy(LockMode.Locked);
        token = token_;
        token_.setMaxSupply(1, 1000);
        token_.mint(holder, 1, 5);

        // 2. The contract emits Locked(1, false). locked(1) returns false.
        token_.setTokensLocked(_asArray(1), false);
        assertFalse(token_.locked(1));

        // 3. The whole supply of token id 1 is burned. Token id 1 no longer
        //    exists, and locked(1) reverts.
        vm.prank(holder);
        token_.burn(holder, 1, 5);
        assertEq(token_.totalSupply(1), 0);
        vm.expectRevert(ERC8451Lockable.LockQueryForNonexistentToken.selector);
        token_.locked(1);

        // 4. The contract emits Locked(1, true) and then PermanentlyLocked().
        token_.lockPermanently();

        // 5. Token id 1 is minted again.
        token_.mint(holder, 1, 3);

        // 6. locked(1) and permanentlyLocked() return true, and the most
        //    recent Locked event for token id 1 locks it, so a consumer that
        //    replays ERC-6982 events also sees it as locked.
        assertTrue(token_.locked(1));
        assertTrue(token_.permanentlyLocked());
        LockEvent[] memory events = _lockEvents();
        LockEvent[] memory expected = new LockEvent[](5);
        expected[0] = LockEvents.defaultLocked(false);
        expected[1] = LockEvents.defaultLocked(true);
        expected[2] = LockEvents.locked(1, false);
        expected[3] = LockEvents.locked(1, true);
        expected[4] = LockEvents.permanentlyLocked();
        _assertLockEvents(events, expected);
        assertTrue(_replayErc6982(events, 1));

        // 7. A holder transfer of token id 1 reverts.
        _assertHolderTransfersRevert(1);
    }

    function testErc6982ReplayMatchesLockedAfterPermanence() public {
        vm.recordLogs();
        _setUp(LockMode.Unlocked);

        token_.setTokensLocked(_asArray(1, 2), false);
        token_.setTokensLocked(_asArray(3), true);
        token_.setDefaultLocked(true);
        token_.setDefaultLocked(false);
        token_.lockPermanently();
        token_.mint(holder, 4, 1);

        LockEvent[] memory events = _lockEvents();
        for (uint256 id = 1; id <= 4; id++) {
            assertTrue(token_.locked(id));
            assertTrue(_replayErc6982(events, id));
        }
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
        token_.safeTransferFrom(holder, recipient, 1, 1, "");

        token_.setTransferValidator(address(new MockTransferValidator(false)));
        _assertTransferSucceeds(1);
    }

    function testLockSetByTransferValidatorAppliesToTransfer() public {
        _setUp(LockMode.Unlocked);

        // The validator is also the owner, so it can lock during a transfer.
        LockingTransferValidator validator =
            new LockingTransferValidator(token_);
        token_.setTransferValidator(address(validator));
        token_.transferOwnership(address(validator));

        vm.startPrank(holder);
        vm.expectRevert(_tokenLocked(1));
        token_.safeTransferFrom(holder, recipient, 1, 1, "");

        vm.expectRevert(_tokenLocked(1));
        token_.safeBatchTransferFrom(
            holder, recipient, _asArray(1, 2), _asArray(1, 1), ""
        );
        vm.stopPrank();

        // The reverted transfers left the lock and balances unchanged.
        assertFalse(token_.permanentlyLocked());
        assertEq(token_.balanceOf(holder, 1), 10);
        assertEq(token_.balanceOf(recipient, 1), 0);
    }

    function testFuzzLockedMatchesLastEvent(
        bool defaultIsLocked,
        bool tokenOverrideSet,
        bool tokenIsLocked,
        bool lockPermanently
    ) public {
        vm.recordLogs();
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

        // Replaying the ERC-6982 events gives the same status.
        LockEvent[] memory events = _lockEvents();
        assertEq(_replayErc6982(events, 1), expected);
        assertEq(_replayErc6982(events, 2), token_.locked(2));

        if (expected) {
            _assertHolderTransfersRevert(1);
        } else {
            _assertTransferSucceeds(1);
        }
    }
}
