// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;
import { ReentrancyGuardStorage } from "./ReentrancyGuardStorage.sol";
import "../../../../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuardUpgradeable is Initializable {
    using ReentrancyGuardStorage for ReentrancyGuardStorage.Layout;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        ReentrancyGuardStorage.layout().locked = 1;
    }

    modifier nonReentrant() virtual {
        require(ReentrancyGuardStorage.layout().locked == 1, "REENTRANCY");

        ReentrancyGuardStorage.layout().locked = 2;

        _;

        ReentrancyGuardStorage.layout().locked = 1;
    }
}
