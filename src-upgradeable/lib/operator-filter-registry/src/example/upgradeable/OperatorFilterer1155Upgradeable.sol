// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IOperatorFilterRegistry} from "../../IOperatorFilterRegistry.sol";
import {Initializable} from "../../../../openzeppelin-contracts/proxy/utils/Initializable.sol";

abstract contract OperatorFilterer1155Upgradeable is Initializable {
    error OperatorNotAllowed(address operator);

    IOperatorFilterRegistry constant operatorFilterRegistry =
        IOperatorFilterRegistry(0x000000000000AAeB6D7670E522A718067333cd4E);

    function __OperatorFilterer1155_init(address subscriptionOrRegistrantToCopy, bool subscribe)
        public
        onlyInitializing
    {
        // If an inheriting token contract is deployed to a network without the registry deployed, the modifier
        // will not revert, but the contract will need to be registered with the registry once it is deployed in
        // order for the modifier to filter addresses.
        if (address(operatorFilterRegistry).code.length > 0) {
            if (!operatorFilterRegistry.isRegistered(address(this))) {
                if (subscribe) {
                    operatorFilterRegistry.registerAndSubscribe(address(this), subscriptionOrRegistrantToCopy);
                } else {
                    if (subscriptionOrRegistrantToCopy != address(0)) {
                        operatorFilterRegistry.registerAndCopyEntries(address(this), subscriptionOrRegistrantToCopy);
                    } else {
                        operatorFilterRegistry.register(address(this));
                    }
                }
            }
        }
    }

    modifier onlyAllowedOperator(address from, uint256 id) virtual {
        // Check registry code length to facilitate testing in environments without a deployed registry.
        if (address(operatorFilterRegistry).code.length > 0) {
            _checkOperator(from);
        }
        _;
    }

    modifier onlyAllowedOperatorBatch(address from, uint256[] memory ids) virtual {
        // Check registry code length to facilitate testing in environments without a deployed registry.
        if (address(operatorFilterRegistry).code.length > 0) {
            uint256 idsLength = ids.length;
            unchecked {
                for (uint256 i = 0; i < idsLength; ++i) {
                    _checkOperator(from);
                }
            }
        }
        _;
    }

    function _checkOperator(address from) internal view {
        // Allow spending tokens from addresses with balance
        // Note that this still allows listings and marketplaces with escrow to transfer tokens if transferred
        // from an EOA.
        if (from == msg.sender) {
            return;
        }
        if (
            !(
                operatorFilterRegistry.isOperatorAllowed(address(this), msg.sender)
                    && operatorFilterRegistry.isOperatorAllowed(address(this), from)
            )
        ) {
            revert OperatorNotAllowed(msg.sender);
        }
    }
}
