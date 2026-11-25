// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropV3TestHelper } from "./utils/SeaDropV3TestHelper.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { ISeaDropTokenV3 } from "seadrop/v3/interfaces/ISeaDropTokenV3.sol";

import { SeaDropTokenV3Base } from "seadrop/v3/SeaDropTokenV3Base.sol";

import { ERC1155SeaDropV3 } from "seadrop/v3/ERC1155SeaDropV3.sol";

import {
    ERC1155SeaDropV3Standalone
} from "seadrop/v3/ERC1155SeaDropV3Standalone.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

import {
    ConstructorInitializable
} from "utility-contracts/ConstructorInitializable.sol";

contract ERC1155SeaDropV3StandaloneTest is SeaDropV3TestHelper {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event AllowedMinterUpdated(address indexed minter, bool allowed);

    string internal constant URI = "ipfs://{id}";

    address internal deployer = makeAddr("deployer");

    ERC1155SeaDropV3Standalone internal standalone;

    function setUp() public override {
        super.setUp();
        vm.prank(deployer);
        standalone = new ERC1155SeaDropV3Standalone(
            address(this), address(minter), URI, CONDUIT
        );
        _setSinglePayout(address(standalone), creator);
    }

    // ---------------------------------------------------------------------
    // Deployment and initialization
    // ---------------------------------------------------------------------

    function test_deploy_setsOwnerMinterURIAndConduit() public {
        address predicted =
            vm.computeCreateAddress(deployer, vm.getNonce(deployer));
        vm.expectEmit(predicted);
        emit OwnershipTransferred(address(0), alice);
        vm.expectEmit(predicted);
        emit AllowedMinterUpdated(address(minter), true);
        vm.prank(deployer);
        ERC1155SeaDropV3Standalone token = new ERC1155SeaDropV3Standalone(
            alice, address(minter), URI, CONDUIT
        );

        assertEq(address(token), predicted);
        assertEq(token.owner(), alice);
        assertTrue(token.allowedMinters(address(minter)));
        assertFalse(token.allowedMinters(deployer));
        assertFalse(token.allowedMinters(alice));
        assertEq(token.uri(1), URI);
        assertEq(token.preapprovedConduit(), CONDUIT);
        assertEq(token.factory(), deployer);
        assertTrue(token.supportsInterface(type(ISeaDropTokenV3).interfaceId));
        assertTrue(token.supportsInterface(0xd9b67a26)); // ERC-1155
    }

    function test_deploy_withoutConduitPreapprovesNothing() public {
        ERC1155SeaDropV3Standalone token = new ERC1155SeaDropV3Standalone(
            alice, address(minter), URI, address(0)
        );
        assertEq(token.preapprovedConduit(), address(0));
        assertFalse(token.isApprovedForAll(alice, address(0)));
        assertFalse(token.isApprovedForAll(alice, CONDUIT));
    }

    /// @dev The provenance OpenSea checks: the creation input is the
    ///      creation code followed by the ABI-encoded constructor args.
    function test_deploy_fromCreationCodeAndEncodedArgs() public {
        bytes memory initcode = abi.encodePacked(
            type(ERC1155SeaDropV3Standalone).creationCode,
            abi.encode(alice, address(minter), URI, CONDUIT)
        );
        address token;
        assembly {
            token := create(0, add(initcode, 0x20), mload(initcode))
        }
        assertTrue(token != address(0));
        // The immutables, the conduit and the deployer, match too.
        ERC1155SeaDropV3Standalone viaNew = new ERC1155SeaDropV3Standalone(
            alice, address(minter), URI, CONDUIT
        );
        assertEq(keccak256(token.code), keccak256(address(viaNew).code));
        ERC1155SeaDropV3Standalone deployed = ERC1155SeaDropV3Standalone(token);
        assertEq(deployed.owner(), alice);
        assertTrue(deployed.allowedMinters(address(minter)));
        assertEq(deployed.uri(1), URI);
        assertEq(deployed.preapprovedConduit(), CONDUIT);
        assertEq(deployed.factory(), address(this));
    }

    function test_revert_deploy_ownerIsZeroAddress() public {
        vm.expectRevert(TwoStepOwnable.NewOwnerIsZeroAddress.selector);
        new ERC1155SeaDropV3Standalone(
            address(0), address(minter), URI, CONDUIT
        );
    }

    function test_revert_deploy_minterIsZeroAddress() public {
        vm.expectRevert(SeaDropTokenV3Base.MinterIsZeroAddress.selector);
        new ERC1155SeaDropV3Standalone(alice, address(0), URI, CONDUIT);
    }

    function test_revert_initialize_byDeployer() public {
        vm.prank(deployer);
        vm.expectRevert(ConstructorInitializable.AlreadyInitialized.selector);
        standalone.initialize(alice, alice);
        assertEq(standalone.owner(), address(this));
        assertFalse(standalone.allowedMinters(alice));
    }

    function test_revert_initialize_byAnyoneElse(address caller) public {
        vm.assume(caller != deployer);
        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.OnlyFactory.selector, caller
            )
        );
        standalone.initialize(caller, caller);
        assertEq(standalone.owner(), address(this));
    }

    // ---------------------------------------------------------------------
    // Behaves like a clone
    // ---------------------------------------------------------------------

    function test_mintThroughMinter() public {
        standalone.setMaxSupply(1, uint128(MAX_SUPPLY));
        minter.setStage(address(standalone), 1, 0, _publicStage());

        vm.prank(alice);
        minter.mint{ value: PRICE * 2 }(
            _params(address(standalone), 1, alice, alice, 2), _noAuth()
        );

        assertEq(standalone.balanceOf(alice, 1), 2);
        (uint256 totalMinted, uint256 maxSupply) = standalone.mintStats(1);
        assertEq(totalMinted, 2);
        assertEq(maxSupply, MAX_SUPPLY);
        assertEq(address(minter).balance, 0);
        assertEq(creator.balance, PRICE * 2 * (10_000 - FEE_BPS) / 10_000);
    }

    function test_revert_mintSeaDrop_notAllowedMinter() public {
        standalone.setMaxSupply(1, 1);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.OnlyAllowedMinter.selector, alice
            )
        );
        standalone.mintSeaDrop(alice, 1, 1);
    }

    function test_onlyOwnerAdmin() public {
        vm.startPrank(alice);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        standalone.setMaxSupply(1, 1);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        standalone.setURI("x");
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        standalone.setAllowedMinter(alice, true);
        vm.stopPrank();
    }

    function test_conduitIsPreapprovedUntilRevoked() public {
        assertTrue(standalone.isApprovedForAll(alice, CONDUIT));
        vm.prank(alice);
        standalone.setApprovalForAll(CONDUIT, false);
        assertFalse(standalone.isApprovedForAll(alice, CONDUIT));
        vm.prank(alice);
        standalone.setApprovalForAll(CONDUIT, true);
        assertTrue(standalone.isApprovedForAll(alice, CONDUIT));
    }

    // ---------------------------------------------------------------------
    // Token ids start at 1, for the clone and the standalone token
    // ---------------------------------------------------------------------

    function _tokens() internal view returns (ERC1155SeaDropV3[2] memory) {
        return [token1155, ERC1155SeaDropV3(address(standalone))];
    }

    function test_revert_setMaxSupply_idZero() public {
        ERC1155SeaDropV3[2] memory tokens = _tokens();
        for (uint256 i; i < tokens.length; ++i) {
            vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
            tokens[i].setMaxSupply(0, uint128(MAX_SUPPLY));
            (, uint256 maxSupply) = tokens[i].mintStats(0);
            assertEq(maxSupply, 0);
        }
    }

    function test_revert_mintSeaDrop_idZero_fromAllowedMinter() public {
        ERC1155SeaDropV3[2] memory tokens = _tokens();
        for (uint256 i; i < tokens.length; ++i) {
            vm.prank(address(minter));
            vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
            tokens[i].mintSeaDrop(alice, 0, 0);
        }
    }

    function test_revert_zeroQuantityFromAllowedMinter() public {
        ERC1155SeaDropV3[2] memory tokens = _tokens();
        for (uint256 i; i < tokens.length; ++i) {
            vm.prank(address(minter));
            vm.expectRevert(ERC1155SeaDropV3.QuantityIsZero.selector);
            tokens[i].mintSeaDrop(alice, 1, 0);
        }
    }

    function test_revert_mint_idZero_throughMinter() public {
        ERC1155SeaDropV3[2] memory tokens = _tokens();
        for (uint256 i; i < tokens.length; ++i) {
            address token = address(tokens[i]);
            // The minter keeps no per-token id rules, so a stage at id 0
            // can be set. The token rejects the mint.
            minter.setStage(token, 0, 0, _publicStage());

            vm.prank(alice);
            vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
            minter.mint{ value: PRICE }(
                _params(token, 0, alice, alice, 1), _noAuth()
            );
            assertEq(tokens[i].balanceOf(alice, 0), 0);
        }
    }

    function test_revert_ownerMint_idZero() public {
        ERC1155SeaDropV3[2] memory tokens = _tokens();
        for (uint256 i; i < tokens.length; ++i) {
            vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
            minter.ownerMint(address(tokens[i]), 0, alice, 1);
        }
    }

    function test_idOneMints() public {
        ERC1155SeaDropV3[2] memory tokens = _tokens();
        for (uint256 i; i < tokens.length; ++i) {
            address token = address(tokens[i]);
            tokens[i].setMaxSupply(1, uint128(MAX_SUPPLY));
            minter.setStage(token, 1, 0, _publicStage());

            vm.prank(alice);
            minter.mint{ value: PRICE }(
                _params(token, 1, alice, alice, 1), _noAuth()
            );
            minter.ownerMint(token, 1, bob, 2);

            assertEq(tokens[i].balanceOf(alice, 1), 1);
            assertEq(tokens[i].balanceOf(bob, 1), 2);
            (uint256 totalMinted,) = tokens[i].mintStats(1);
            assertEq(totalMinted, 3);
        }
    }

    function testFuzz_nonzeroIdsMint(uint256 id, uint128 maxSupply) public {
        id = bound(id, 1, type(uint256).max);
        maxSupply = uint128(bound(maxSupply, 1, type(uint128).max));
        ERC1155SeaDropV3[2] memory tokens = _tokens();
        for (uint256 i; i < tokens.length; ++i) {
            tokens[i].setMaxSupply(id, maxSupply);
            vm.prank(address(minter));
            tokens[i].mintSeaDrop(alice, id, 1);
            (uint256 totalMinted, uint256 max) = tokens[i].mintStats(id);
            assertEq(totalMinted, 1);
            assertEq(max, maxSupply);
            assertEq(tokens[i].balanceOf(alice, id), 1);
        }
    }
}
