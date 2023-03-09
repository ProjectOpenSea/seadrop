// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721SeaDropCloneable} from "./ERC721SeaDropCloneable.sol";
import {Clones} from "openzeppelin-contracts/proxy/Clones.sol";

contract ERC721SeaDropCloneFactory {
    address public immutable seaDropCloneableUpgradeableImplementation;
    address public constant DEFAULT_SEADROP = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;

    constructor() {
        ERC721SeaDropCloneable impl = new ERC721SeaDropCloneable();
        impl.initialize("", "", new address[](0), address(this));
        seaDropCloneableUpgradeableImplementation = address(impl);
    }

    function createClone(string memory name, string memory symbol) external returns (address) {
        address instance = Clones.clone(seaDropCloneableUpgradeableImplementation);
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = DEFAULT_SEADROP;
        ERC721SeaDropCloneable(instance).initialize(name, symbol, allowedSeaDrop, msg.sender);
        return instance;
    }
}
