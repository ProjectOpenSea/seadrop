// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721ContractMetadataTest
} from "test/foundry/ERC721ContractMetadata.t.sol";

import { ERC721SeaDropAdminTest } from "test/foundry/ERC721SeaDropAdmin.t.sol";

import {
    ERC721SeaDropRandomOffsetTest
} from "test/foundry/ERC721SeaDropRandomOffset.t.sol";

import {
    ERC721TransferValidatorTest
} from "test/foundry/ERC721TransferValidator.t.sol";

import { TestSeaDrop } from "test/foundry/SeaDrop.t.sol";

import {
    ERC721DropTest as MintAllowedTokenHolderTest,
    SeaDropMintAllowedTokenHolderScenarioTest
} from "test/foundry/SeaDrop-mintAllowedTokenHolder.t.sol";

import {
    ERC721DropTest as MintAllowListTest,
    SeaDropMintAllowListScenarioTest
} from "test/foundry/SeaDrop-mintAllowList.t.sol";

import {
    ERC721SeaDropMintPublicTest,
    SeaDropMintPublicScenarioTest
} from "test/foundry/SeaDrop-mintPublic.t.sol";

import {
    SeaDropMintSignedTest,
    SeaDropMintSignedScenarioTest
} from "test/foundry/SeaDrop-mintSigned.t.sol";

// Each contract below reruns a shared test contract against the upgradeable
// token: ERC721SeaDropUpgradeable (or ERC721SeaDropRandomOffsetUpgradeable)
// behind a transparent proxy, deployed by TestHelper._deployUpgradeable.

contract ERC721ContractMetadataUpgradeableTest is ERC721ContractMetadataTest {
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract ERC721SeaDropUpgradeableAdminTest is ERC721SeaDropAdminTest {
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract ERC721SeaDropRandomOffsetUpgradeableTest is
    ERC721SeaDropRandomOffsetTest
{
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract ERC721TransferValidatorUpgradeableTest is ERC721TransferValidatorTest {
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract SeaDropUpgradeableTokenTest is TestSeaDrop {
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract MintAllowedTokenHolderUpgradeableTest is MintAllowedTokenHolderTest {
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract SeaDropMintAllowedTokenHolderUpgradeableScenarioTest is
    SeaDropMintAllowedTokenHolderScenarioTest
{
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract MintAllowListUpgradeableTest is MintAllowListTest {
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract SeaDropMintAllowListUpgradeableScenarioTest is
    SeaDropMintAllowListScenarioTest
{
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract ERC721SeaDropUpgradeableMintPublicTest is ERC721SeaDropMintPublicTest {
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract SeaDropMintPublicUpgradeableScenarioTest is
    SeaDropMintPublicScenarioTest
{
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract SeaDropMintSignedUpgradeableTest is SeaDropMintSignedTest {
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}

contract SeaDropMintSignedUpgradeableScenarioTest is
    SeaDropMintSignedScenarioTest
{
    function _upgradeable() internal pure override returns (bool) {
        return true;
    }
}
