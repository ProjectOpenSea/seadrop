// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropV3TestHelper } from "./utils/SeaDropV3TestHelper.sol";

import {
    TestExistingERC721,
    TestMinimalERC721,
    TestFallbackERC721,
    TestRoyaltyERC721,
    TestForwardingReceiver,
    TestReentrantAdapterMinter,
    TestRedepositingOwner,
    IOwnerMint
} from "./utils/AdapterMocks.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { ISeaDropTokenV3 } from "seadrop/v3/interfaces/ISeaDropTokenV3.sol";

import {
    ERC721SeaDropV3Adapter
} from "seadrop/v3/adapters/ERC721SeaDropV3Adapter.sol";

import {
    ERC721SeaDropV3MintAdapter
} from "seadrop/v3/adapters/ERC721SeaDropV3MintAdapter.sol";

import {
    ERC721SeaDropV3TransferAdapter
} from "seadrop/v3/adapters/ERC721SeaDropV3TransferAdapter.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

import { IERC2981 } from "openzeppelin-contracts/interfaces/IERC2981.sol";

import { IERC721 } from "openzeppelin-contracts/token/ERC721/IERC721.sol";

import {
    IERC721Receiver
} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @dev Adapters run a SeaDropMinter drop for an existing ERC-721. The test
 *      contract owns the existing collection, which already minted 10
 *      tokens, and owns the adapters, so it configures their drops on the
 *      minter directly.
 */
contract SeaDropV3AdaptersTest is SeaDropV3TestHelper {
    event SeaDropShimDeployed(address indexed tokenContract);

    TestExistingERC721 internal existing;

    function setUp() public override {
        super.setUp();
        existing = new TestExistingERC721();
        existing.mintTo(address(this), 10);
    }

    // ---------------------------------------------------------------------
    // Setup helpers
    // ---------------------------------------------------------------------

    function _configure(ERC721SeaDropV3Adapter adapter, uint256 supply)
        internal
    {
        adapter.setMaxSupply(supply);
        _setSinglePayout(address(adapter), creator);
        minter.setStage(address(adapter), 0, 0, _publicStage());
    }

    function _newMintAdapter() internal returns (ERC721SeaDropV3MintAdapter) {
        ERC721SeaDropV3MintAdapter adapter = new ERC721SeaDropV3MintAdapter(
            address(existing),
            TestExistingERC721.mintTo.selector,
            address(minter),
            address(this)
        );
        existing.setMinter(address(adapter), true);
        _configure(adapter, 60);
        return adapter;
    }

    function _newTransferAdapter(uint256 deposit)
        internal
        returns (ERC721SeaDropV3TransferAdapter adapter)
    {
        adapter = new ERC721SeaDropV3TransferAdapter(
            address(existing), address(minter), address(this)
        );
        _configure(adapter, 60);
        if (deposit != 0) existing.mintTo(address(adapter), deposit);
    }

    function _mint(address adapter, address wallet, uint256 quantity) internal {
        vm.prank(wallet);
        minter.mint{ value: PRICE * quantity }(
            _params(adapter, 0, wallet, wallet, quantity), _noAuth()
        );
    }

    // ---------------------------------------------------------------------
    // Mint adapter
    // ---------------------------------------------------------------------

    function test_mintAdapter_publicMint() public {
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();

        vm.expectEmit(address(minter));
        emit ISeaDropMinter.SeaDropMint(
            address(adapter),
            0,
            0,
            alice,
            alice,
            alice,
            3,
            PRICE,
            address(0),
            feeRecipient,
            FEE_BPS
        );
        _mint(address(adapter), alice, 3);

        // The tokens are minted on the existing collection, continuing its
        // token ids.
        assertEq(existing.balanceOf(alice), 3);
        assertEq(existing.ownerOf(11), alice);
        assertEq(existing.ownerOf(13), alice);
        assertEq(existing.totalSupply(), 13);

        (uint256 minted, uint256 max) = adapter.mintStats(0);
        assertEq(minted, 3);
        assertEq(max, 60);
        assertEq(adapter.totalMinted(), 3);
        assertEq(minter.mintedByWallet(address(adapter), 0, alice), 3);

        // The minter pays the fee recipient and the creator as usual.
        uint256 fee = PRICE * 3 * FEE_BPS / 10_000;
        assertEq(feeRecipient.balance, fee);
        assertEq(creator.balance, PRICE * 3 - fee);
    }

    function test_mintAdapter_enforcesDropSupply() public {
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();
        adapter.setMaxSupply(4);
        _mint(address(adapter), alice, 4);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3Adapter.MintQuantityExceedsMaxSupply.selector,
                5,
                4
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(adapter), 0, bob, bob, 1), _noAuth()
        );
    }

    /// @dev A stage cap compares against this drop's mints, not the
    ///      target's 10 earlier tokens.
    function test_mintAdapter_stageCapCountsThisDropOnly() public {
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.maxTokenSupplyForStage = 4;
        minter.setStage(address(adapter), 0, 0, stage);

        _mint(address(adapter), alice, 4);
        assertEq(existing.totalSupply(), 14);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.MintQuantityExceedsMaxTokenSupplyForStage
                .selector,
                5,
                4
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(adapter), 0, bob, bob, 1), _noAuth()
        );
    }

    /// @dev The adapter isn't an ERC-721, so the minter accepts a stage at
    ///      another id, but the adapter refuses to mint for it.
    function test_mintAdapter_rejectsIdNotZero() public {
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();
        minter.setStage(address(adapter), 1, 0, _publicStage());

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC721SeaDropV3Adapter.IdNotZero.selector, 1)
        );
        minter.mint{ value: PRICE }(
            _params(address(adapter), 1, alice, alice, 1), _noAuth()
        );
    }

    function test_mintAdapter_onlyAllowedMinter() public {
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();

        vm.prank(carol);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3Adapter.OnlyAllowedMinter.selector, carol
            )
        );
        adapter.mintSeaDrop(carol, 0, 1);

        adapter.setAllowedMinter(address(minter), false);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3Adapter.OnlyAllowedMinter.selector,
                address(minter)
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(adapter), 0, alice, alice, 1), _noAuth()
        );
    }

    /// @dev A target that refuses the adapter reverts the whole mint, so
    ///      the payer keeps their payment.
    function test_mintAdapter_bubblesTargetRevert() public {
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();
        existing.setMinter(address(adapter), false);
        uint256 balance = alice.balance;

        vm.prank(alice);
        vm.expectRevert(TestExistingERC721.NotMinter.selector);
        minter.mint{ value: PRICE }(
            _params(address(adapter), 0, alice, alice, 1), _noAuth()
        );
        assertEq(alice.balance, balance);
    }

    function test_mintAdapter_rejectsWrongMintShape() public {
        // mintTokenId takes a token id, not a quantity, so it mints one
        // token whatever the quantity.
        ERC721SeaDropV3MintAdapter adapter = new ERC721SeaDropV3MintAdapter(
            address(existing),
            TestExistingERC721.mintTokenId.selector,
            address(minter),
            address(this)
        );
        existing.setMinter(address(adapter), true);
        _configure(adapter, 60);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3MintAdapter.UnexpectedMintCount.selector, 2, 1
            )
        );
        minter.mint{ value: PRICE * 2 }(
            _params(address(adapter), 0, alice, alice, 2), _noAuth()
        );
    }

    function test_mintAdapter_countsBySupply() public {
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();
        assertTrue(adapter.countsBySupply());

        // A recipient that forwards tokens in its callback keeps none, but
        // the target's supply still shows the full mint.
        address vault = makeAddr("vault");
        TestForwardingReceiver wallet = new TestForwardingReceiver(vault);
        vm.deal(address(wallet), 1 ether);
        _mint(address(adapter), address(wallet), 2);
        assertEq(existing.balanceOf(address(wallet)), 0);
        assertEq(existing.balanceOf(vault), 2);
    }

    function test_mintAdapter_countsByBalanceWithoutSupply() public {
        TestMinimalERC721 minimal = new TestMinimalERC721();
        ERC721SeaDropV3MintAdapter adapter = new ERC721SeaDropV3MintAdapter(
            address(minimal),
            TestMinimalERC721.mintTo.selector,
            address(minter),
            address(this)
        );
        assertFalse(adapter.countsBySupply());
        _configure(adapter, 60);

        _mint(address(adapter), alice, 3);
        assertEq(minimal.balanceOf(alice), 3);
        assertEq(adapter.totalMinted(), 3);
    }

    /// @dev The adapter's owner mints through the minter without payment,
    ///      as a token's owner does, and the mint counts toward the drop.
    function test_mintAdapter_ownerMint() public {
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();
        minter.ownerMint(address(adapter), 0, carol, 2);
        assertEq(existing.balanceOf(carol), 2);
        assertEq(adapter.totalMinted(), 2);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.OnlyTokenOwner.selector, address(adapter), alice
            )
        );
        minter.ownerMint(address(adapter), 0, alice, 1);
    }

    /// @dev A second allowed minter that reenters from the recipient's
    ///      callback hits the adapter's own guard.
    function test_mintAdapter_rejectsReentry() public {
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();
        TestReentrantAdapterMinter reentrant = new TestReentrantAdapterMinter();
        adapter.setAllowedMinter(address(reentrant), true);

        vm.expectRevert(ERC721SeaDropV3Adapter.Reentrancy.selector);
        reentrant.mint(adapter, 1);
    }

    // ---------------------------------------------------------------------
    // Shared adapter behavior
    // ---------------------------------------------------------------------

    function test_deployEmitsShimEvent() public {
        vm.expectEmit();
        emit SeaDropShimDeployed(address(existing));
        ERC721SeaDropV3MintAdapter adapter = new ERC721SeaDropV3MintAdapter(
            address(existing),
            TestExistingERC721.mintTo.selector,
            address(minter),
            alice
        );
        assertEq(adapter.owner(), alice);
        assertEq(adapter.target(), address(existing));
        assertTrue(adapter.allowedMinters(address(minter)));
        // Adapters are standalone, not the factory's clones.
        assertEq(minter.tokenFactoryOf(address(adapter)), address(0));
    }

    function test_revert_targetMustHaveCode() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3Adapter.TargetHasNoCode.selector, carol
            )
        );
        new ERC721SeaDropV3MintAdapter(
            carol, bytes4(0), address(minter), address(this)
        );
    }

    /// @dev The minter checks the adapter's owner, so only it configures the
    ///      drop, and only it changes the adapter's settings.
    function test_onlyOwnerConfigures() public {
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();
        ISeaDropMinter.Stage memory stage = _publicStage();

        vm.startPrank(carol);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.OnlyTokenOwner.selector, address(adapter), carol
            )
        );
        minter.setStage(address(adapter), 0, 0, stage);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.OnlyTokenOwner.selector, address(adapter), carol
            )
        );
        minter.setPayoutRecipients(
            address(adapter), new ISeaDropMinter.PayoutRecipient[](0)
        );
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.setMaxSupply(1000);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.setAllowedMinter(carol, true);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.setContractURI("x");
        vm.stopPrank();
    }

    function test_settings() public {
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();

        adapter.setContractURI("ipfs://drop");
        assertEq(adapter.contractURI(), "ipfs://drop");

        _mint(address(adapter), alice, 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3Adapter.MaxSupplyBelowTotalMinted.selector, 1, 2
            )
        );
        adapter.setMaxSupply(1);
        assertEq(adapter.maxSupply(), 60);

        adapter.transferOwnership(alice);
        adapter.renounceOwnership();
        vm.prank(alice);
        vm.expectRevert(TwoStepOwnable.NotNextOwner.selector);
        adapter.acceptOwnership();
    }

    function test_royaltyReadsTheTarget() public {
        // No EIP-2981 on the existing collection.
        ERC721SeaDropV3MintAdapter adapter = _newMintAdapter();
        (address receiver, uint256 amount) = adapter.royaltyInfo(1, 1 ether);
        assertEq(receiver, address(0));
        assertEq(amount, 0);

        // A target with a royalty.
        TestRoyaltyERC721 royalty = new TestRoyaltyERC721(carol);
        adapter = new ERC721SeaDropV3MintAdapter(
            address(royalty),
            TestMinimalERC721.mintTo.selector,
            address(minter),
            address(this)
        );
        (receiver, amount) = adapter.royaltyInfo(1, 1 ether);
        assertEq(receiver, carol);
        assertEq(amount, 0.05 ether);
    }

    /// @dev The fallback answers royaltyInfo with empty returndata, which
    ///      the adapter reads as no royalty instead of reverting.
    function test_royaltyWithFallbackTarget() public {
        TestFallbackERC721 fallbackTarget = new TestFallbackERC721();
        ERC721SeaDropV3MintAdapter adapter = new ERC721SeaDropV3MintAdapter(
            address(fallbackTarget),
            TestMinimalERC721.mintTo.selector,
            address(minter),
            address(this)
        );
        (address receiver, uint256 amount) = adapter.royaltyInfo(1, 1 ether);
        assertEq(receiver, address(0));
        assertEq(amount, 0);
        assertFalse(adapter.countsBySupply());
    }

    function test_supportsInterface() public {
        ERC721SeaDropV3MintAdapter mintAdapter = _newMintAdapter();
        ERC721SeaDropV3TransferAdapter transferAdapter = _newTransferAdapter(0);

        bytes4 v3 = type(ISeaDropTokenV3).interfaceId;
        assertTrue(mintAdapter.supportsInterface(v3));
        assertTrue(transferAdapter.supportsInterface(v3));
        assertTrue(mintAdapter.supportsInterface(type(IERC2981).interfaceId));
        assertTrue(mintAdapter.supportsInterface(0x01ffc9a7));
        assertTrue(
            transferAdapter.supportsInterface(type(IERC721Receiver).interfaceId)
        );
        assertFalse(
            mintAdapter.supportsInterface(type(IERC721Receiver).interfaceId)
        );
        // Not an ERC-721 itself.
        assertFalse(mintAdapter.supportsInterface(0x80ac58cd));
        assertFalse(mintAdapter.supportsInterface(0xffffffff));
    }

    // ---------------------------------------------------------------------
    // Transfer adapter
    // ---------------------------------------------------------------------

    function test_transferAdapter_sellsQueuedTokensInOrder() public {
        ERC721SeaDropV3TransferAdapter adapter = _newTransferAdapter(5);
        assertEq(adapter.queuedTokenCount(), 5);

        // The drop can sell only the 5 tokens it holds.
        (, uint256 max) = adapter.mintStats(0);
        assertEq(max, 5);

        _mint(address(adapter), alice, 2);
        assertEq(existing.ownerOf(11), alice);
        assertEq(existing.ownerOf(12), alice);
        assertEq(adapter.queuedTokenCount(), 3);
        assertFalse(adapter.isQueued(11));

        uint256[] memory queued = adapter.queuedTokenIds();
        assertEq(queued.length, 3);
        assertEq(queued[0], 13);
        assertEq(queued[2], 15);

        _mint(address(adapter), alice, 3);
        assertEq(existing.balanceOf(alice), 5);
        assertEq(existing.ownerOf(15), alice);
        assertEq(creator.balance, PRICE * 5 * (10_000 - FEE_BPS) / 10_000);

        // The queue is empty, so another wallet can't mint either.
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3Adapter.MintQuantityExceedsMaxSupply.selector,
                6,
                5
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(adapter), 0, bob, bob, 1), _noAuth()
        );
    }

    function test_transferAdapter_maxSupplyBelowQueue() public {
        ERC721SeaDropV3TransferAdapter adapter = _newTransferAdapter(5);
        adapter.setMaxSupply(2);
        (, uint256 max) = adapter.mintStats(0);
        assertEq(max, 2);
    }

    function test_transferAdapter_ownerTransferQueues() public {
        ERC721SeaDropV3TransferAdapter adapter = _newTransferAdapter(0);
        existing.safeTransferFrom(address(this), address(adapter), 4);
        uint256[] memory queued = adapter.queuedTokenIds();
        assertEq(queued.length, 1);
        assertEq(queued[0], 4);
        assertTrue(adapter.isQueued(4));
    }

    function test_transferAdapter_rejectsOtherDeposits() public {
        ERC721SeaDropV3TransferAdapter adapter = _newTransferAdapter(0);

        existing.transferFrom(address(this), carol, 1);
        vm.prank(carol);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3TransferAdapter.OnlyOwnerCanDeposit.selector,
                carol,
                carol
            )
        );
        existing.safeTransferFrom(carol, address(adapter), 1);

        vm.prank(carol);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3TransferAdapter.OnlyTarget.selector, carol
            )
        );
        adapter.onERC721Received(address(this), address(this), 1, "");
    }

    /// @dev A mint without the receiver callback leaves the tokens
    ///      unqueued, so the drop can't sell them and rescue returns them.
    function test_transferAdapter_unsafeMintIsNotQueued() public {
        ERC721SeaDropV3TransferAdapter adapter = _newTransferAdapter(0);
        existing.mintUnsafe(address(adapter), 2);
        assertEq(adapter.queuedTokenCount(), 0);
        (, uint256 max) = adapter.mintStats(0);
        assertEq(max, 0);

        adapter.rescue(11, carol);
        assertEq(existing.ownerOf(11), carol);
    }

    function test_transferAdapter_withdrawAndRescue() public {
        ERC721SeaDropV3TransferAdapter adapter = _newTransferAdapter(5);
        _mint(address(adapter), alice, 1);

        // Withdraw takes from the back of the queue.
        adapter.withdraw(creator, 2);
        assertEq(existing.ownerOf(15), creator);
        assertEq(existing.ownerOf(14), creator);
        assertEq(adapter.queuedTokenCount(), 2);
        (, uint256 max) = adapter.mintStats(0);
        assertEq(max, 3);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3TransferAdapter.NotEnoughQueuedTokens.selector,
                3,
                2
            )
        );
        adapter.withdraw(creator, 3);

        // A token sent without safeTransferFrom isn't queued, and only
        // rescue gets it back.
        existing.transferFrom(address(this), address(adapter), 1);
        assertEq(adapter.queuedTokenCount(), 2);
        adapter.rescue(1, creator);
        assertEq(existing.ownerOf(1), creator);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3TransferAdapter.TokenIsQueued.selector, 12
            )
        );
        adapter.rescue(12, creator);

        vm.startPrank(carol);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.withdraw(carol, 1);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.rescue(12, carol);
        vm.stopPrank();
    }

    /// @dev A token can't be queued while the adapter is transferring one
    ///      out, even when its owner sends it from the delivery callback.
    function test_transferAdapter_rejectsDepositDuringDelivery() public {
        TestRedepositingOwner owner_ = new TestRedepositingOwner();
        ERC721SeaDropV3TransferAdapter adapter = new ERC721SeaDropV3TransferAdapter(
            address(existing), address(minter), address(owner_)
        );
        owner_.setAdapter(address(adapter));
        existing.transferFrom(address(this), address(owner_), 1);
        owner_.deposit(IERC721(address(existing)), 1);
        assertEq(adapter.queuedTokenCount(), 1);
        vm.prank(address(owner_));
        adapter.setMaxSupply(10);

        vm.expectRevert(
            ERC721SeaDropV3TransferAdapter.DepositDuringTransfer.selector
        );
        owner_.ownerMintAndRedeposit(IOwnerMint(address(minter)));
        assertEq(existing.ownerOf(1), address(adapter));
        assertEq(adapter.queuedTokenCount(), 1);
    }

    /// @dev Renouncing would leave held tokens with no way out, so it
    ///      waits until the adapter holds none, queued or not.
    function test_transferAdapter_renounceNeedsNoTokens() public {
        ERC721SeaDropV3TransferAdapter adapter = _newTransferAdapter(2);
        existing.transferFrom(address(this), address(adapter), 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3TransferAdapter.StillHoldsTokens.selector, 3
            )
        );
        adapter.renounceOwnership();

        adapter.withdraw(carol, 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3TransferAdapter.StillHoldsTokens.selector, 1
            )
        );
        adapter.renounceOwnership();

        adapter.rescue(1, carol);
        adapter.renounceOwnership();
        assertEq(adapter.owner(), address(0));

        vm.prank(carol);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.renounceOwnership();
    }

    /// @dev The adapter approves no operator, so the collection's conduit,
    ///      or anyone else, can't move the tokens it holds.
    function test_transferAdapter_grantsNoApproval() public {
        ERC721SeaDropV3TransferAdapter adapter = _newTransferAdapter(2);
        assertFalse(existing.isApprovedForAll(address(adapter), CONDUIT));
        assertEq(existing.getApproved(11), address(0));

        vm.prank(CONDUIT);
        vm.expectRevert();
        existing.transferFrom(address(adapter), CONDUIT, 11);
    }

    /// @dev Lets the test contract receive tokens it mints for itself.
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}
