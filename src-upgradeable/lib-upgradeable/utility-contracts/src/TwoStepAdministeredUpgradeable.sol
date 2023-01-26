// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { TwoStepOwnableUpgradeable } from "./TwoStepOwnableUpgradeable.sol";
import { TwoStepAdministeredStorage } from "./TwoStepAdministeredStorage.sol";
import "../../../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

contract TwoStepAdministeredUpgradeable is
    Initializable,
    TwoStepOwnableUpgradeable
{
    using TwoStepAdministeredStorage for TwoStepAdministeredStorage.Layout;
    event AdministratorUpdated(
        address indexed previousAdministrator,
        address indexed newAdministrator
    );
    event PotentialAdministratorUpdated(address newPotentialAdministrator);

    error OnlyAdministrator();
    error OnlyOwnerOrAdministrator();
    error NotNextAdministrator();
    error NewAdministratorIsZeroAddress();

    modifier onlyAdministrator() virtual {
        if (msg.sender != TwoStepAdministeredStorage.layout().administrator) {
            revert OnlyAdministrator();
        }

        _;
    }

    modifier onlyOwnerOrAdministrator() virtual {
        if (msg.sender != owner()) {
            if (
                msg.sender != TwoStepAdministeredStorage.layout().administrator
            ) {
                revert OnlyOwnerOrAdministrator();
            }
        }
        _;
    }

    function __TwoStepAdministered_init(
        address _administrator
    ) internal onlyInitializing {
        __ConstructorInitializable_init_unchained();
        __TwoStepOwnable_init_unchained();
        __TwoStepAdministered_init_unchained(_administrator);
    }

    function __TwoStepAdministered_init_unchained(
        address _administrator
    ) internal onlyInitializing {
        _initialize(_administrator);
    }

    function _initialize(address _administrator) private onlyConstructor {
        TwoStepAdministeredStorage.layout().administrator = _administrator;
        emit AdministratorUpdated(address(0), _administrator);
    }

    function transferAdministration(
        address newAdministrator
    ) public virtual onlyAdministrator {
        if (newAdministrator == address(0)) {
            revert NewAdministratorIsZeroAddress();
        }
        TwoStepAdministeredStorage
            .layout()
            .potentialAdministrator = newAdministrator;
        emit PotentialAdministratorUpdated(newAdministrator);
    }

    function _transferAdministration(
        address newAdministrator
    ) internal virtual {
        TwoStepAdministeredStorage.layout().administrator = newAdministrator;

        emit AdministratorUpdated(msg.sender, newAdministrator);
    }

    ///@notice Acept administration of smart contract, after the current administrator has initiated the process with transferAdministration
    function acceptAdministration() public virtual {
        address _potentialAdministrator = TwoStepAdministeredStorage
            .layout()
            .potentialAdministrator;
        if (msg.sender != _potentialAdministrator) {
            revert NotNextAdministrator();
        }
        _transferAdministration(_potentialAdministrator);
        delete TwoStepAdministeredStorage.layout().potentialAdministrator;
    }

    ///@notice cancel administration transfer
    function cancelAdministrationTransfer() public virtual onlyAdministrator {
        delete TwoStepAdministeredStorage.layout().potentialAdministrator;
        emit PotentialAdministratorUpdated(address(0));
    }

    function renounceAdministration() public virtual onlyAdministrator {
        delete TwoStepAdministeredStorage.layout().administrator;
        emit AdministratorUpdated(msg.sender, address(0));
    }

    // generated getter for ${varDecl.name}
    function administrator() public view returns (address) {
        return TwoStepAdministeredStorage.layout().administrator;
    }

    // generated getter for ${varDecl.name}
    function potentialAdministrator() public view returns (address) {
        return TwoStepAdministeredStorage.layout().potentialAdministrator;
    }
}
