// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { Test } from "forge-std/Test.sol";

import { SeaDrop } from "seadrop/SeaDrop.sol";

import { SeaDropErrorsAndEvents } from "seadrop/lib/SeaDropErrorsAndEvents.sol";

import {
    INonFungibleSeaDropToken,
    ISeaDropTokenContractMetadata
} from "seadrop/interfaces/INonFungibleSeaDropToken.sol";

import {
    MintParams,
    PublicDrop,
    SignedMintValidationParams
} from "seadrop/lib/SeaDropStructs.sol";

import {
    ERC721SeaDropAdapter
} from "seadrop/adapters/ERC721SeaDropAdapter.sol";

import {
    ERC721SeaDropMintAdapter
} from "seadrop/adapters/ERC721SeaDropMintAdapter.sol";

import {
    ERC721SeaDropTransferAdapter
} from "seadrop/adapters/ERC721SeaDropTransferAdapter.sol";

import { TestExistingERC721 } from "seadrop/test/TestExistingERC721.sol";

import { TestMinimalERC721 } from "seadrop/test/TestMinimalERC721.sol";

import { TestFallbackERC721 } from "seadrop/test/TestFallbackERC721.sol";

import {
    TestForwardingReceiver
} from "seadrop/test/TestForwardingReceiver.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

import {
    IERC721Receiver
} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

contract ERC721SeaDropAdapterTest is Test, SeaDropErrorsAndEvents {
    SeaDrop seadrop;
    TestExistingERC721 existing;

    address creator = makeAddr("creator");
    address feeRecipient = makeAddr("feeRecipient");
    address minter = makeAddr("minter");
    address stranger = makeAddr("stranger");

    uint80 constant PRICE = 0.01 ether;

    function setUp() public {
        seadrop = new SeaDrop();
        // The test contract owns the existing collection, as its creator
        // would, and has already minted 10 tokens from it.
        existing = new TestExistingERC721();
        existing.mintTo(address(this), 10);
        vm.deal(minter, 10 ether);
    }

    function _allowedSeaDrop() internal view returns (address[] memory a) {
        a = new address[](1);
        a[0] = address(seadrop);
    }

    function _publicDrop() internal view returns (PublicDrop memory) {
        return PublicDrop({
            mintPrice: PRICE,
            startTime: uint48(block.timestamp),
            endTime: uint48(block.timestamp + 1 days),
            maxTotalMintableByWallet: 5,
            feeBps: 500,
            restrictFeeRecipients: false
        });
    }

    function _configure(ERC721SeaDropAdapter adapter, uint256 supply) internal {
        adapter.setMaxSupply(supply);
        adapter.updateCreatorPayoutAddress(address(seadrop), creator);
        adapter.updatePublicDrop(address(seadrop), _publicDrop());
    }

    function _mintPublic(address nftContract, uint256 quantity) internal {
        vm.prank(minter);
        seadrop.mintPublic{ value: PRICE * quantity }(
            nftContract, feeRecipient, address(0), quantity
        );
    }

    function _newMintAdapter() internal returns (ERC721SeaDropMintAdapter) {
        ERC721SeaDropMintAdapter adapter = new ERC721SeaDropMintAdapter(
            address(existing),
            TestExistingERC721.mintTo.selector,
            _allowedSeaDrop()
        );
        existing.setMinter(address(adapter), true);
        _configure(adapter, 60);
        return adapter;
    }

    function _newTransferAdapter(uint256 deposit)
        internal
        returns (ERC721SeaDropTransferAdapter adapter)
    {
        adapter = new ERC721SeaDropTransferAdapter(
            address(existing), _allowedSeaDrop()
        );
        _configure(adapter, 60);
        if (deposit != 0) existing.mintTo(address(adapter), deposit);
    }

    // Mint adapter

    function testMintAdapterPublicMint() public {
        ERC721SeaDropMintAdapter adapter = _newMintAdapter();

        vm.expectEmit(true, true, true, true, address(seadrop));
        emit SeaDropMint(
            address(adapter),
            minter,
            feeRecipient,
            minter,
            3,
            PRICE,
            500,
            0
        );
        _mintPublic(address(adapter), 3);

        // The tokens are minted on the existing collection, continuing its
        // token IDs.
        assertEq(existing.balanceOf(minter), 3);
        assertEq(existing.ownerOf(11), minter);
        assertEq(existing.ownerOf(13), minter);
        assertEq(existing.totalSupply(), 13);

        (uint256 numMinted, uint256 total, uint256 max) =
            adapter.getMintStats(minter);
        assertEq(numMinted, 3);
        assertEq(total, 3);
        assertEq(max, 60);
        assertEq(adapter.totalMinted(), 3);

        // SeaDrop pays the creator and fee recipient as usual.
        uint256 fee = (uint256(PRICE) * 3 * 500) / 10_000;
        assertEq(feeRecipient.balance, fee);
        assertEq(creator.balance, uint256(PRICE) * 3 - fee);
    }

    function testMintAdapterEnforcesDropSupply() public {
        ERC721SeaDropMintAdapter adapter = _newMintAdapter();
        adapter.setMaxSupply(4);

        _mintPublic(address(adapter), 4);

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 5, 4)
        );
        seadrop.mintPublic{ value: PRICE }(
            address(adapter), feeRecipient, address(0), 1
        );
    }

    function testMintAdapterOnlyAllowedSeaDrop() public {
        ERC721SeaDropMintAdapter adapter = _newMintAdapter();

        vm.prank(stranger);
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        adapter.mintSeaDrop(stranger, 1);

        address[] memory none = new address[](0);
        adapter.updateAllowedSeaDrop(none);
        vm.prank(minter);
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        seadrop.mintPublic{ value: PRICE }(
            address(adapter), feeRecipient, address(0), 1
        );
    }

    function testMintAdapterBubblesTargetRevert() public {
        ERC721SeaDropMintAdapter adapter = _newMintAdapter();
        existing.setMinter(address(adapter), false);

        vm.prank(minter);
        vm.expectRevert(TestExistingERC721.NotMinter.selector);
        seadrop.mintPublic{ value: PRICE }(
            address(adapter), feeRecipient, address(0), 1
        );
    }

    function testMintAdapterRejectsWrongMintShape() public {
        // mintTokenId takes a token ID, not a quantity, so it mints one
        // token whatever the quantity.
        ERC721SeaDropMintAdapter adapter = new ERC721SeaDropMintAdapter(
            address(existing),
            TestExistingERC721.mintTokenId.selector,
            _allowedSeaDrop()
        );
        existing.setMinter(address(adapter), true);
        _configure(adapter, 60);

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropMintAdapter.UnexpectedMintCount.selector, 2, 1
            )
        );
        seadrop.mintPublic{ value: PRICE * 2 }(
            address(adapter), feeRecipient, address(0), 2
        );
    }

    function testMintAdapterCountsBySupply() public {
        ERC721SeaDropMintAdapter adapter = _newMintAdapter();
        assertTrue(adapter.countsBySupply());

        // A recipient that forwards tokens in its callback keeps none, but
        // the target's supply still shows the full mint.
        address vault = makeAddr("vault");
        TestForwardingReceiver wallet = new TestForwardingReceiver(vault);
        vm.deal(address(wallet), 1 ether);
        vm.prank(address(wallet));
        seadrop.mintPublic{ value: PRICE * 2 }(
            address(adapter), feeRecipient, address(0), 2
        );
        assertEq(existing.balanceOf(address(wallet)), 0);
        assertEq(existing.balanceOf(vault), 2);
    }

    function testMintAdapterCountsByBalanceWithoutSupply() public {
        TestMinimalERC721 minimal = new TestMinimalERC721();
        ERC721SeaDropMintAdapter adapter = new ERC721SeaDropMintAdapter(
            address(minimal),
            TestMinimalERC721.mintTo.selector,
            _allowedSeaDrop()
        );
        assertFalse(adapter.countsBySupply());
        _configure(adapter, 60);

        _mintPublic(address(adapter), 3);
        assertEq(minimal.balanceOf(minter), 3);
        assertEq(adapter.totalMinted(), 3);
    }

    function testMintAdapterSignedMint() public {
        ERC721SeaDropMintAdapter adapter = _newMintAdapter();
        (address signer, uint256 signerKey) = makeAddrAndKey("signer");
        adapter.updateSignedMintValidationParams(
            address(seadrop),
            signer,
            SignedMintValidationParams({
                minMintPrice: 0,
                maxMaxTotalMintableByWallet: 10,
                minStartTime: 0,
                maxEndTime: type(uint40).max,
                maxMaxTokenSupplyForStage: 60,
                minFeeBps: 0,
                maxFeeBps: 1000
            })
        );

        MintParams memory params = MintParams({
            mintPrice: PRICE,
            maxTotalMintableByWallet: 5,
            startTime: block.timestamp,
            endTime: block.timestamp + 1 days,
            dropStageIndex: 1,
            maxTokenSupplyForStage: 60,
            feeBps: 500,
            restrictFeeRecipients: true
        });
        adapter.updateAllowedFeeRecipient(address(seadrop), feeRecipient, true);
        bytes memory signature = _signMint(
            signerKey, address(adapter), minter, feeRecipient, params, 1
        );

        vm.prank(minter);
        seadrop.mintSigned{ value: PRICE * 2 }(
            address(adapter), feeRecipient, address(0), 2, params, 1, signature
        );
        assertEq(existing.balanceOf(minter), 2);
        assertEq(existing.ownerOf(11), minter);
        assertEq(adapter.totalMinted(), 2);
    }

    /// @dev Sign a SeaDrop v1 signed mint, as OpenSea's signer would.
    function _signMint(
        uint256 key,
        address nftContract,
        address mintFor,
        address fee,
        MintParams memory p,
        uint256 salt
    ) internal view returns (bytes memory) {
        bytes32 mintParamsHash = keccak256(
            abi.encode(
                keccak256(
                    "MintParams(uint256 mintPrice,uint256 maxTotalMintableByWallet,uint256 startTime,uint256 endTime,uint256 dropStageIndex,uint256 maxTokenSupplyForStage,uint256 feeBps,bool restrictFeeRecipients)"
                ),
                p.mintPrice,
                p.maxTotalMintableByWallet,
                p.startTime,
                p.endTime,
                p.dropStageIndex,
                p.maxTokenSupplyForStage,
                p.feeBps,
                p.restrictFeeRecipients
            )
        );
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("SeaDrop"),
                keccak256("1.0"),
                block.chainid,
                address(seadrop)
            )
        );
        bytes32 digest = keccak256(
            bytes.concat(
                bytes2(0x1901),
                domainSeparator,
                keccak256(
                    abi.encode(
                        keccak256(
                            "SignedMint(address nftContract,address minter,address feeRecipient,MintParams mintParams,uint256 salt)MintParams(uint256 mintPrice,uint256 maxTotalMintableByWallet,uint256 startTime,uint256 endTime,uint256 dropStageIndex,uint256 maxTokenSupplyForStage,uint256 feeBps,bool restrictFeeRecipients)"
                        ),
                        nftContract,
                        mintFor,
                        fee,
                        mintParamsHash,
                        salt
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 sig) = vm.sign(key, digest);
        return abi.encodePacked(r, sig, v);
    }

    function testDeployEmitsShimEvent() public {
        vm.expectEmit(true, true, true, true);
        emit ERC721SeaDropAdapter.SeaDropShimDeployed(address(existing));
        new ERC721SeaDropMintAdapter(
            address(existing),
            TestExistingERC721.mintTo.selector,
            _allowedSeaDrop()
        );
    }

    function testMintAdapterTargetMustHaveCode() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropAdapter.TargetHasNoCode.selector, stranger
            )
        );
        new ERC721SeaDropMintAdapter(stranger, bytes4(0), _allowedSeaDrop());
    }

    // Shared adapter settings

    function testOnlyOwnerConfigures() public {
        ERC721SeaDropMintAdapter adapter = _newMintAdapter();
        PublicDrop memory publicDrop = _publicDrop();

        vm.startPrank(stranger);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.updatePublicDrop(address(seadrop), publicDrop);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.updateCreatorPayoutAddress(address(seadrop), stranger);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.setMaxSupply(1000);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.updateAllowedSeaDrop(new address[](0));
        vm.stopPrank();

        // A SeaDrop that isn't allowed can't be configured.
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        adapter.updatePublicDrop(stranger, publicDrop);
    }

    function testMetadataSettings() public {
        ERC721SeaDropMintAdapter adapter = _newMintAdapter();

        vm.expectRevert(ERC721SeaDropAdapter.NotSupportedByAdapter.selector);
        adapter.setBaseURI("ipfs://x/");
        ISeaDropTokenContractMetadata.RoyaltyInfo memory info;
        vm.expectRevert(ERC721SeaDropAdapter.NotSupportedByAdapter.selector);
        adapter.setRoyaltyInfo(info);
        assertEq(adapter.baseURI(), "");

        // The existing collection has no EIP-2981 royalty.
        (address receiver, uint256 amount) = adapter.royaltyInfo(1, 1 ether);
        assertEq(receiver, address(0));
        assertEq(amount, 0);
        assertEq(adapter.royaltyAddress(), address(0));
        assertEq(adapter.royaltyBasisPoints(), 0);

        adapter.setContractURI("ipfs://drop");
        assertEq(adapter.contractURI(), "ipfs://drop");

        adapter.setProvenanceHash(bytes32(uint256(1)));
        assertEq(adapter.provenanceHash(), bytes32(uint256(1)));
        _mintPublic(address(adapter), 2);
        vm.expectRevert(
            ISeaDropTokenContractMetadata.ProvenanceHashCannotBeSetAfterMintStarted
                .selector
        );
        adapter.setProvenanceHash(bytes32(uint256(2)));

        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropTokenContractMetadata.NewMaxSupplyCannotBeLessThenTotalMinted
                    .selector,
                1,
                2
            )
        );
        adapter.setMaxSupply(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropTokenContractMetadata.CannotExceedMaxSupplyOfUint64
                .selector,
                2 ** 64
            )
        );
        adapter.setMaxSupply(2 ** 64);
        assertEq(adapter.maxSupply(), 60);
    }

    function testRoyaltyGettersWithFallbackTarget() public {
        // The fallback answers royaltyInfo with empty returndata, which the
        // adapter treats as no royalty instead of reverting.
        TestFallbackERC721 target = new TestFallbackERC721();
        ERC721SeaDropMintAdapter adapter = new ERC721SeaDropMintAdapter(
            address(target),
            TestMinimalERC721.mintTo.selector,
            _allowedSeaDrop()
        );
        (address receiver, uint256 amount) = adapter.royaltyInfo(1, 1 ether);
        assertEq(receiver, address(0));
        assertEq(amount, 0);
        assertEq(adapter.royaltyAddress(), address(0));
        assertEq(adapter.royaltyBasisPoints(), 0);
        assertFalse(adapter.countsBySupply());
    }

    function testSupportsInterface() public {
        ERC721SeaDropMintAdapter mintAdapter = _newMintAdapter();
        ERC721SeaDropTransferAdapter transferAdapter = _newTransferAdapter(0);

        bytes4 seaDropId = type(INonFungibleSeaDropToken).interfaceId;
        assertTrue(mintAdapter.supportsInterface(seaDropId));
        assertTrue(transferAdapter.supportsInterface(seaDropId));
        assertTrue(
            mintAdapter.supportsInterface(
                type(ISeaDropTokenContractMetadata).interfaceId
            )
        );
        assertTrue(
            transferAdapter.supportsInterface(type(IERC721Receiver).interfaceId)
        );
        assertFalse(
            mintAdapter.supportsInterface(type(IERC721Receiver).interfaceId)
        );
        assertFalse(mintAdapter.supportsInterface(0xffffffff));
    }

    // Transfer adapter

    function testTransferAdapterSellsQueuedTokensInOrder() public {
        ERC721SeaDropTransferAdapter adapter = _newTransferAdapter(5);
        assertEq(adapter.queuedTokenCount(), 5);

        // The drop can sell only the 5 tokens it holds.
        (,, uint256 max) = adapter.getMintStats(minter);
        assertEq(max, 5);

        _mintPublic(address(adapter), 2);
        assertEq(existing.ownerOf(11), minter);
        assertEq(existing.ownerOf(12), minter);
        assertEq(adapter.queuedTokenCount(), 3);

        uint256[] memory queued = adapter.queuedTokenIds();
        assertEq(queued.length, 3);
        assertEq(queued[0], 13);
        assertEq(queued[2], 15);

        _mintPublic(address(adapter), 3);
        assertEq(existing.balanceOf(minter), 5);
        assertEq(existing.ownerOf(15), minter);

        // The queue is empty, so another wallet can't mint either.
        vm.deal(stranger, 1 ether);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 6, 5)
        );
        seadrop.mintPublic{ value: PRICE }(
            address(adapter), feeRecipient, address(0), 1
        );
    }

    function testTransferAdapterMaxSupplyBelowQueue() public {
        ERC721SeaDropTransferAdapter adapter = _newTransferAdapter(5);
        adapter.setMaxSupply(2);
        (,, uint256 max) = adapter.getMintStats(minter);
        assertEq(max, 2);
    }

    function testTransferAdapterOwnerTransferQueues() public {
        ERC721SeaDropTransferAdapter adapter = _newTransferAdapter(0);
        existing.safeTransferFrom(address(this), address(adapter), 4);
        uint256[] memory queued = adapter.queuedTokenIds();
        assertEq(queued.length, 1);
        assertEq(queued[0], 4);
    }

    function testTransferAdapterRejectsOtherDeposits() public {
        ERC721SeaDropTransferAdapter adapter = _newTransferAdapter(0);

        existing.transferFrom(address(this), stranger, 1);
        vm.prank(stranger);
        vm.expectRevert(
            ERC721SeaDropTransferAdapter.OnlyOwnerCanDeposit.selector
        );
        existing.safeTransferFrom(stranger, address(adapter), 1);

        vm.prank(stranger);
        vm.expectRevert(ERC721SeaDropTransferAdapter.OnlyTarget.selector);
        adapter.onERC721Received(address(this), address(this), 1, "");
    }

    function testTransferAdapterWithdrawAndRescue() public {
        ERC721SeaDropTransferAdapter adapter = _newTransferAdapter(5);
        _mintPublic(address(adapter), 1);

        // Withdraw takes from the back of the queue.
        adapter.withdraw(creator, 2);
        assertEq(existing.ownerOf(15), creator);
        assertEq(existing.ownerOf(14), creator);
        assertEq(adapter.queuedTokenCount(), 2);
        (,, uint256 max) = adapter.getMintStats(minter);
        assertEq(max, 3);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropTransferAdapter.NotEnoughQueuedTokens.selector,
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
                ERC721SeaDropTransferAdapter.TokenIsQueued.selector, 12
            )
        );
        adapter.rescue(12, creator);

        vm.startPrank(stranger);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.withdraw(stranger, 1);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        adapter.rescue(12, stranger);
        vm.stopPrank();
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
