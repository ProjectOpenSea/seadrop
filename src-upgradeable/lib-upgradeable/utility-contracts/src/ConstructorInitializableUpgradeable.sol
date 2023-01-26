// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;
import "../../../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/**
 * @author emo.eth
 * @notice Abstract smart contract that provides an onlyUninitialized modifier which only allows calling when
 *         from within a constructor of some sort, whether directly instantiating an inherting contract,
 *         or when delegatecalling from a proxy
 */
abstract contract ConstructorInitializableUpgradeable is Initializable {
    function __ConstructorInitializable_init() internal onlyInitializing {
        __ConstructorInitializable_init_unchained();
    }

    function __ConstructorInitializable_init_unchained()
        internal
        onlyInitializing
    {}

    error AlreadyInitialized();

    modifier onlyConstructor() {
        if (address(this).code.length != 0) {
            revert AlreadyInitialized();
        }
        _;
    }
}
