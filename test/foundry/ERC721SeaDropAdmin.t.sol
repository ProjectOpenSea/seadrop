// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Vm } from "forge-std/Vm.sol";

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    INonFungibleSeaDropToken
} from "seadrop/interfaces/INonFungibleSeaDropToken.sol";

import {
    ISeaDropTokenContractMetadata
} from "seadrop/interfaces/ISeaDropTokenContractMetadata.sol";

import {
    ICreatorToken,
    ILegacyCreatorToken
} from "seadrop/interfaces/ICreatorToken.sol";

import {
    ERC721SeaDropStructsErrorsAndEvents
} from "seadrop/lib/ERC721SeaDropStructsErrorsAndEvents.sol";

import {
    AllowListData,
    PublicDrop,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "seadrop/lib/SeaDropStructs.sol";

import { IERC721A } from "ERC721A/IERC721A.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

import { IERC2981 } from "openzeppelin-contracts/interfaces/IERC2981.sol";

import { IERC721 } from "openzeppelin-contracts/token/ERC721/IERC721.sol";

import {
    IERC165
} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

contract ERC721SeaDropAdminTest is TestHelper {
    address minter = makeAddr("minter");

    PublicDrop publicDrop;

    event SeaDropTokenDeployed();
    event AllowedSeaDropUpdated(address[] allowedSeaDrop);
    event ProvenanceHashUpdated(bytes32 previousHash, bytes32 newHash);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function setUp() public {
        // Use a realistic timestamp so stage start times in the past are
        // representable.
        vm.warp(1_700_000_000);

        // Deploy the ERC721SeaDrop token. The test contract is the owner.
        token = _newToken("", "", _allowedSeaDrop());

        publicDrop = PublicDrop(
            0.1 ether, // mint price
            uint48(block.timestamp - 100), // start time
            uint48(block.timestamp + 100), // end time
            10, // max mints per wallet
            1000, // fee (10%)
            true // restrict fee recipients
        );
    }

    function _allowedSeaDrop() internal view returns (address[] memory) {
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        return allowedSeaDrop;
    }

    function _tokenGatedDropStage()
        internal
        view
        returns (TokenGatedDropStage memory)
    {
        return TokenGatedDropStage(
            0.01 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp - 100), // start time
            uint48(block.timestamp + 500), // end time
            1, // drop stage index
            100, // max token supply for stage
            100, // fee (1%)
            true // restrict fee recipients
        );
    }

    function _signedMintValidationParams()
        internal
        pure
        returns (SignedMintValidationParams memory)
    {
        return SignedMintValidationParams(
            10, // min mint price
            5, // max max total mintable by wallet
            50, // min start time
            100, // max end time
            100, // max max token supply for stage
            5, // min fee bps
            1000 // max fee bps
        );
    }

    function _allowListData() internal pure returns (AllowListData memory) {
        string[] memory publicKeyURIs = new string[](0);
        return
            AllowListData(bytes32(uint256(0x33) * _REPEAT), publicKeyURIs, "");
    }

    /// @dev Multiplier that repeats a byte across 32 bytes, e.g.
    ///      0x33 * _REPEAT == 0x3333...33.
    uint256 internal constant _REPEAT = type(uint256).max / 0xff;

    /// @dev Address with a repeated hex digit, e.g. _addr(0x44) == 0x4444...44.
    function _addr(uint160 digitPair) internal pure returns (address) {
        return address(digitPair * (type(uint160).max / 0xff));
    }

    function testDeploy_emitsSeaDropTokenDeployed() public {
        // The upgradeable token emits from its proxy, which _newToken
        // creates after the implementation and the ProxyAdmin.
        uint256 nonce = vm.getNonce(address(this)) + (_upgradeable() ? 2 : 0);
        address expected = computeCreateAddress(address(this), nonce);
        vm.expectEmit(true, true, true, true, expected);
        emit SeaDropTokenDeployed();
        ERC721SeaDrop deployed = _newToken("", "", _allowedSeaDrop());
        assertEq(address(deployed), expected);
    }

    function testMintPublic_revertsUntilCreatorPayoutAddressIsSet() public {
        token.updatePublicDrop(address(seadrop), publicDrop);
        token.setMaxSupply(5);

        address feeRecipient = makeAddr("feeRecipient");
        token.updateAllowedFeeRecipient(address(seadrop), feeRecipient, true);

        vm.expectRevert(CreatorPayoutAddressCannotBeZeroAddress.selector);
        seadrop.mintPublic{ value: publicDrop.mintPrice }(
            address(token), feeRecipient, address(0), 1
        );

        token.updateAllowedFeeRecipient(address(seadrop), feeRecipient, false);
    }

    function testUpdateDropURI_onlyOwner() public {
        vm.prank(creator);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.updateDropURI(address(seadrop), "http://test.com");

        vm.expectEmit(true, true, true, true, address(seadrop));
        emit DropURIUpdated(address(token), "http://test.com");
        token.updateDropURI(address(seadrop), "http://test.com");
    }

    function testUpdateAllowedFeeRecipient_viaToken() public {
        address feeRecipient = makeAddr("feeRecipient");

        assertEq(seadrop.getAllowedFeeRecipients(address(token)).length, 0);
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), feeRecipient)
        );

        vm.expectRevert(FeeRecipientCannotBeZeroAddress.selector);
        token.updateAllowedFeeRecipient(address(seadrop), address(0), true);

        vm.expectEmit(true, true, true, true, address(seadrop));
        emit AllowedFeeRecipientUpdated(address(token), feeRecipient, true);
        token.updateAllowedFeeRecipient(address(seadrop), feeRecipient, true);

        vm.expectRevert(DuplicateFeeRecipient.selector);
        token.updateAllowedFeeRecipient(address(seadrop), feeRecipient, true);

        address[] memory allowed =
            seadrop.getAllowedFeeRecipients(address(token));
        assertEq(allowed.length, 1);
        assertEq(allowed[0], feeRecipient);
        assertTrue(
            seadrop.getFeeRecipientIsAllowed(address(token), feeRecipient)
        );

        // Now disallow the fee recipient.
        vm.expectEmit(true, true, true, true, address(seadrop));
        emit AllowedFeeRecipientUpdated(address(token), feeRecipient, false);
        token.updateAllowedFeeRecipient(address(seadrop), feeRecipient, false);

        assertEq(seadrop.getAllowedFeeRecipients(address(token)).length, 0);
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), feeRecipient)
        );

        vm.expectRevert(FeeRecipientNotPresent.selector);
        token.updateAllowedFeeRecipient(address(seadrop), feeRecipient, false);
    }

    function testSetProvenanceHash_onlyOwnerAndBeforeMint() public {
        token.setMaxSupply(1);
        assertEq(token.provenanceHash(), bytes32(0));

        bytes32 defaultProvenanceHash = bytes32(0);
        bytes32 firstProvenanceHash = bytes32(0x11 * _REPEAT);
        bytes32 secondProvenanceHash = bytes32(0x22 * _REPEAT);

        vm.prank(creator);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.setProvenanceHash(firstProvenanceHash);

        vm.expectEmit(true, true, true, true, address(token));
        emit ProvenanceHashUpdated(defaultProvenanceHash, firstProvenanceHash);
        token.setProvenanceHash(firstProvenanceHash);

        // The provenance hash should not be updatable after the first token
        // has minted.
        vm.prank(address(seadrop));
        token.mintSeaDrop(minter, 1);

        vm.expectRevert(
            ISeaDropTokenContractMetadata.ProvenanceHashCannotBeSetAfterMintStarted
                .selector
        );
        token.setProvenanceHash(secondProvenanceHash);

        assertEq(token.provenanceHash(), firstProvenanceHash);
    }

    function testMintSeaDrop_onlyAllowedSeaDrop() public {
        token.setMaxSupply(1);

        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), minter, 1);
        vm.prank(address(seadrop));
        token.mintSeaDrop(minter, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropStructsErrorsAndEvents.MintQuantityExceedsMaxSupply
                    .selector,
                2,
                1
            )
        );
        vm.prank(address(seadrop));
        token.mintSeaDrop(minter, 1);

        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        token.mintSeaDrop(minter, 1);
    }

    function testSupportsInterface() public view {
        // Interfaces declared by ERC721SeaDrop.
        assertTrue(
            token.supportsInterface(type(INonFungibleSeaDropToken).interfaceId)
        );
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));

        // Interfaces declared by ERC721ContractMetadata.
        assertTrue(
            token.supportsInterface(
                type(ISeaDropTokenContractMetadata).interfaceId
            )
        );
        assertTrue(token.supportsInterface(type(IERC2981).interfaceId));
        assertTrue(token.supportsInterface(type(ICreatorToken).interfaceId));
        assertTrue(
            token.supportsInterface(type(ILegacyCreatorToken).interfaceId)
        );

        // Interfaces declared by ERC721A.
        assertTrue(token.supportsInterface(type(IERC721).interfaceId));

        // The interface that SeaDrop 1.0 strictly checks for in the modifier
        // `onlyINonFungibleSeaDropToken` must return true, otherwise the
        // contract will not be able to interact with SeaDrop 1.0.
        assertTrue(token.supportsInterface(0x1890fe8e));

        // ERC-4906.
        assertTrue(token.supportsInterface(0x49064906));

        // Invalid interfaces return false.
        assertFalse(token.supportsInterface(0x00000000));
        assertFalse(token.supportsInterface(0x10000000));
        assertFalse(token.supportsInterface(0x00000001));
    }

    function testUpdateAllowedSeaDrop_onlyOwner() public {
        vm.prank(creator);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.updateAllowedSeaDrop(_allowedSeaDrop());

        vm.prank(minter);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.updateAllowedSeaDrop(_allowedSeaDrop());

        _expectAllowedSeaDropUpdated(_allowedSeaDrop());

        address address1 = _addr(0x11);
        address address2 = _addr(0x22);
        address address3 = _addr(0x33);

        address[] memory list = new address[](2);
        list[0] = address(seadrop);
        list[1] = address1;
        _expectAllowedSeaDropUpdated(list);

        list = new address[](1);
        list[0] = address2;
        _expectAllowedSeaDropUpdated(list);

        list = new address[](4);
        list[0] = address3;
        list[1] = address(seadrop);
        list[2] = address2;
        list[3] = address1;
        _expectAllowedSeaDropUpdated(list);

        _expectAllowedSeaDropUpdated(_allowedSeaDrop());
    }

    function _expectAllowedSeaDropUpdated(address[] memory allowedSeaDrop)
        internal
    {
        vm.expectEmit(true, true, true, true, address(token));
        emit AllowedSeaDropUpdated(allowedSeaDrop);
        token.updateAllowedSeaDrop(allowedSeaDrop);
    }

    function testAdminMethods_onlyOwner() public {
        // updateAllowList
        AllowListData memory allowListData = _allowListData();
        token.updateAllowList(address(seadrop), allowListData);

        vm.prank(creator);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.updateAllowList(address(seadrop), allowListData);

        // updateTokenGatedDrop
        TokenGatedDropStage memory dropStage = _tokenGatedDropStage();
        token.updateTokenGatedDrop(address(seadrop), _addr(0x44), dropStage);

        vm.prank(creator);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.updateTokenGatedDrop(address(seadrop), _addr(0x44), dropStage);

        // updateSignedMintValidationParams
        SignedMintValidationParams memory signedMintValidationParams =
            _signedMintValidationParams();
        token.updateSignedMintValidationParams(
            address(seadrop), _addr(0x55), signedMintValidationParams
        );

        vm.prank(creator);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.updateSignedMintValidationParams(
            address(seadrop), _addr(0x55), signedMintValidationParams
        );

        // updatePayer
        token.updatePayer(address(seadrop), _addr(0x66), true);

        // The original Hardhat case checked updateSignedMintValidationParams
        // again here (with the payer address as signer); kept as written.
        // updatePayer's owner check is covered in testUpdateMethods_onlyOwner.
        vm.prank(creator);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.updateSignedMintValidationParams(
            address(seadrop), _addr(0x66), signedMintValidationParams
        );
    }

    function testUpdatePayer() public {
        address payer = makeAddr("payer");
        address payer2 = makeAddr("payer2");

        vm.expectRevert(PayerNotPresent.selector);
        token.updatePayer(address(seadrop), payer, false);

        token.updatePayer(address(seadrop), payer, true);

        // Ensure that the same payer cannot be added twice.
        vm.expectRevert(DuplicatePayer.selector);
        token.updatePayer(address(seadrop), payer, true);

        // Ensure that the zero address cannot be added as a payer.
        vm.expectRevert(PayerCannotBeZeroAddress.selector);
        token.updatePayer(address(seadrop), address(0), true);

        // Remove the original payer for branch coverage.
        token.updatePayer(address(seadrop), payer, false);
        assertFalse(seadrop.getPayerIsAllowed(address(token), payer));

        // Add two payers and remove the second for branch coverage.
        token.updatePayer(address(seadrop), payer, true);
        token.updatePayer(address(seadrop), payer2, true);
        token.updatePayer(address(seadrop), payer2, false);
        assertTrue(seadrop.getPayerIsAllowed(address(token), payer));
        assertFalse(seadrop.getPayerIsAllowed(address(token), payer2));
    }

    function testUpdateMethods_onlyOwner() public {
        bytes4 onlyOwner = TwoStepOwnable.OnlyOwner.selector;
        bytes4 onlyAllowedSeaDrop =
            INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector;
        address seaDropImpl = address(seadrop);
        address nonSeaDrop = creator;
        address addr4 = _addr(0x44);

        // updateAllowedSeaDrop (no SeaDrop parameter to swap)
        token.updateAllowedSeaDrop(_allowedSeaDrop());
        vm.prank(creator);
        vm.expectRevert(onlyOwner);
        token.updateAllowedSeaDrop(_allowedSeaDrop());

        // updatePublicDrop
        token.updatePublicDrop(seaDropImpl, publicDrop);
        vm.prank(creator);
        vm.expectRevert(onlyOwner);
        token.updatePublicDrop(seaDropImpl, publicDrop);
        vm.expectRevert(onlyAllowedSeaDrop);
        token.updatePublicDrop(nonSeaDrop, publicDrop);

        // updateAllowList
        AllowListData memory allowListData = _allowListData();
        token.updateAllowList(seaDropImpl, allowListData);
        vm.prank(creator);
        vm.expectRevert(onlyOwner);
        token.updateAllowList(seaDropImpl, allowListData);
        vm.expectRevert(onlyAllowedSeaDrop);
        token.updateAllowList(nonSeaDrop, allowListData);

        // updateTokenGatedDrop
        TokenGatedDropStage memory dropStage = _tokenGatedDropStage();
        token.updateTokenGatedDrop(seaDropImpl, addr4, dropStage);
        vm.prank(creator);
        vm.expectRevert(onlyOwner);
        token.updateTokenGatedDrop(seaDropImpl, addr4, dropStage);
        vm.expectRevert(onlyAllowedSeaDrop);
        token.updateTokenGatedDrop(nonSeaDrop, addr4, dropStage);

        // updateDropURI
        token.updateDropURI(seaDropImpl, "http://test.com");
        vm.prank(creator);
        vm.expectRevert(onlyOwner);
        token.updateDropURI(seaDropImpl, "http://test.com");
        vm.expectRevert(onlyAllowedSeaDrop);
        token.updateDropURI(nonSeaDrop, "http://test.com");

        // updateCreatorPayoutAddress
        token.updateCreatorPayoutAddress(seaDropImpl, addr4);
        vm.prank(creator);
        vm.expectRevert(onlyOwner);
        token.updateCreatorPayoutAddress(seaDropImpl, addr4);
        vm.expectRevert(onlyAllowedSeaDrop);
        token.updateCreatorPayoutAddress(nonSeaDrop, addr4);

        // updateAllowedFeeRecipient
        token.updateAllowedFeeRecipient(seaDropImpl, addr4, true);
        vm.prank(creator);
        vm.expectRevert(onlyOwner);
        token.updateAllowedFeeRecipient(seaDropImpl, addr4, true);
        vm.expectRevert(onlyAllowedSeaDrop);
        token.updateAllowedFeeRecipient(nonSeaDrop, addr4, true);

        // updateSignedMintValidationParams
        SignedMintValidationParams memory signedMintValidationParams =
            _signedMintValidationParams();
        token.updateSignedMintValidationParams(
            seaDropImpl, addr4, signedMintValidationParams
        );
        vm.prank(creator);
        vm.expectRevert(onlyOwner);
        token.updateSignedMintValidationParams(
            seaDropImpl, addr4, signedMintValidationParams
        );
        vm.expectRevert(onlyAllowedSeaDrop);
        token.updateSignedMintValidationParams(
            nonSeaDrop, addr4, signedMintValidationParams
        );

        // updatePayer
        token.updatePayer(seaDropImpl, addr4, true);
        vm.prank(creator);
        vm.expectRevert(onlyOwner);
        token.updatePayer(seaDropImpl, addr4, true);
        vm.expectRevert(onlyAllowedSeaDrop);
        token.updatePayer(nonSeaDrop, addr4, true);
    }

    function testTransfer() public {
        token.updatePublicDrop(address(seadrop), publicDrop);
        token.setMaxSupply(5);

        address feeRecipient = makeAddr("feeRecipient");
        token.updateAllowedFeeRecipient(address(seadrop), feeRecipient, true);
        token.updateCreatorPayoutAddress(address(seadrop), creator);

        hoax(minter, 100 ether);
        seadrop.mintPublic{ value: publicDrop.mintPrice * 5 }(
            address(token), feeRecipient, address(0), 5
        );

        vm.startPrank(minter);
        token.transferFrom(minter, creator, 1);
        token.safeTransferFrom(minter, creator, 2);
        token.safeTransferFrom(minter, creator, 3, hex"dadb0d");
        assertEq(token.balanceOf(creator), 3);

        token.setApprovalForAll(creator, true);
        token.approve(creator, 4);
        vm.stopPrank();
    }

    /// @dev approve, transferFrom and both safeTransferFrom overloads are
    ///      non-payable, so ETH sent with them reverts instead of staying in
    ///      the token, which cannot withdraw it. Each call succeeds without
    ///      value, so the revert comes from the value alone.
    function testApproveAndTransfers_revertWithValue() public {
        token.setMaxSupply(1);
        vm.prank(address(seadrop));
        token.mintSeaDrop(minter, 1);
        vm.deal(minter, 1 ether);
        vm.deal(creator, 1 ether);

        address[4] memory callers = [minter, minter, creator, minter];
        bytes[4] memory calls = [
            abi.encodeCall(IERC721.approve, (creator, 1)),
            abi.encodeCall(IERC721.transferFrom, (minter, creator, 1)),
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)", creator, minter, 1
            ),
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,bytes)",
                minter,
                creator,
                1,
                hex"dadb0d"
            )
        ];

        for (uint256 i = 0; i < calls.length; i++) {
            vm.prank(callers[i]);
            (bool success, bytes memory returnData) =
                address(token).call{ value: 1 }(calls[i]);
            assertFalse(success, "call with value should revert");
            assertEq(returnData.length, 0, "non-payable check reverts empty");

            vm.prank(callers[i]);
            (success,) = address(token).call(calls[i]);
            assertTrue(success, "call without value should succeed");
        }

        assertEq(token.ownerOf(1), creator);
        assertEq(address(token).balance, 0);
    }

    function _fullConfig(address feeRecipient)
        internal
        view
        returns (ERC721SeaDropStructsErrorsAndEvents
                    .MultiConfigureStruct memory config)
    {
        config.maxSupply = 100;
        config.baseURI = "https://example1.com";
        config.contractURI = "https://example2.com";
        config.seaDropImpl = address(seadrop);
        config.publicDrop = publicDrop;
        config.dropURI = "https://example3.com";
        config.allowListData = _allowListData();
        config.creatorPayoutAddress = creator;
        config.provenanceHash = bytes32(0x33 * _REPEAT);

        config.allowedFeeRecipients = new address[](1);
        config.allowedFeeRecipients[0] = feeRecipient;

        config.allowedPayers = new address[](2);
        config.allowedPayers[0] = _addr(0x44);
        config.allowedPayers[1] = _addr(0x55);

        config.tokenGatedAllowedNftTokens = new address[](2);
        config.tokenGatedAllowedNftTokens[0] = _addr(0x66);
        config.tokenGatedAllowedNftTokens[1] = _addr(0x77);

        // Each element gets its own memory struct, since assigning one memory
        // struct to two array slots would alias them.
        // The Hardhat spec built the second stage's price by string
        // concatenation ("10000000000000000" + "1"), giving 0.1 ether + 1 wei.
        config.tokenGatedDropStages = new TokenGatedDropStage[](2);
        config.tokenGatedDropStages[0] = _tokenGatedDropStage();
        config.tokenGatedDropStages[1] = _tokenGatedDropStage();
        config.tokenGatedDropStages[1].mintPrice = 100000000000000001;

        config.signers = new address[](2);
        config.signers[0] = _addr(0x88);
        config.signers[1] = _addr(0x99);

        config.signedMintValidationParams = new SignedMintValidationParams[](2);
        config.signedMintValidationParams[0] = _signedMintValidationParams();
        config.signedMintValidationParams[1] = _signedMintValidationParams();
        config.signedMintValidationParams[1].minMintPrice += 1;
    }

    function _zeroedConfig()
        internal
        view
        returns (ERC721SeaDropStructsErrorsAndEvents
                    .MultiConfigureStruct memory config)
    {
        config.seaDropImpl = address(seadrop);
        config.publicDrop.restrictFeeRecipients = true;
    }

    function _checkMultiConfigureResults(
        ERC721SeaDropStructsErrorsAndEvents.MultiConfigureStruct memory config,
        address feeRecipient
    ) internal view {
        assertEq(token.maxSupply(), 100);
        assertEq(token.baseURI(), "https://example1.com");
        assertEq(token.contractURI(), "https://example2.com");

        PublicDrop memory storedPublicDrop =
            seadrop.getPublicDrop(address(token));
        assertEq(storedPublicDrop.mintPrice, publicDrop.mintPrice);
        assertEq(storedPublicDrop.startTime, publicDrop.startTime);
        assertEq(storedPublicDrop.endTime, publicDrop.endTime);
        assertEq(
            storedPublicDrop.maxTotalMintableByWallet,
            publicDrop.maxTotalMintableByWallet
        );
        assertEq(storedPublicDrop.feeBps, publicDrop.feeBps);
        assertEq(
            storedPublicDrop.restrictFeeRecipients,
            publicDrop.restrictFeeRecipients
        );

        assertEq(
            seadrop.getAllowListMerkleRoot(address(token)),
            config.allowListData.merkleRoot
        );
        assertEq(seadrop.getCreatorPayoutAddress(address(token)), creator);

        address[] memory feeRecipients =
            seadrop.getAllowedFeeRecipients(address(token));
        assertEq(feeRecipients.length, 1);
        assertEq(feeRecipients[0], feeRecipient);

        assertEq(seadrop.getPayers(address(token)), config.allowedPayers);
        assertEq(token.provenanceHash(), bytes32(0x33 * _REPEAT));

        assertEq(
            seadrop.getTokenGatedAllowedTokens(address(token)),
            config.tokenGatedAllowedNftTokens
        );
        for (uint256 i = 0; i < config.tokenGatedAllowedNftTokens.length; i++) {
            _assertTokenGatedDropEq(
                seadrop.getTokenGatedDrop(
                    address(token), config.tokenGatedAllowedNftTokens[i]
                ),
                config.tokenGatedDropStages[i]
            );
        }

        assertEq(seadrop.getSigners(address(token)), config.signers);
        for (uint256 i = 0; i < config.signers.length; i++) {
            _assertSignedMintValidationParamsEq(
                seadrop.getSignedMintValidationParams(
                    address(token), config.signers[i]
                ),
                config.signedMintValidationParams[i]
            );
        }
    }

    function testMultiConfigure() public {
        address feeRecipient = makeAddr("feeRecipient");
        ERC721SeaDropStructsErrorsAndEvents.MultiConfigureStruct memory config =
            _fullConfig(feeRecipient);

        vm.prank(creator);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.multiConfigure(config);

        // Should revert if tokenGatedAllowedNftTokens.length !=
        // tokenGatedDropStages.length.
        ERC721SeaDropStructsErrorsAndEvents.MultiConfigureStruct memory
            mismatched = _fullConfig(feeRecipient);
        mismatched.tokenGatedAllowedNftTokens = new address[](1);
        mismatched.tokenGatedAllowedNftTokens[0] = _addr(0x77);
        vm.expectRevert(
            ERC721SeaDropStructsErrorsAndEvents.TokenGatedMismatch.selector
        );
        token.multiConfigure(mismatched);

        // Should revert if signers.length != signedMintValidationParams.length.
        mismatched = _fullConfig(feeRecipient);
        mismatched.signers = new address[](1);
        mismatched.signers[0] = _addr(0x99);
        vm.expectRevert(
            ERC721SeaDropStructsErrorsAndEvents.SignersMismatch.selector
        );
        token.multiConfigure(mismatched);

        vm.expectEmit(true, true, true, true, address(seadrop));
        emit DropURIUpdated(address(token), "https://example3.com");
        token.multiConfigure(config);

        _checkMultiConfigureResults(config, feeRecipient);

        // Should not do anything if all fields are zeroed out.
        vm.recordLogs();
        token.multiConfigure(_zeroedConfig());
        _assertNotEmitted(address(seadrop), DropURIUpdated.selector);

        _checkMultiConfigureResults(config, feeRecipient);

        // Should unset properties.
        ERC721SeaDropStructsErrorsAndEvents.MultiConfigureStruct memory unset =
            _zeroedConfig();
        unset.disallowedFeeRecipients = config.allowedFeeRecipients;
        vm.expectEmit(true, true, true, true, address(seadrop));
        emit AllowedFeeRecipientUpdated(address(token), feeRecipient, false);
        token.multiConfigure(unset);

        unset = _zeroedConfig();
        unset.disallowedPayers = config.allowedPayers;
        vm.expectEmit(true, true, true, true, address(seadrop));
        emit PayerUpdated(address(token), config.allowedPayers[0], false);
        token.multiConfigure(unset);

        unset = _zeroedConfig();
        unset.disallowedTokenGatedAllowedNftTokens = new address[](1);
        unset.disallowedTokenGatedAllowedNftTokens[0] =
            config.tokenGatedAllowedNftTokens[0];
        TokenGatedDropStage memory emptyStage;
        vm.expectEmit(true, true, true, true, address(seadrop));
        emit TokenGatedDropStageUpdated(
            address(token),
            config.tokenGatedAllowedNftTokens[0],
            emptyStage
        );
        token.multiConfigure(unset);

        unset = _zeroedConfig();
        unset.disallowedSigners = new address[](1);
        unset.disallowedSigners[0] = config.signers[0];
        SignedMintValidationParams memory emptyParams;
        vm.expectEmit(true, true, true, true, address(seadrop));
        emit SignedMintValidationParamsUpdated(
            address(token),
            config.signers[0],
            emptyParams
        );
        token.multiConfigure(unset);
    }

    /// @dev Token gated tokens or signers passed without their stages or
    ///      params (or the reverse) revert instead of being skipped.
    function testMultiConfigure_revertsOnUnpairedArrays() public {
        ERC721SeaDropStructsErrorsAndEvents.MultiConfigureStruct memory config =
            _zeroedConfig();
        config.tokenGatedAllowedNftTokens = new address[](1);
        config.tokenGatedAllowedNftTokens[0] = _addr(0x66);
        vm.expectRevert(
            ERC721SeaDropStructsErrorsAndEvents.TokenGatedMismatch.selector
        );
        token.multiConfigure(config);

        config = _zeroedConfig();
        config.tokenGatedDropStages = new TokenGatedDropStage[](1);
        config.tokenGatedDropStages[0] = _tokenGatedDropStage();
        vm.expectRevert(
            ERC721SeaDropStructsErrorsAndEvents.TokenGatedMismatch.selector
        );
        token.multiConfigure(config);

        config = _zeroedConfig();
        config.signers = new address[](1);
        config.signers[0] = _addr(0x88);
        vm.expectRevert(
            ERC721SeaDropStructsErrorsAndEvents.SignersMismatch.selector
        );
        token.multiConfigure(config);

        config = _zeroedConfig();
        config.signedMintValidationParams = new SignedMintValidationParams[](1);
        config.signedMintValidationParams[0] = _signedMintValidationParams();
        vm.expectRevert(
            ERC721SeaDropStructsErrorsAndEvents.SignersMismatch.selector
        );
        token.multiConfigure(config);

        assertEq(seadrop.getTokenGatedAllowedTokens(address(token)).length, 0);
        assertEq(seadrop.getSigners(address(token)).length, 0);
    }

    function testBurn_onlyOwnerOrApproved() public {
        token.setMaxSupply(3);

        // Mint three tokens to the minter.
        vm.prank(address(seadrop));
        token.mintSeaDrop(minter, 3);

        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        assertEq(token.ownerOf(3), minter);
        assertEq(token.totalSupply(), 3);

        // Only the owner or approved of the minted token should be able to
        // burn it.
        bytes4 notOwnerNorApproved =
            IERC721A.TransferCallerNotOwnerNorApproved.selector;
        vm.prank(creator);
        vm.expectRevert(notOwnerNorApproved);
        token.burn(1);
        vm.expectRevert(notOwnerNorApproved);
        token.burn(1);
        vm.expectRevert(notOwnerNorApproved);
        token.burn(2);
        vm.expectRevert(notOwnerNorApproved);
        token.burn(3);

        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        assertEq(token.ownerOf(3), minter);
        assertEq(token.totalSupply(), 3);

        vm.prank(minter);
        token.burn(1);

        assertEq(token.totalSupply(), 2);

        vm.prank(minter);
        token.setApprovalForAll(address(this), true);
        token.burn(2);

        assertEq(token.totalSupply(), 1);

        vm.prank(minter);
        token.setApprovalForAll(address(this), false);
        vm.expectRevert(notOwnerNorApproved);
        token.burn(3);

        vm.prank(minter);
        token.approve(creator, 3);
        vm.prank(creator);
        token.burn(3);

        assertEq(token.totalSupply(), 0);

        bytes4 nonexistent = IERC721A.OwnerQueryForNonexistentToken.selector;
        vm.expectRevert(nonexistent);
        token.ownerOf(1);
        vm.expectRevert(nonexistent);
        token.ownerOf(2);
        assertEq(token.totalSupply(), 0);

        // Should not be able to burn a nonexistent token.
        for (uint256 tokenId = 0; tokenId <= 3; tokenId++) {
            vm.prank(minter);
            vm.expectRevert(nonexistent);
            token.burn(tokenId);
        }
    }

    function _assertTokenGatedDropEq(
        TokenGatedDropStage memory a,
        TokenGatedDropStage memory b
    ) internal pure {
        assertEq(a.mintPrice, b.mintPrice);
        assertEq(a.maxTotalMintableByWallet, b.maxTotalMintableByWallet);
        assertEq(a.startTime, b.startTime);
        assertEq(a.endTime, b.endTime);
        assertEq(a.dropStageIndex, b.dropStageIndex);
        assertEq(a.maxTokenSupplyForStage, b.maxTokenSupplyForStage);
        assertEq(a.feeBps, b.feeBps);
        assertEq(a.restrictFeeRecipients, b.restrictFeeRecipients);
    }

    function _assertSignedMintValidationParamsEq(
        SignedMintValidationParams memory a,
        SignedMintValidationParams memory b
    ) internal pure {
        assertEq(a.minMintPrice, b.minMintPrice);
        assertEq(a.maxMaxTotalMintableByWallet, b.maxMaxTotalMintableByWallet);
        assertEq(a.minStartTime, b.minStartTime);
        assertEq(a.maxEndTime, b.maxEndTime);
        assertEq(a.maxMaxTokenSupplyForStage, b.maxMaxTokenSupplyForStage);
        assertEq(a.minFeeBps, b.minFeeBps);
        assertEq(a.maxFeeBps, b.maxFeeBps);
    }

    /// @dev Assert that no log with `topic0` was emitted by `emitter` since
    ///      `vm.recordLogs()` was called.
    function _assertNotEmitted(address emitter, bytes32 topic0) internal view {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            bool matches = logs[i].emitter == emitter
                && logs[i].topics.length != 0 && logs[i].topics[0] == topic0;
            assertFalse(matches, "unexpected event emitted");
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        public
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
