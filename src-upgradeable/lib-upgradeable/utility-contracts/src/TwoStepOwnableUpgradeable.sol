// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {
    ConstructorInitializableUpgradeable
} from "./ConstructorInitializableUpgradeable.sol";
import { TwoStepOwnableStorage } from "./TwoStepOwnableStorage.sol";
import "../../../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/**
@notice A two-step extension of Ownable, where the new owner must claim ownership of the contract after owner initiates transfer
Owner can cancel the transfer at any point before the new owner claims ownership.
Helpful in guarding against transferring ownership to an address that is unable to act as the Owner.
*/
abstract contract TwoStepOwnableUpgradeable is
    Initializable,
    ConstructorInitializableUpgradeable
{
    using TwoStepOwnableStorage for TwoStepOwnableStorage.Layout;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event PotentialOwnerUpdated(address newPotentialAdministrator);

    error NewOwnerIsZeroAddress();
    error NotNextOwner();
    error OnlyOwner();

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function __TwoStepOwnable_init() internal onlyInitializing {
        __ConstructorInitializable_init_unchained();
        __TwoStepOwnable_init_unchained();
    }

    function __TwoStepOwnable_init_unchained() internal onlyInitializing {
        _initialize();
    }

    function _initialize() private onlyConstructor {
        _transferOwnership(msg.sender);
    }

    ///@notice Initiate ownership transfer to newPotentialOwner. Note: new owner will have to manually acceptOwnership
    ///@param newPotentialOwner address of potential new owner
    function transferOwnership(
        address newPotentialOwner
    ) public virtual onlyOwner {
        if (newPotentialOwner == address(0)) {
            revert NewOwnerIsZeroAddress();
        }
        TwoStepOwnableStorage.layout().potentialOwner = newPotentialOwner;
        emit PotentialOwnerUpdated(newPotentialOwner);
    }

    ///@notice Claim ownership of smart contract, after the current owner has initiated the process with transferOwnership
    function acceptOwnership() public virtual {
        address _potentialOwner = TwoStepOwnableStorage.layout().potentialOwner;
        if (msg.sender != _potentialOwner) {
            revert NotNextOwner();
        }
        delete TwoStepOwnableStorage.layout().potentialOwner;
        emit PotentialOwnerUpdated(address(0));
        _transferOwnership(_potentialOwner);
    }

    ///@notice cancel ownership transfer
    function cancelOwnershipTransfer() public virtual onlyOwner {
        delete TwoStepOwnableStorage.layout().potentialOwner;
        emit PotentialOwnerUpdated(address(0));
    }

    function owner() public view virtual returns (address) {
        return TwoStepOwnableStorage.layout()._owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (TwoStepOwnableStorage.layout()._owner != msg.sender) {
            revert OnlyOwner();
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = TwoStepOwnableStorage.layout()._owner;
        TwoStepOwnableStorage.layout()._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
