// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import {
    ERC721SeaDropCloneFactory
} from "../../src/clones/ERC721SeaDropCloneFactory.sol";
import {
    ERC721SeaDropCloneable
} from "../../src/clones/ERC721SeaDropCloneable.sol";
import { SeaDrop } from "../../src/SeaDrop.sol";
import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";
import {
    PublicDrop,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "../../src/lib/SeaDropStructs.sol";
import {
    ERC721SeaDropStructsErrorsAndEvents
} from "../../src/lib/ERC721SeaDropStructsErrorsAndEvents.sol";
import {
    ITransferValidator721
} from "../../src/interfaces/ITransferValidator.sol";

contract ERC721SeaDropCloneFactoryTest is Test {
    ERC721SeaDropCloneFactory factory;

    function setUp() public {
        factory = new ERC721SeaDropCloneFactory();
    }

    function testClone__snapshot() public {
        factory.createClone("name", "symbol", bytes32("1"));
    }

    function testCreateClone_saltIsBoundToCaller() public {
        bytes32 salt = bytes32("1");
        address other = makeAddr("other");

        // Another caller using the same salt, for example by copying it
        // from a pending transaction, gets a different clone and doesn't
        // block this one.
        vm.prank(other);
        address theirs = factory.createClone("x", "x", salt);
        address mine = factory.createClone("name", "symbol", salt);

        assertTrue(theirs != mine);
        assertEq(ERC721SeaDropCloneable(theirs).owner(), other);
        assertEq(ERC721SeaDropCloneable(mine).owner(), address(this));

        // The same caller can't reuse a salt.
        vm.expectRevert(bytes("ERC1167: create2 failed"));
        factory.createClone("name", "symbol", salt);
    }

    function testCloneRenounceOwnership_cancelsPendingTransfer() public {
        ERC721SeaDropCloneable token = ERC721SeaDropCloneable(
            factory.createClone("name", "symbol", bytes32("1"))
        );
        address pending = makeAddr("pending");
        token.transferOwnership(pending);

        token.renounceOwnership();
        assertEq(token.owner(), address(0));

        // The pending owner can't take back a renounced clone.
        vm.prank(pending);
        vm.expectRevert(TwoStepOwnable.NotNextOwner.selector);
        token.acceptOwnership();
        assertEq(token.owner(), address(0));
    }

    event SeaDropTokenDeployed();

    function testClone1() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl);
        factory = new ERC721SeaDropCloneFactory();
        vm.expectEmit(false, false, false, false);
        emit SeaDropTokenDeployed();
        address clone = factory.createClone("name", "symbol", bytes32("1"));
        ERC721SeaDropCloneable token = ERC721SeaDropCloneable(clone);

        assertEq(token.name(), "name", "name should be set");
        assertEq(token.symbol(), "symbol", "symbol should be set");
        assertEq(token.owner(), address(this), "owner should be set");
        token.updateCreatorPayoutAddress(
            factory.DEFAULT_SEADROP(), address(1234)
        );
        SeaDrop seaDrop = SeaDrop(factory.DEFAULT_SEADROP());
        assertEq(seaDrop.getCreatorPayoutAddress(address(token)), address(1234));

        assertEq(token.totalSupply(), 0);

        token.updatePublicDrop(
            factory.DEFAULT_SEADROP(),
            PublicDrop({
                mintPrice: 1 ether,
                startTime: uint48(block.timestamp),
                endTime: uint48(block.timestamp + 1 days),
                maxTotalMintableByWallet: 3,
                feeBps: 0,
                restrictFeeRecipients: false
            })
        );
        token.setMaxSupply(100);

        seaDrop.mintPublic{ value: 1 ether }(
            address(token), address(1), address(0), 1
        );
        assertEq(token.totalSupply(), 1);
        assertEq(token.ownerOf(1), address(this));

        assertEq(token.tokenURI(1), "", "tokenURI should be blank at first");
        assertEq(token.baseURI(), "", "baseURI should be blank at first");

        token.setBaseURI("https://example.com");
        assertEq(
            token.tokenURI(1), token.baseURI(), "tokenURI just the baseURI"
        );

        token.setBaseURI("https://example.com/");
        assertEq(
            token.tokenURI(1),
            string(abi.encodePacked(token.baseURI(), "1")),
            "tokenURI the baseURI + tokenID"
        );
    }

    function testClone_Reinitialize() public {
        address clone = factory.createClone("name", "symbol", bytes32("1"));
        ERC721SeaDropCloneable token = ERC721SeaDropCloneable(clone);
        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize("name", "symbol", new address[](0), address(this));
    }

    /// @dev Token gated tokens or signers passed without their stages or
    ///      params (or the reverse) revert instead of being skipped.
    function testClone_multiConfigure_revertsOnUnpairedArrays() public {
        ERC721SeaDropCloneable token = ERC721SeaDropCloneable(
            factory.createClone("name", "symbol", bytes32("1"))
        );
        ERC721SeaDropStructsErrorsAndEvents.MultiConfigureStruct memory config;
        config.seaDropImpl = factory.DEFAULT_SEADROP();

        config.tokenGatedAllowedNftTokens = new address[](1);
        config.tokenGatedAllowedNftTokens[0] = address(0x66);
        vm.expectRevert(
            ERC721SeaDropStructsErrorsAndEvents.TokenGatedMismatch.selector
        );
        token.multiConfigure(config);
        config.tokenGatedAllowedNftTokens = new address[](0);

        config.tokenGatedDropStages = new TokenGatedDropStage[](1);
        vm.expectRevert(
            ERC721SeaDropStructsErrorsAndEvents.TokenGatedMismatch.selector
        );
        token.multiConfigure(config);
        config.tokenGatedDropStages = new TokenGatedDropStage[](0);

        config.signers = new address[](1);
        config.signers[0] = address(0x88);
        vm.expectRevert(
            ERC721SeaDropStructsErrorsAndEvents.SignersMismatch.selector
        );
        token.multiConfigure(config);
        config.signers = new address[](0);

        config.signedMintValidationParams = new SignedMintValidationParams[](1);
        vm.expectRevert(
            ERC721SeaDropStructsErrorsAndEvents.SignersMismatch.selector
        );
        token.multiConfigure(config);
    }

    event ContractURIUpdated(string newContractURI);
    event ContractURIUpdated();

    /// @dev Clones emit ERC-7572's ContractURIUpdated() after SeaDrop's
    ///      original event, from setContractURI and from multiConfigure.
    function testClone_setContractURI_emitsERC7572Event() public {
        ERC721SeaDropCloneable token = ERC721SeaDropCloneable(
            factory.createClone("name", "symbol", bytes32("1"))
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit ContractURIUpdated("https://example.com/contract");
        vm.expectEmit(true, true, true, true, address(token));
        emit ContractURIUpdated();
        token.setContractURI("https://example.com/contract");
        assertEq(token.contractURI(), "https://example.com/contract");

        ERC721SeaDropStructsErrorsAndEvents.MultiConfigureStruct memory config;
        config.seaDropImpl = factory.DEFAULT_SEADROP();
        config.contractURI = "https://example.com/contract2";
        vm.expectEmit(true, true, true, true, address(token));
        emit ContractURIUpdated("https://example.com/contract2");
        vm.expectEmit(true, true, true, true, address(token));
        emit ContractURIUpdated();
        token.multiConfigure(config);
        assertEq(token.contractURI(), "https://example.com/contract2");
    }

    function testClone_getTransferValidationFunction() public {
        ERC721SeaDropCloneable token = ERC721SeaDropCloneable(
            factory.createClone("name", "symbol", bytes32("1"))
        );
        (bytes4 functionSignature, bool isViewFunction) =
            token.getTransferValidationFunction();
        assertEq(
            functionSignature, ITransferValidator721.validateTransfer.selector
        );
        assertEq(isViewFunction, true);
    }

    /// @dev approve, transferFrom and both safeTransferFrom overloads are
    ///      non-payable on clones too, so ETH sent with them reverts. Each
    ///      call succeeds without value.
    function testClone_approveAndTransfers_revertWithValue() public {
        ERC721SeaDropCloneable token = ERC721SeaDropCloneable(
            factory.createClone("name", "symbol", bytes32("1"))
        );
        address minter = makeAddr("minter");
        address receiver = makeAddr("receiver");
        token.setMaxSupply(1);
        vm.prank(factory.DEFAULT_SEADROP());
        token.mintSeaDrop(minter, 1);
        vm.deal(minter, 1 ether);
        vm.deal(receiver, 1 ether);

        address[4] memory callers = [minter, minter, receiver, minter];
        bytes[4] memory calls = [
            abi.encodeWithSignature("approve(address,uint256)", receiver, 1),
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)", minter, receiver, 1
            ),
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)", receiver, minter, 1
            ),
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,bytes)",
                minter,
                receiver,
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

        assertEq(token.ownerOf(1), receiver);
        assertEq(address(token).balance, 0);
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        public
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
