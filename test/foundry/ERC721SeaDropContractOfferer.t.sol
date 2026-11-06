// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721OffererFixture } from "./utils/SeaDrop721Test.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    ERC721SeaDropConfigurer
} from "seadrop/lib/ERC721SeaDropConfigurer.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { ISeaDropToken } from "seadrop/interfaces/ISeaDropToken.sol";

import {
    IERC721ContractMetadata
} from "seadrop/interfaces/IERC721ContractMetadata.sol";

import {
    ICreatorToken,
    ILegacyCreatorToken
} from "seadrop/interfaces/ICreatorToken.sol";

import { MultiConfigureStruct } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { AllowListData, CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

import {
    ContractOffererInterface
} from "seaport-types/src/interfaces/ContractOffererInterface.sol";

import { SpentItem } from "seaport-types/src/lib/ConsiderationStructs.sol";

import { IERC2981 } from "@openzeppelin/contracts/interfaces/IERC2981.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

import { Vm } from "forge-std/Vm.sol";

/**
 * @dev Deployment, configuration and admin cases of the 721 contract
 *      offerer. The Seaport mint order cases are in
 *      ERC721SeaDropContractOffererMint.t.sol.
 */
contract ERC721SeaDropContractOffererTest is SeaDrop721OffererFixture {
    /// @dev The token reverts with solady Ownable's `Unauthorized()`.
    bytes4 internal immutable _UNAUTHORIZED = Ownable.Unauthorized.selector;

    /// @dev Should emit an event when the contract is deployed.
    function testEmitsEventWhenDeployed() public {
        address expected = computeCreateAddress(owner, vm.getNonce(owner));
        vm.expectEmit(true, true, true, true, expected);
        emit SeaDropTokenDeployed(SEADROP_TOKEN_TYPE.ERC721_STANDARD);
        vm.prank(owner);
        ERC721SeaDrop deployed =
            new ERC721SeaDrop(address(0), allowedSeaport, "", "");
        assertEq(address(deployed), expected);

        vm.expectRevert(AllowedSeaportCannotBeZeroAddress.selector);
        vm.prank(owner);
        new ERC721SeaDrop(address(0), address(0), "", "");
    }

    /// @dev Should return the configurer contact.
    function testReturnsConfigurer() public view {
        assertEq(_seaDrop().configurer(), address(configurer));
    }

    /// @dev Should not be able to call into the implementation contract
    ///      without delegatecall.
    function testImplementationRequiresDelegateCall() public {
        vm.startPrank(owner);

        // Fallback
        (bool success, bytes memory returnData) =
            address(configurer).call(hex"123456");
        assertFalse(success);
        assertEq(
            returnData, abi.encodeWithSelector(OnlyDelegateCalled.selector)
        );

        // updateDropURI
        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateDropURI("");

        // updatePublicDrop
        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updatePublicDrop(publicDrop);

        // updateAllowList
        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateAllowList(
            AllowListData({
                merkleRoot: 0x1111111111111111111111111111111111111111111111111111111111111111,
                publicKeyURIs: new string[](0),
                allowListURI: ""
            })
        );

        // generateOrder
        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.generateOrder(
            address(0), new SpentItem[](0), new SpentItem[](0), ""
        );

        // previewOrder
        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.previewOrder(
            address(0), address(0), new SpentItem[](0), new SpentItem[](0), ""
        );

        // updateAllowedSeaport
        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateAllowedSeaport(new address[](0));

        // updateCreatorPayouts
        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateCreatorPayouts(new CreatorPayout[](0));

        // updateAllowedFeeRecipient
        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateAllowedFeeRecipient(address(0), true);

        // updateSigner
        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateSigner(address(0), true);

        // updatePayer
        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updatePayer(address(0), true);

        vm.stopPrank();
    }

    /// @dev Should only let the token owner update the drop URI.
    function testOnlyOwnerCanUpdateDropURI() public {
        vm.expectRevert(_UNAUTHORIZED);
        vm.prank(creator);
        _seaDrop().updateDropURI("http://test.com");

        vm.expectEmit(true, true, true, true, address(token));
        emit DropURIUpdated("http://test.com");
        vm.prank(owner);
        _seaDrop().updateDropURI("http://test.com");
    }

    /// @dev Should only let the owner update the allowed fee recipients.
    function testUpdateAllowedFeeRecipients() public {
        vm.startPrank(owner);

        _seaDrop().updateAllowedFeeRecipient(feeRecipient, false);
        assertEq(_seaDrop().getAllowedFeeRecipients(), new address[](0));

        vm.expectRevert(FeeRecipientCannotBeZeroAddress.selector);
        _seaDrop().updateAllowedFeeRecipient(address(0), true);

        vm.expectEmit(true, true, true, true, address(token));
        emit AllowedFeeRecipientUpdated(feeRecipient, true);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);

        vm.expectRevert(DuplicateFeeRecipient.selector);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);

        assertEq(_seaDrop().getAllowedFeeRecipients(), _addrs(feeRecipient));

        // Now let's disallow the feeRecipient
        vm.expectEmit(true, true, true, true, address(token));
        emit AllowedFeeRecipientUpdated(feeRecipient, false);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, false);

        assertEq(_seaDrop().getAllowedFeeRecipients(), new address[](0));

        vm.expectRevert(FeeRecipientNotPresent.selector);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, false);

        vm.stopPrank();
    }

    /// @dev Should return supportsInterface true for supported interfaces.
    ///      Each id below is the XOR of the interface's own selectors
    ///      (excluding its parent interface's).
    function testSupportsInterface() public view {
        // [IERC721SeaDrop, ISeaDropToken]
        assertTrue(
            token.supportsInterface(
                IERC721SeaDrop.updatePublicDrop.selector
                    ^ IERC721SeaDrop.getPublicDrop.selector
                    ^ IERC721SeaDrop.getMintStats.selector
                    ^ IERC721SeaDrop.multiConfigureMint.selector
            )
        );

        // [IERC721ContractMetadata, ISeaDropTokenContractMetadata]
        assertTrue(
            token.supportsInterface(
                IERC721ContractMetadata.setMaxSupply.selector
                    ^ IERC721ContractMetadata.maxSupply.selector
            )
        );

        // [IERC2981, IERC165]
        assertTrue(token.supportsInterface(IERC2981.royaltyInfo.selector));

        // [ICreatorToken]
        assertTrue(
            token.supportsInterface(
                ICreatorToken.getTransferValidator.selector
                    ^ ICreatorToken.getTransferValidationFunction.selector
                    ^ ICreatorToken.setTransferValidator.selector
            )
        );

        // [ILegacyCreatorToken]
        assertTrue(
            token.supportsInterface(
                ILegacyCreatorToken.getTransferValidator.selector
                    ^ ILegacyCreatorToken.setTransferValidator.selector
            )
        );

        // [ContractOffererInterface]
        assertTrue(
            token.supportsInterface(
                ContractOffererInterface.generateOrder.selector
                    ^ ContractOffererInterface.ratifyOrder.selector
                    ^ ContractOffererInterface.previewOrder.selector
                    ^ ContractOffererInterface.getSeaportMetadata.selector
                    ^ ContractOffererInterface.supportsInterface.selector
            )
        );

        // Ensure the supported interfaces from ERC721A return true.
        // 0x80ac58cd: ERC721
        assertTrue(token.supportsInterface(0x80ac58cd));
        // 0x5b5e139f: ERC721Metadata
        assertTrue(token.supportsInterface(0x5b5e139f));
        // 0x01ffc9a7: ERC165
        assertTrue(token.supportsInterface(0x01ffc9a7));

        // Ensure the interface for ERC-4906 returns true.
        assertTrue(token.supportsInterface(0x49064906));

        // Ensure the interface for SIP-5 (getSeaportMetadata) returns true.
        assertTrue(token.supportsInterface(0x2e778efc));

        // Ensure invalid interfaces return false.
        assertFalse(token.supportsInterface(0x00000000));
        assertFalse(token.supportsInterface(0x10000000));
        assertFalse(token.supportsInterface(0x00000001));
    }

    /// @dev Should only let the token owner update the allowed Seaport
    ///      addresses.
    function testOnlyOwnerCanUpdateAllowedSeaport() public {
        address seaport = address(consideration);

        vm.expectRevert(_UNAUTHORIZED);
        vm.prank(creator);
        _seaDrop().updateAllowedSeaport(_addrs(seaport));

        vm.expectRevert(_UNAUTHORIZED);
        vm.prank(minter);
        _seaDrop().updateAllowedSeaport(_addrs(seaport));

        vm.startPrank(owner);

        vm.expectRevert(AllowedSeaportCannotBeZeroAddress.selector);
        _seaDrop().updateAllowedSeaport(_addrs(address(0)));

        _updateAllowedSeaportAndCheck(_addrs(seaport));

        address address1 = 0x1111111111111111111111111111111111111111;
        address address2 = 0x2222222222222222222222222222222222222222;
        address address3 = 0x3333333333333333333333333333333333333333;

        _updateAllowedSeaportAndCheck(_addrs(seaport, address1));
        _updateAllowedSeaportAndCheck(_addrs(address2));
        _updateAllowedSeaportAndCheck(
            _addrs(address3, seaport, address2, address1)
        );
        _updateAllowedSeaportAndCheck(_addrs(seaport));

        vm.stopPrank();
    }

    function _updateAllowedSeaportAndCheck(address[] memory seaports) internal {
        vm.expectEmit(true, true, true, true, address(token));
        emit AllowedSeaportUpdated(seaports);
        _seaDrop().updateAllowedSeaport(seaports);

        assertEq(_seaDrop().getAllowedSeaport(), seaports);
    }

    /// @dev Should let the token owner use admin methods.
    function testOwnerCanUseAdminMethods() public {
        // Test `updateAllowList` for coverage.
        vm.prank(owner);
        _seaDrop().updateAllowList(_allowListData(_ALLOW_LIST_MERKLE_ROOT));

        vm.expectRevert(_UNAUTHORIZED);
        vm.prank(creator);
        _seaDrop().updateAllowList(_allowListData(_ALLOW_LIST_MERKLE_ROOT));

        // Test `updateSigner` for coverage.
        address signer = 0x5555555555555555555555555555555555555555;
        vm.prank(owner);
        _seaDrop().updateSigner(signer, true);

        vm.expectRevert(_UNAUTHORIZED);
        vm.prank(creator);
        _seaDrop().updateSigner(signer, false);

        // Test `updatePayer` for coverage.
        address payer = 0x6666666666666666666666666666666666666666;
        vm.prank(owner);
        _seaDrop().updatePayer(payer, true);

        // Only the owner can update payers and signers.
        vm.expectRevert(_UNAUTHORIZED);
        vm.prank(creator);
        _seaDrop().updatePayer(payer, false);
        vm.expectRevert(_UNAUTHORIZED);
        vm.prank(creator);
        _seaDrop().updateSigner(payer, true);
    }

    /// @dev Should be able to update the allowed payers.
    function testUpdateAllowedPayers() public {
        address payer = makeAddr("payer");
        address payer2 = makeAddr("payer2");

        vm.startPrank(owner);

        vm.expectRevert(PayerNotPresent.selector);
        _seaDrop().updatePayer(payer, false);

        _seaDrop().updatePayer(payer, true);

        // Ensure that the same payer cannot be added twice.
        vm.expectRevert(DuplicatePayer.selector);
        _seaDrop().updatePayer(payer, true);

        // Ensure that the zero address cannot be added as a payer.
        vm.expectRevert(PayerCannotBeZeroAddress.selector);
        _seaDrop().updatePayer(address(0), true);

        // Remove the original payer for branch coverage.
        _seaDrop().updatePayer(payer, false);
        assertEq(_seaDrop().getPayers(), new address[](0));

        // Add two signers and remove the second for branch coverage.
        _seaDrop().updatePayer(payer, true);
        _seaDrop().updatePayer(payer2, true);
        _seaDrop().updatePayer(payer2, false);
        assertEq(_seaDrop().getPayers(), _addrs(payer));

        vm.stopPrank();
    }

    /// @dev Should only let the owner call update functions.
    function testOnlyOwnerCanCallUpdateFunctions() public {
        address four = 0x4444444444444444444444444444444444444444;

        bytes[] memory calls = new bytes[](8);
        calls[0] = abi.encodeCall(
            ISeaDropToken.updateAllowedSeaport, (_addrs(address(token)))
        );
        calls[1] = abi.encodeCall(IERC721SeaDrop.updatePublicDrop, (publicDrop));
        calls[2] = abi.encodeCall(
            ISeaDropToken.updateAllowList,
            (_allowListData(_ALLOW_LIST_MERKLE_ROOT))
        );
        calls[3] =
            abi.encodeCall(ISeaDropToken.updateDropURI, ("http://test.com"));
        calls[4] = abi.encodeCall(
            ISeaDropToken.updateCreatorPayouts, (_payouts(four, 10_000))
        );
        calls[5] = abi.encodeCall(
            ISeaDropToken.updateAllowedFeeRecipient, (four, true)
        );
        calls[6] = abi.encodeCall(ISeaDropToken.updateSigner, (four, true));
        calls[7] = abi.encodeCall(ISeaDropToken.updatePayer, (four, true));

        for (uint256 i = 0; i < calls.length; i++) {
            vm.prank(owner);
            (bool success, bytes memory returnData) =
                address(token).call(calls[i]);
            assertTrue(success, string(returnData));

            vm.prank(creator);
            (success, returnData) = address(token).call(calls[i]);
            assertFalse(success);
            assertEq(returnData, abi.encodeWithSelector(_UNAUTHORIZED));
        }
    }

    /// @dev Should be able to use the multiConfigure method.
    function testMultiConfigure() public {
        vm.prank(owner);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, false);

        MultiConfigureStruct memory config = _zeroedConfig();
        config.maxSupply = 100;
        config.baseURI = "https://example1.com";
        config.contractURI = "https://example2.com";
        config.publicDrop = publicDrop;
        config.dropURI = "https://example3.com";
        config.allowListData = _allowListData(_ALLOW_LIST_MERKLE_ROOT);
        config.creatorPayouts = _payouts(creator, 10_000);
        config.provenanceHash =
        0x3333333333333333333333333333333333333333333333333333333333333333;
        config.allowedFeeRecipients = _addrs(feeRecipient);
        config.allowedPayers = _addrs(
            0x4444444444444444444444444444444444444444,
            0x5555555555555555555555555555555555555555
        );
        config.allowedSigners = _addrs(
            0x8888888888888888888888888888888888888888,
            0x9999999999999999999999999999999999999999
        );
        config.royaltyReceiver = 0x1212121212121212121212121212121212121212;
        config.royaltyBps = 1_000;

        vm.expectRevert(ERC721SeaDropConfigurer.Unauthorized.selector);
        vm.prank(creator);
        configurer.multiConfigure(address(token), config);

        vm.expectEmit(true, true, true, true, address(token));
        emit DropURIUpdated("https://example3.com");
        vm.prank(owner);
        configurer.multiConfigure(address(token), config);

        _checkMultiConfigureResults(config);

        // Should not do anything if all fields are zeroed out
        MultiConfigureStruct memory zeroedConfig = _zeroedConfig();
        vm.recordLogs();
        vm.prank(owner);
        configurer.multiConfigure(address(token), zeroedConfig);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32[] memory dropURITopics = new bytes32[](1);
        dropURITopics[0] = keccak256("DropURIUpdated(string)");
        assertEq(_countLogs(logs, address(token), dropURITopics), 0);
        _checkMultiConfigureResults(config);

        // Should unset properties
        MultiConfigureStruct memory unsetConfig = _zeroedConfig();
        unsetConfig.disallowedFeeRecipients = config.allowedFeeRecipients;
        vm.expectEmit(true, true, true, true, address(token));
        emit AllowedFeeRecipientUpdated(feeRecipient, false);
        vm.prank(owner);
        configurer.multiConfigure(address(token), unsetConfig);

        assertEq(_seaDrop().getPayers(), config.allowedPayers);
        for (uint256 i = 0; i < config.allowedPayers.length; i++) {
            unsetConfig = _zeroedConfig();
            unsetConfig.disallowedPayers = _addrs(config.allowedPayers[i]);
            vm.expectEmit(true, true, true, true, address(token));
            emit PayerUpdated(config.allowedPayers[i], false);
            vm.prank(owner);
            configurer.multiConfigure(address(token), unsetConfig);
        }
        assertEq(_seaDrop().getPayers(), new address[](0));

        assertEq(_seaDrop().getSigners(), config.allowedSigners);
        for (uint256 i = 0; i < config.allowedSigners.length; i++) {
            unsetConfig = _zeroedConfig();
            unsetConfig.disallowedSigners = _addrs(config.allowedSigners[i]);
            vm.expectEmit(true, true, true, true, address(token));
            emit SignerUpdated(config.allowedSigners[i], false);
            vm.prank(owner);
            configurer.multiConfigure(address(token), unsetConfig);
        }
        assertEq(_seaDrop().getSigners(), new address[](0));

        // Should be able to use the multiConfigure method to mint
        MultiConfigureStruct memory configWithMint = _zeroedConfig();
        configWithMint.mintRecipient = minter;
        configWithMint.mintQuantity = 1;
        vm.recordLogs();
        vm.prank(owner);
        configurer.multiConfigure(address(token), configWithMint);
        logs = vm.getRecordedLogs();
        // ERC721 Transfer(from = 0, to = minter, tokenId = 1), all indexed.
        bytes32[] memory transferTopics = new bytes32[](4);
        transferTopics[0] = keccak256("Transfer(address,address,uint256)");
        transferTopics[1] = bytes32(0);
        transferTopics[2] = bytes32(uint256(uint160(minter)));
        transferTopics[3] = bytes32(uint256(1));
        assertEq(_countLogs(logs, address(token), transferTopics), 1);

        // Ensure multiConfigureMint can only be used by the owner and
        // configurer.
        vm.expectRevert(_UNAUTHORIZED);
        vm.prank(minter);
        _seaDrop().multiConfigureMint(minter, 1);
    }

    /// @dev multiConfigureMint can't mint past the max supply, directly or
    ///      through the configurer.
    function testMultiConfigureMintRespectsMaxSupply() public {
        assertEq(token.maxSupply(), 5);

        vm.expectRevert(
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 6, 5)
        );
        vm.prank(owner);
        _seaDrop().multiConfigureMint(minter, 6);

        MultiConfigureStruct memory configWithMint = _zeroedConfig();
        configWithMint.mintRecipient = minter;
        configWithMint.mintQuantity = 6;
        vm.expectRevert(
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 6, 5)
        );
        vm.prank(owner);
        configurer.multiConfigure(address(token), configWithMint);

        // Up to the max supply is fine.
        vm.prank(owner);
        _seaDrop().multiConfigureMint(minter, 4);
        configWithMint.mintQuantity = 1;
        vm.prank(owner);
        configurer.multiConfigure(address(token), configWithMint);
        assertEq(token.totalSupply(), 5);

        // One more is not.
        vm.expectRevert(
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 6, 5)
        );
        vm.prank(owner);
        _seaDrop().multiConfigureMint(minter, 1);
    }

    function _zeroedConfig()
        internal
        pure
        returns (MultiConfigureStruct memory config)
    {
        config.publicDrop.restrictFeeRecipients = true;
        config.allowListData.publicKeyURIs = new string[](0);
        config.creatorPayouts = new CreatorPayout[](0);
        config.allowedFeeRecipients = new address[](0);
        config.disallowedFeeRecipients = new address[](0);
        config.allowedPayers = new address[](0);
        config.disallowedPayers = new address[](0);
        config.allowedSigners = new address[](0);
        config.disallowedSigners = new address[](0);
    }

    /// @dev Assert the token state after the multiConfigure in
    ///      testMultiConfigure.
    function _checkMultiConfigureResults(MultiConfigureStruct memory config)
        internal
        view
    {
        assertEq(token.maxSupply(), 100);
        assertEq(token.baseURI(), "https://example1.com");
        assertEq(token.contractURI(), "https://example2.com");
        assertEq(token.provenanceHash(), config.provenanceHash);

        assertEq(
            abi.encode(_seaDrop().getPublicDrop()),
            abi.encode(config.publicDrop)
        );
        assertEq(
            abi.encode(_seaDrop().getCreatorPayouts()),
            abi.encode(_payouts(creator, 10_000))
        );
        assertEq(
            _seaDrop().getAllowListMerkleRoot(), config.allowListData.merkleRoot
        );
        assertEq(_seaDrop().getAllowedFeeRecipients(), _addrs(feeRecipient));
        assertEq(_seaDrop().getPayers(), config.allowedPayers);
        assertEq(_seaDrop().getSigners(), config.allowedSigners);

        (address receiver, uint256 royaltyAmount) = token.royaltyInfo(0, 100);
        assertEq(receiver, config.royaltyReceiver);
        assertEq(royaltyAmount, (uint256(config.royaltyBps) * 100) / 10_000);
    }

    /// @dev Should allow multiple creator payout addresses, emitting
    ///      CreatorPayoutsUpdated with the payouts.
    function testMultipleCreatorPayouts() public {
        vm.startPrank(owner);

        // Valid cases
        CreatorPayout[] memory payouts = _payouts(creator, 10_000);
        _updateCreatorPayoutsAndCheck(payouts);

        payouts = new CreatorPayout[](2);
        payouts[0] = CreatorPayout(creator, 5_000);
        payouts[1] = CreatorPayout(owner, 5_000);
        _updateCreatorPayoutsAndCheck(payouts);

        payouts = new CreatorPayout[](3);
        payouts[0] = CreatorPayout(creator, 9_000);
        payouts[1] = CreatorPayout(owner, 500);
        payouts[2] = CreatorPayout(minter, 500);
        _updateCreatorPayoutsAndCheck(payouts);

        payouts = new CreatorPayout[](3);
        payouts[0] = CreatorPayout(creator, 100);
        payouts[1] = CreatorPayout(owner, 100);
        payouts[2] = CreatorPayout(minter, 9_800);
        _updateCreatorPayoutsAndCheck(payouts);

        payouts = new CreatorPayout[](6);
        payouts[0] = CreatorPayout(creator, 1_000);
        payouts[1] = CreatorPayout(owner, 1_000);
        payouts[2] = CreatorPayout(minter, 1_000);
        payouts[3] = CreatorPayout(creator, 1_000);
        payouts[4] = CreatorPayout(owner, 1_000);
        payouts[5] = CreatorPayout(minter, 5_000);
        _updateCreatorPayoutsAndCheck(payouts);

        // Invalid cases
        payouts = new CreatorPayout[](4);
        payouts[0] = CreatorPayout(creator, 100);
        payouts[1] = CreatorPayout(owner, 100);
        payouts[2] = CreatorPayout(minter, 9_700);
        payouts[3] = CreatorPayout(address(0), 100);
        vm.expectRevert(CreatorPayoutAddressCannotBeZeroAddress.selector);
        _seaDrop().updateCreatorPayouts(payouts);

        payouts = new CreatorPayout[](3);
        payouts[0] = CreatorPayout(creator, 100);
        payouts[1] = CreatorPayout(owner, 0);
        payouts[2] = CreatorPayout(minter, 9_900);
        vm.expectRevert(CreatorPayoutBasisPointsCannotBeZero.selector);
        _seaDrop().updateCreatorPayouts(payouts);

        payouts = new CreatorPayout[](3);
        payouts[0] = CreatorPayout(creator, 100);
        payouts[1] = CreatorPayout(owner, 10);
        payouts[2] = CreatorPayout(minter, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidCreatorPayoutTotalBasisPoints.selector, 111
            )
        );
        _seaDrop().updateCreatorPayouts(payouts);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidCreatorPayoutTotalBasisPoints.selector, 10_001
            )
        );
        _seaDrop().updateCreatorPayouts(_payouts(creator, 10_001));

        payouts = new CreatorPayout[](2);
        payouts[0] = CreatorPayout(creator, 9_998);
        payouts[1] = CreatorPayout(owner, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidCreatorPayoutTotalBasisPoints.selector, 9_999
            )
        );
        _seaDrop().updateCreatorPayouts(payouts);

        vm.stopPrank();
    }

    function _updateCreatorPayoutsAndCheck(CreatorPayout[] memory payouts)
        internal
    {
        vm.expectEmit(true, true, true, true, address(token));
        emit CreatorPayoutsUpdated(payouts);
        _seaDrop().updateCreatorPayouts(payouts);

        assertEq(
            abi.encode(_seaDrop().getCreatorPayouts()), abi.encode(payouts)
        );
    }
}
