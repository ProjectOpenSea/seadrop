// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropV3TestHelper } from "./utils/SeaDropV3TestHelper.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    INonFungibleSeaDropToken
} from "seadrop/interfaces/INonFungibleSeaDropToken.sol";

/**
 * @dev An existing v1 token, this repo's own ERC721SeaDrop, mints through
 *      the v3 minter once its owner adds the minter with
 *      `updateAllowedSeaDrop`. Its owner configures the drop on the minter
 *      directly.
 */
contract SeaDropMinterV1CompatTest is SeaDropV3TestHelper {
    ERC721SeaDrop internal v1Token;

    function setUp() public override {
        super.setUp();

        // Deployed before v3 existed, with only v1 SeaDrop allowed.
        address[] memory allowed = new address[](1);
        allowed[0] = makeAddr("v1SeaDrop");
        v1Token = new ERC721SeaDrop("V1", "V1", allowed);
        v1Token.setMaxSupply(10);

        _setSinglePayout(address(v1Token), creator);
        minter.setStage(address(v1Token), 0, 0, _publicStage());
    }

    function _allowMinter() internal {
        address[] memory allowed = new address[](2);
        allowed[0] = makeAddr("v1SeaDrop");
        allowed[1] = address(minter);
        v1Token.updateAllowedSeaDrop(allowed);
    }

    function test_v1Token_mintsThroughMinter() public {
        _allowMinter();

        vm.expectEmit(address(minter));
        emit ISeaDropMinter.SeaDropMint(
            address(v1Token),
            0,
            0,
            alice,
            alice,
            alice,
            2,
            PRICE,
            address(0),
            feeRecipient,
            FEE_BPS
        );
        vm.prank(alice);
        minter.mint{ value: 2 * PRICE }(
            _params(address(v1Token), 0, alice, alice, 2), _noAuth()
        );

        assertEq(v1Token.ownerOf(1), alice);
        assertEq(v1Token.ownerOf(2), alice);
        assertEq(creator.balance, 2 * PRICE * (10_000 - FEE_BPS) / 10_000);
        assertEq(feeRecipient.balance, 2 * PRICE * FEE_BPS / 10_000);
        assertEq(minter.mintedByWallet(address(v1Token), 0, 0, alice), 2);
    }

    function test_v1Token_signedMint() public {
        _allowMinter();
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.signer = signer;
        minter.setStage(address(v1Token), 0, 0, stage);
        ISeaDropMinter.MintParams memory params =
            _params(address(v1Token), 0, alice, carol, 1);
        params.maxTotalPrice = 0;

        vm.prank(alice);
        minter.mint(params, _authorize(params, signer, signerKey, 1, true, 0));
        assertEq(v1Token.ownerOf(1), carol);
    }

    function test_v1Token_ownerMint() public {
        _allowMinter();
        minter.ownerMint(address(v1Token), 0, carol, 3);
        assertEq(v1Token.balanceOf(carol), 3);
    }

    function test_revert_v1Token_minterNotAllowed() public {
        vm.prank(alice);
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        minter.mint{ value: PRICE }(
            _params(address(v1Token), 0, alice, alice, 1), _noAuth()
        );
    }

    function test_revert_v1Token_maxSupplyFromMintStats() public {
        _allowMinter();
        v1Token.setMaxSupply(1);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.MintQuantityExceedsMaxSupply.selector, 2, 1
            )
        );
        minter.mint{ value: 2 * PRICE }(
            _params(address(v1Token), 0, alice, alice, 2), _noAuth()
        );
    }

    function test_revert_v1Token_configIsOwnerOnly() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.OnlyTokenOwner.selector, address(v1Token), alice
            )
        );
        minter.setStage(address(v1Token), 0, 0, _publicStage());
    }

    function test_revert_setStage_nonzeroIdOnV1Token() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.ERC721StageIdNotZero.selector, 7
            )
        );
        minter.setStage(address(v1Token), 7, 0, _publicStage());
    }
}
