// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { Test } from "forge-std/Test.sol";

import { SeaDropMinter } from "seadrop/v3/SeaDropMinter.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { SeaDropTokenFactory } from "seadrop/v3/SeaDropTokenFactory.sol";

/**
 * @dev Pins the events OpenSea indexes to the field lists in
 *      docs/v3/AuditScope.md ("Event schema"). Changing a field's type or
 *      order fails here. Changing a config event's fields means bumping
 *      CONFIG_EVENT_VERSION, updating the doc, and telling the indexer.
 */
contract SeaDropV3EventSchemaTest is Test {
    function test_configEventVersion() public {
        SeaDropMinter minter = new SeaDropMinter(address(this));
        assertEq(minter.CONFIG_EVENT_VERSION(), 1);
    }

    function test_minterEventSignatures() public pure {
        assertEq(
            ISeaDropMinter.StageUpdated.selector,
            keccak256(
                "StageUpdated(uint256,address,uint256,uint256,"
                "(uint96,address,uint40,uint40,uint16,address,uint32,uint32,"
                "uint32,address))"
            )
        );
        assertEq(
            ISeaDropMinter.PayoutRecipientsUpdated.selector,
            keccak256(
                "PayoutRecipientsUpdated(uint256,address,(address,uint16)[])"
            )
        );
        assertEq(
            ISeaDropMinter.CurrencyUpdated.selector,
            keccak256("CurrencyUpdated(uint256,address,(bool,uint16,address))")
        );
        assertEq(
            ISeaDropMinter.SignerSetUpdated.selector,
            keccak256("SignerSetUpdated(uint256,uint32,address,bool)")
        );
        assertEq(
            ISeaDropMinter.TokenFactoryUpdated.selector,
            keccak256("TokenFactoryUpdated(uint256,address,bool)")
        );
        assertEq(
            ISeaDropMinter.TokenRegistered.selector,
            keccak256("TokenRegistered(uint256,address,address)")
        );
        assertEq(
            ISeaDropMinter.SeaDropMint.selector,
            keccak256(
                "SeaDropMint(address,uint256,uint256,address,address,address,"
                "uint256,uint256,address,address,uint256)"
            )
        );
        assertEq(
            ISeaDropMinter.PaymentCredited.selector,
            keccak256("PaymentCredited(address,address,uint256)")
        );
        assertEq(
            ISeaDropMinter.Withdrawal.selector,
            keccak256("Withdrawal(address,address,address,uint256)")
        );
        assertEq(
            ISeaDropMinter.IntentCancelled.selector,
            keccak256("IntentCancelled(address,uint256)")
        );
    }

    function test_factoryEventSignature() public pure {
        assertEq(
            SeaDropTokenFactory.TokenCreated.selector,
            keccak256("TokenCreated(address,address,address,bytes32)")
        );
    }
}
