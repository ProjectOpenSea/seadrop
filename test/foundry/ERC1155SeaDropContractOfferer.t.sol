// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155OffererFixture } from "./utils/SeaDrop1155Test.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import {
    ERC1155SeaDropConfigurer
} from "seadrop/lib/ERC1155SeaDropConfigurer.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import {
    IERC1155ContractMetadata
} from "seadrop/interfaces/IERC1155ContractMetadata.sol";

import {
    ICreatorToken,
    ILegacyCreatorToken
} from "seadrop/interfaces/ICreatorToken.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "seadrop/lib/ERC1155SeaDropErrorsAndEvents.sol";

import {
    MultiConfigureStruct,
    PublicDrop
} from "seadrop/lib/ERC1155SeaDropStructs.sol";

import { AllowListData, CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

import { IERC2981 } from "@openzeppelin/contracts/interfaces/IERC2981.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

import {
    ContractOffererInterface
} from "seaport-types/src/interfaces/ContractOffererInterface.sol";

import {
    Schema,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { Vm } from "forge-std/Vm.sol";

/**
 * @dev Admin, configuration and introspection cases of the 1155 contract
 *      offerer. The Seaport mint order cases are in
 *      ERC1155SeaDropContractOffererMint.t.sol.
 */
contract ERC1155SeaDropContractOffererTest is SeaDrop1155OffererFixture {
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    address internal constant _ADDRESS_1 =
        0x1111111111111111111111111111111111111111;
    address internal constant _ADDRESS_2 =
        0x2222222222222222222222222222222222222222;
    address internal constant _ADDRESS_3 =
        0x3333333333333333333333333333333333333333;
    address internal constant _ADDRESS_4 =
        0x4444444444444444444444444444444444444444;
    address internal constant _ADDRESS_5 =
        0x5555555555555555555555555555555555555555;
    address internal constant _ADDRESS_6 =
        0x6666666666666666666666666666666666666666;
    address internal constant _ADDRESS_8 =
        0x8888888888888888888888888888888888888888;
    address internal constant _ADDRESS_9 =
        0x9999999999999999999999999999999999999999;
    address internal constant _ROYALTY_RECEIVER =
        0x1212121212121212121212121212121212121212;
    bytes32 internal constant _PROVENANCE_HASH =
        0x3333333333333333333333333333333333333333333333333333333333333333;

    /// @dev Should emit an event when the contract is deployed.
    function testEmitsEventOnDeployAndRejectsZeroAllowedSeaport() public {
        address expected =
            computeCreateAddress(address(this), vm.getNonce(address(this)));
        vm.expectEmit(true, true, true, true, expected);
        emit SeaDropTokenDeployed(SEADROP_TOKEN_TYPE.ERC1155_STANDARD);
        ERC1155SeaDrop deployed =
            new ERC1155SeaDrop(address(0), address(consideration), "", "");
        assertEq(address(deployed), expected);

        vm.expectRevert(AllowedSeaportCannotBeZeroAddress.selector);
        new ERC1155SeaDrop(address(0), address(0), "", "");
    }

    /// @dev Should return the configurer contact.
    function testReturnsConfigurer() public view {
        assertEq(_seaDrop().configurer(), address(configurer));
    }

    /// @dev Should not be able to call into the implementation contract
    ///      without delegatecall.
    function testImplementationRequiresDelegatecall() public {
        // Fallback
        (bool success, bytes memory returnData) =
            address(configurer).call(hex"123456");
        assertFalse(success, "fallback should revert");
        assertEq(
            returnData,
            abi.encodeWithSelector(OnlyDelegateCalled.selector),
            "fallback revert reason"
        );

        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateDropURI("");

        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updatePublicDrop(publicDrop, 0);

        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateAllowList(
            AllowListData({
                merkleRoot: bytes32(
                    0x1111111111111111111111111111111111111111111111111111111111111111
                ),
                publicKeyURIs: new string[](0),
                allowListURI: ""
            })
        );

        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.generateOrder(
            address(0), new SpentItem[](0), new SpentItem[](0), ""
        );

        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.previewOrder(
            address(0), address(0), new SpentItem[](0), new SpentItem[](0), ""
        );

        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateAllowedSeaport(new address[](0));

        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateCreatorPayouts(new CreatorPayout[](0));

        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateAllowedFeeRecipient(address(0), true);

        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updateSigner(address(0), true);

        vm.expectRevert(OnlyDelegateCalled.selector);
        configurer.updatePayer(address(0), true);
    }

    /// @dev Should only let the token owner update the drop URI.
    function testOnlyOwnerCanUpdateDropURI() public {
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateDropURI("http://test.com");

        vm.expectEmit(true, true, true, true, address(token));
        emit DropURIUpdated("http://test.com");
        _seaDrop().updateDropURI("http://test.com");
    }

    /// @dev Should only let the owner update the allowed fee recipients.
    function testUpdateAllowedFeeRecipients() public {
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, false);
        assertEq(_seaDrop().getAllowedFeeRecipients().length, 0);

        vm.expectRevert(FeeRecipientCannotBeZeroAddress.selector);
        _seaDrop().updateAllowedFeeRecipient(address(0), true);

        vm.expectEmit(true, true, true, true, address(token));
        emit AllowedFeeRecipientUpdated(feeRecipient, true);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);

        vm.expectRevert(DuplicateFeeRecipient.selector);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);

        _assertEq(
            _seaDrop().getAllowedFeeRecipients(),
            _addrs(feeRecipient),
            "allowed fee recipients"
        );

        // Now let's disallow the feeRecipient
        vm.expectEmit(true, true, true, true, address(token));
        emit AllowedFeeRecipientUpdated(feeRecipient, false);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, false);

        assertEq(_seaDrop().getAllowedFeeRecipients().length, 0);

        vm.expectRevert(FeeRecipientNotPresent.selector);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, false);
    }

    /// @dev Should return supportsInterface true for supported interfaces.
    function testSupportsInterface() public view {
        // Each id is the XOR of the interface's own selectors
        // (`type(I).interfaceId`).
        // [IERC1155SeaDrop, ISeaDropToken]
        assertTrue(token.supportsInterface(type(IERC1155SeaDrop).interfaceId));
        // [IERC1155ContractMetadata, ISeaDropTokenContractMetadata]
        assertTrue(
            token.supportsInterface(type(IERC1155ContractMetadata).interfaceId)
        );
        // [IERC2981, IERC165]
        assertTrue(token.supportsInterface(type(IERC2981).interfaceId));
        // [ICreatorToken]
        assertTrue(token.supportsInterface(type(ICreatorToken).interfaceId));
        // [ILegacyCreatorToken]
        assertTrue(
            token.supportsInterface(type(ILegacyCreatorToken).interfaceId)
        );
        // [ContractOffererInterface]: its ABI includes supportsInterface.
        bytes4 contractOffererInterfaceId =
            ContractOffererInterface.generateOrder.selector
                ^ ContractOffererInterface.ratifyOrder.selector
                ^ ContractOffererInterface.previewOrder.selector
                ^ ContractOffererInterface.getSeaportMetadata.selector
                ^ ContractOffererInterface.supportsInterface.selector;
        assertTrue(token.supportsInterface(contractOffererInterfaceId));

        // Ensure the supported interfaces from ERC1155 return true.
        // 0xd9b67a26: ERC1155
        assertTrue(token.supportsInterface(0xd9b67a26));
        // 0x0e89341c: ERC1155MetadataURI
        assertTrue(token.supportsInterface(0x0e89341c));
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

        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateAllowedSeaport(_addrs(seaport));

        vm.prank(minter);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateAllowedSeaport(_addrs(seaport));

        vm.expectRevert(AllowedSeaportCannotBeZeroAddress.selector);
        _seaDrop().updateAllowedSeaport(_addrs(address(0)));

        _updateAllowedSeaportAndCheck(_addrs(seaport));
        _updateAllowedSeaportAndCheck(_addrs(seaport, _ADDRESS_1));
        _updateAllowedSeaportAndCheck(_addrs(_ADDRESS_2));
        _updateAllowedSeaportAndCheck(
            _addrs(_ADDRESS_3, seaport, _ADDRESS_2, _ADDRESS_1)
        );
        _updateAllowedSeaportAndCheck(_addrs(seaport));
    }

    function _updateAllowedSeaportAndCheck(address[] memory seaports) internal {
        vm.expectEmit(true, true, true, true, address(token));
        emit AllowedSeaportUpdated(seaports);
        _seaDrop().updateAllowedSeaport(seaports);
        _assertEq(_seaDrop().getAllowedSeaport(), seaports, "allowed seaport");
    }

    /// @dev Should let the token owner use admin methods.
    function testOwnerCanUseAdminMethods() public {
        // Test `updateAllowList` for coverage.
        _seaDrop().updateAllowList(_allowListData(_ALLOW_LIST_MERKLE_ROOT));

        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateAllowList(_allowListData(_ALLOW_LIST_MERKLE_ROOT));

        // Test `updateSigner` for coverage.
        _seaDrop().updateSigner(_ADDRESS_5, true);

        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateSigner(_ADDRESS_5, false);

        // Test `updatePayer` for coverage.
        _seaDrop().updatePayer(_ADDRESS_6, true);

        // Only the owner can update payers and signers.
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updatePayer(_ADDRESS_6, false);
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateSigner(_ADDRESS_6, true);
    }

    /// @dev Should be able to update the allowed payers.
    function testUpdateAllowedPayers() public {
        address payer = makeAddr("payer");
        address payer2 = makeAddr("payer2");

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
        assertEq(_seaDrop().getPayers().length, 0);

        // Add two signers and remove the second for branch coverage.
        _seaDrop().updatePayer(payer, true);
        _seaDrop().updatePayer(payer2, true);
        _seaDrop().updatePayer(payer2, false);
        _assertEq(_seaDrop().getPayers(), _addrs(payer), "payers");
    }

    /// @dev Should only let the owner call update functions.
    function testOnlyOwnerCanCallUpdateFunctions() public {
        // updateAllowedSeaport
        _seaDrop().updateAllowedSeaport(_addrs(address(token)));
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateAllowedSeaport(_addrs(address(token)));

        // updatePublicDrop
        _seaDrop().updatePublicDrop(publicDrop, 0);
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updatePublicDrop(publicDrop, 0);

        // updateAllowList
        _seaDrop().updateAllowList(_allowListData(_ALLOW_LIST_MERKLE_ROOT));
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateAllowList(_allowListData(_ALLOW_LIST_MERKLE_ROOT));

        // updateDropURI
        _seaDrop().updateDropURI("http://test.com");
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateDropURI("http://test.com");

        // updateCreatorPayouts
        _seaDrop().updateCreatorPayouts(_payouts(_ADDRESS_4, 10_000));
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateCreatorPayouts(_payouts(_ADDRESS_4, 10_000));

        // updateAllowedFeeRecipient
        _seaDrop().updateAllowedFeeRecipient(_ADDRESS_4, true);
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateAllowedFeeRecipient(_ADDRESS_4, true);

        // updateSigner
        _seaDrop().updateSigner(_ADDRESS_4, true);
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updateSigner(_ADDRESS_4, true);

        // updatePayer
        _seaDrop().updatePayer(_ADDRESS_4, true);
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().updatePayer(_ADDRESS_4, true);
    }

    /// @dev Should be able to use the multiConfigure method.
    function testMultiConfigure() public {
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, false);

        MultiConfigureStruct memory config = _multiConfig();

        vm.prank(creator);
        vm.expectRevert(ERC1155SeaDropConfigurer.Unauthorized.selector);
        configurer.multiConfigure(address(token), config);

        // Should revert if maxSupplyTokenIds.length != maxSupplyAmounts.length
        MultiConfigureStruct memory badConfig = _multiConfig();
        badConfig.maxSupplyAmounts = _uints(101);
        vm.expectRevert(
            ERC1155SeaDropErrorsAndEvents.MaxSupplyMismatch.selector
        );
        configurer.multiConfigure(address(token), badConfig);

        // Should revert if publicDrops.length != publicDropsIndexes.length
        badConfig = _multiConfig();
        badConfig.publicDropsIndexes = new uint256[](0);
        vm.expectRevert(
            ERC1155SeaDropErrorsAndEvents.PublicDropsMismatch.selector
        );
        configurer.multiConfigure(address(token), badConfig);

        vm.expectEmit(true, true, true, true, address(token));
        emit DropURIUpdated("https://example3.com");
        configurer.multiConfigure(address(token), config);

        _checkMultiConfigureResults();

        // Should not do anything if all fields are zeroed out
        vm.recordLogs();
        configurer.multiConfigure(address(token), _zeroedMultiConfig());
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            assertTrue(
                logs[i].topics.length == 0
                    || logs[i].topics[0] != DropURIUpdated.selector,
                "zeroed config should not emit DropURIUpdated"
            );
        }
        _checkMultiConfigureResults();

        // Should unset properties
        _multiConfigureUnsetsProperties();

        // Should be able to use the multiConfigure method to mint
        _multiConfigureMints();
    }

    function _multiConfigureUnsetsProperties() internal {
        MultiConfigureStruct memory unsetConfig = _zeroedMultiConfig();
        unsetConfig.disallowedFeeRecipients = _addrs(feeRecipient);
        vm.expectEmit(true, true, true, true, address(token));
        emit AllowedFeeRecipientUpdated(feeRecipient, false);
        configurer.multiConfigure(address(token), unsetConfig);

        address[] memory allowedPayers = _addrs(_ADDRESS_4, _ADDRESS_5);
        _assertEq(_seaDrop().getPayers(), allowedPayers, "payers before unset");
        for (uint256 i = 0; i < allowedPayers.length; i++) {
            unsetConfig = _zeroedMultiConfig();
            unsetConfig.disallowedPayers = _addrs(allowedPayers[i]);
            vm.expectEmit(true, true, true, true, address(token));
            emit PayerUpdated(allowedPayers[i], false);
            configurer.multiConfigure(address(token), unsetConfig);
        }
        assertEq(_seaDrop().getPayers().length, 0);

        address[] memory allowedSigners = _addrs(_ADDRESS_8, _ADDRESS_9);
        _assertEq(
            _seaDrop().getSigners(), allowedSigners, "signers before unset"
        );
        for (uint256 i = 0; i < allowedSigners.length; i++) {
            unsetConfig = _zeroedMultiConfig();
            unsetConfig.disallowedSigners = _addrs(allowedSigners[i]);
            vm.expectEmit(true, true, true, true, address(token));
            emit SignerUpdated(allowedSigners[i], false);
            configurer.multiConfigure(address(token), unsetConfig);
        }
        assertEq(_seaDrop().getSigners().length, 0);
    }

    function _multiConfigureMints() internal {
        MultiConfigureStruct memory configWithMint = _zeroedMultiConfig();
        configWithMint.mintRecipient = minter;
        configWithMint.mintTokenIds = _uints(0);
        configWithMint.mintAmounts = _uints(1);
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(
            address(configurer),
            address(0),
            minter,
            _uints(0),
            _uints(1)
        );
        configurer.multiConfigure(address(token), configWithMint);

        // Should revert if mintTokenIds.length != mintAmounts.length
        configWithMint.mintAmounts = new uint256[](0);
        vm.expectRevert(
            ERC1155SeaDropErrorsAndEvents.MintAmountsMismatch.selector
        );
        configurer.multiConfigure(address(token), configWithMint);

        // Ensure multiConfigureMint can only be used by the owner and
        // configurer.
        vm.prank(minter);
        vm.expectRevert(Ownable.Unauthorized.selector);
        _seaDrop().multiConfigureMint(minter, _uints(0), _uints(1));
    }

    function _multiConfig()
        internal
        view
        returns (MultiConfigureStruct memory config)
    {
        PublicDrop[] memory publicDrops = new PublicDrop[](1);
        publicDrops[0] = publicDrop;

        config.maxSupplyTokenIds = _uints(0, 1);
        config.maxSupplyAmounts = _uints(100, 101);
        config.baseURI = "https://example1.com";
        config.contractURI = "https://example2.com";
        config.publicDrops = publicDrops;
        config.publicDropsIndexes = _uints(0);
        config.dropURI = "https://example3.com";
        config.allowListData = _allowListData(_ALLOW_LIST_MERKLE_ROOT);
        config.creatorPayouts = _payouts(creator, 10_000);
        config.provenanceHash = _PROVENANCE_HASH;
        config.allowedFeeRecipients = _addrs(feeRecipient);
        config.disallowedFeeRecipients = new address[](0);
        config.allowedPayers = _addrs(_ADDRESS_4, _ADDRESS_5);
        config.disallowedPayers = new address[](0);
        config.allowedSigners = _addrs(_ADDRESS_8, _ADDRESS_9);
        config.disallowedSigners = new address[](0);
        config.royaltyReceiver = _ROYALTY_RECEIVER;
        config.royaltyBps = 1_000;
        config.mintRecipient = address(0);
        config.mintTokenIds = new uint256[](0);
        config.mintAmounts = new uint256[](0);
    }

    function _zeroedMultiConfig()
        internal
        pure
        returns (MultiConfigureStruct memory config)
    {
        // Memory structs are zero-initialized; spell out the fields that
        // multiConfigure skips when zero.
        config.allowListData = AllowListData({
            merkleRoot: bytes32(0),
            publicKeyURIs: new string[](0),
            allowListURI: ""
        });
        config.provenanceHash = bytes32(0);
        config.royaltyReceiver = address(0);
        config.royaltyBps = 0;
        config.mintRecipient = address(0);
    }

    function _checkMultiConfigureResults() internal {
        assertEq(token.maxSupply(0), 100);
        assertEq(token.maxSupply(1), 101);
        assertEq(token.baseURI(), "https://example1.com");
        assertEq(token.contractURI(), "https://example2.com");
        assertEq(token.provenanceHash(), _PROVENANCE_HASH);

        PublicDrop memory got = _seaDrop().getPublicDrop(0);
        assertEq(got.startPrice, publicDrop.startPrice, "startPrice");
        assertEq(got.endPrice, publicDrop.endPrice, "endPrice");
        assertEq(got.startTime, publicDrop.startTime, "startTime");
        assertEq(got.endTime, publicDrop.endTime, "endTime");
        assertEq(
            got.restrictFeeRecipients,
            publicDrop.restrictFeeRecipients,
            "restrictFeeRecipients"
        );
        assertEq(got.paymentToken, publicDrop.paymentToken, "paymentToken");
        assertEq(got.fromTokenId, publicDrop.fromTokenId, "fromTokenId");
        assertEq(got.toTokenId, publicDrop.toTokenId, "toTokenId");
        assertEq(
            got.maxTotalMintableByWallet,
            publicDrop.maxTotalMintableByWallet,
            "maxTotalMintableByWallet"
        );
        assertEq(
            got.maxTotalMintableByWalletPerToken,
            publicDrop.maxTotalMintableByWalletPerToken,
            "maxTotalMintableByWalletPerToken"
        );
        assertEq(got.feeBps, publicDrop.feeBps, "feeBps");

        _assertEq(_seaDrop().getCreatorPayouts(), _payouts(creator, 10_000));
        assertEq(_seaDrop().getAllowListMerkleRoot(), _ALLOW_LIST_MERKLE_ROOT);
        _assertEq(
            _seaDrop().getAllowedFeeRecipients(),
            _addrs(feeRecipient),
            "allowed fee recipients"
        );
        _assertEq(
            _seaDrop().getPayers(), _addrs(_ADDRESS_4, _ADDRESS_5), "payers"
        );
        _assertEq(
            _seaDrop().getSigners(), _addrs(_ADDRESS_8, _ADDRESS_9), "signers"
        );

        (address receiver, uint256 royaltyAmount) = token.royaltyInfo(0, 100);
        assertEq(receiver, _ROYALTY_RECEIVER);
        assertEq(royaltyAmount, (1_000 * 100) / 10_000);
    }

    /// @dev Should allow multiple creator payout addresses.
    function testMultipleCreatorPayoutAddresses() public {
        // Valid cases, checking the CreatorPayoutsUpdated event args.
        _updateCreatorPayoutsAndCheck(_payouts(creator, 10_000));
        _updateCreatorPayoutsAndCheck(_payouts(creator, 5_000, owner, 5_000));
        _updateCreatorPayoutsAndCheck(
            _payouts(creator, 9_000, owner, 500, minter, 500)
        );
        _updateCreatorPayoutsAndCheck(
            _payouts(creator, 100, owner, 100, minter, 9_800)
        );

        CreatorPayout[] memory six = new CreatorPayout[](6);
        six[0] = CreatorPayout(creator, 1_000);
        six[1] = CreatorPayout(owner, 1_000);
        six[2] = CreatorPayout(minter, 1_000);
        six[3] = CreatorPayout(creator, 1_000);
        six[4] = CreatorPayout(owner, 1_000);
        six[5] = CreatorPayout(minter, 5_000);
        _updateCreatorPayoutsAndCheck(six);

        // Invalid cases
        CreatorPayout[] memory withZeroAddress = new CreatorPayout[](4);
        withZeroAddress[0] = CreatorPayout(creator, 100);
        withZeroAddress[1] = CreatorPayout(owner, 100);
        withZeroAddress[2] = CreatorPayout(minter, 9_700);
        withZeroAddress[3] = CreatorPayout(address(0), 100);
        vm.expectRevert(CreatorPayoutAddressCannotBeZeroAddress.selector);
        _seaDrop().updateCreatorPayouts(withZeroAddress);

        vm.expectRevert(CreatorPayoutBasisPointsCannotBeZero.selector);
        _seaDrop()
            .updateCreatorPayouts(
                _payouts(creator, 100, owner, 0, minter, 9_900)
            );

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidCreatorPayoutTotalBasisPoints.selector, 111
            )
        );
        _seaDrop()
            .updateCreatorPayouts(_payouts(creator, 100, owner, 10, minter, 1));

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidCreatorPayoutTotalBasisPoints.selector, 10_001
            )
        );
        _seaDrop().updateCreatorPayouts(_payouts(creator, 10_001));

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidCreatorPayoutTotalBasisPoints.selector, 9_999
            )
        );
        _seaDrop().updateCreatorPayouts(_payouts(creator, 9_998, owner, 1));
    }

    function _updateCreatorPayoutsAndCheck(CreatorPayout[] memory payouts)
        internal
    {
        vm.expectEmit(true, true, true, true, address(token));
        emit CreatorPayoutsUpdated(payouts);
        _seaDrop().updateCreatorPayouts(payouts);
        _assertEq(_seaDrop().getCreatorPayouts(), payouts);
    }

    /// @dev Should return the expected values for getSeaportMetadata.
    function testGetSeaportMetadata() public {
        bytes4 getSeaportMetadataSelector = 0x2e778efc;
        assertEq(
            getSeaportMetadataSelector,
            ContractOffererInterface.getSeaportMetadata.selector
        );

        vm.prank(minter);
        (bool success, bytes memory returnData) = address(token)
            .staticcall(abi.encodePacked(getSeaportMetadataSelector));
        assertTrue(success);

        (string memory name, Schema[] memory schemas) =
            abi.decode(returnData, (string, Schema[]));

        uint256[] memory supportedSubstandards = _uints(0, 1, 2);
        bytes memory metadata = abi.encode(supportedSubstandards);

        assertEq(name, "ERC1155SeaDrop");
        assertEq(schemas.length, 1);
        assertEq(schemas[0].id, 12);
        assertEq(schemas[0].metadata, metadata);
    }

    /// @dev Should revert on unsupported function selector.
    function testRevertsOnUnsupportedFunctionSelector() public {
        (bool success, bytes memory returnData) =
            address(token).call(hex"12345678");
        assertFalse(success, "should revert");
        assertEq(
            returnData,
            abi.encodeWithSelector(
                UnsupportedFunctionSelector.selector, bytes4(0x12345678)
            )
        );
    }
}
