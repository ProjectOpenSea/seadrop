// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import {
    ERC721SeaDropUpgradeable
} from "seadrop/upgradeable/ERC721SeaDropUpgradeable.sol";

import {
    ERC721SeaDropRandomOffsetUpgradeable
} from "seadrop/upgradeable/extensions/ERC721SeaDropRandomOffsetUpgradeable.sol";

import { ExampleToken } from "seadrop/upgradeable/ExampleToken.sol";

import {
    ConstructorInitializableUpgradeable
} from "seadrop/upgradeable/vendored/utility-contracts/ConstructorInitializableUpgradeable.sol";

import {
    TwoStepOwnableUpgradeable
} from "seadrop/upgradeable/vendored/utility-contracts/TwoStepOwnableUpgradeable.sol";

import {
    ISeaDropTokenContractMetadata
} from "seadrop/interfaces/ISeaDropTokenContractMetadata.sol";

import { IERC721A } from "ERC721A/IERC721A.sol";

import {
    ProxyAdmin
} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";

import {
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @dev Initializes through __ERC721SeaDropRandomOffset_init, the way a
///      contract extending ERC721SeaDropRandomOffsetUpgradeable would.
contract RandomOffsetInitializer is ERC721SeaDropRandomOffsetUpgradeable {
    function initializeRandomOffset(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) external initializer initializerERC721A {
        __ERC721SeaDropRandomOffset_init(name, symbol, allowedSeaDrop);
    }
}

/**
 * @notice Tests specific to the upgradeable tokens: initialization, the
 *         storage layout that deployed proxies depend on, and ExampleToken.
 *         The behavior they share with ERC721SeaDrop runs in SharedTests.t.sol.
 *
 *         This file compiles with the upgradeable settings, so it imports
 *         no regular SeaDrop contract (not even through TestHelper): that
 *         would compile those under both profiles, and forge verify-contract
 *         would then need --compilation-profile for them.
 */
contract ERC721SeaDropUpgradeableTest is Test {
    // The diamond storage slots. Deployed proxies hold their state at these
    // slots, so the strings must never change, "openzepplin" spelling
    // included.
    bytes32 internal constant CONTRACT_METADATA_SLOT =
        keccak256("openzepplin.contracts.storage.ERC721ContractMetadata");
    bytes32 internal constant SEADROP_SLOT =
        keccak256("openzepplin.contracts.storage.ERC721SeaDrop");
    bytes32 internal constant RANDOM_OFFSET_SLOT =
        keccak256("openzepplin.contracts.storage.ERC721SeaDropRandomOffset");
    bytes32 internal constant REENTRANCY_GUARD_SLOT =
        keccak256("openzepplin.contracts.storage.ReentrancyGuard");
    bytes32 internal constant TWO_STEP_OWNABLE_SLOT =
        keccak256("openzepplin.contracts.storage.TwoStepOwnable");
    bytes32 internal constant EXAMPLE_TOKEN_SLOT =
        keccak256("seaDrop.contracts.storage.exampleToken");
    bytes32 internal constant ERC721A_SLOT =
        keccak256("ERC721A.contracts.storage.ERC721A");
    bytes32 internal constant ERC721A_INITIALIZABLE_SLOT =
        keccak256("ERC721A.contracts.storage.initializable.facet");

    /// @dev Stands in for SeaDrop, which only needs to be allowed to mint.
    address seadrop = makeAddr("seadrop");
    address minter = makeAddr("minter");

    ERC721SeaDropUpgradeable token;

    function setUp() public {
        token = ERC721SeaDropUpgradeable(
            _deployProxy(
                address(new ERC721SeaDropUpgradeable()), "Name", "SYMBOL"
            )
        );
    }

    function _allowedSeaDrop() internal view returns (address[] memory) {
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = seadrop;
        return allowedSeaDrop;
    }

    /// @dev A transparent proxy for `implementation` whose constructor
    ///      initializes it, making this contract the token owner.
    function _deployProxy(
        address implementation,
        string memory name,
        string memory symbol
    ) internal returns (address) {
        return address(
            new TransparentUpgradeableProxy(
                implementation,
                address(new ProxyAdmin()),
                abi.encodeCall(
                    ERC721SeaDropUpgradeable.initialize,
                    (name, symbol, _allowedSeaDrop())
                )
            )
        );
    }

    /// @dev The storage word of `slot` plus `offset`.
    function _load(bytes32 slot, uint256 offset)
        internal
        view
        returns (bytes32)
    {
        return vm.load(address(token), bytes32(uint256(slot) + offset));
    }

    /// @dev How Solidity stores a string shorter than 32 bytes in one word.
    function _shortString(string memory value) internal pure returns (bytes32) {
        return bytes32(bytes(value)) | bytes32(bytes(value).length * 2);
    }

    function _word(address value) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }

    function testInitialize_onlyOnce() public {
        assertEq(token.owner(), address(this));
        assertEq(token.name(), "Name");
        assertEq(token.symbol(), "SYMBOL");

        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize("", "", new address[](0));
    }

    /// @dev initialize() only works in a constructor context: the proxy's.
    ///      So nobody can initialize the implementation itself, or a proxy
    ///      deployed without the initialize call.
    function testInitialize_onlyInConstructor() public {
        ERC721SeaDropUpgradeable implementation = new ERC721SeaDropUpgradeable();
        vm.expectRevert(
            ConstructorInitializableUpgradeable.AlreadyInitialized.selector
        );
        implementation.initialize("", "", _allowedSeaDrop());

        ERC721SeaDropUpgradeable uninitialized = ERC721SeaDropUpgradeable(
            address(
                new TransparentUpgradeableProxy(
                    address(implementation), address(new ProxyAdmin()), ""
                )
            )
        );
        vm.expectRevert(
            ConstructorInitializableUpgradeable.AlreadyInitialized.selector
        );
        uninitialized.initialize("", "", _allowedSeaDrop());
        assertEq(uninitialized.owner(), address(0));
    }

    /// @dev __ERC721SeaDropRandomOffset_init initializes the whole
    ///      ERC721SeaDropUpgradeable chain. It used to run only
    ///      __ERC721SeaDrop_init_unchained, which left the token without a
    ///      name, symbol, or owner, and with its reentrancy lock at 0, so
    ///      every mint reverted.
    function testRandomOffsetInit_initializesParents() public {
        RandomOffsetInitializer randomOffsetToken = RandomOffsetInitializer(
            address(
                new TransparentUpgradeableProxy(
                    address(new RandomOffsetInitializer()),
                    address(new ProxyAdmin()),
                    abi.encodeCall(
                        RandomOffsetInitializer.initializeRandomOffset,
                        ("Name", "SYMBOL", _allowedSeaDrop())
                    )
                )
            )
        );

        assertEq(randomOffsetToken.owner(), address(this));
        assertEq(randomOffsetToken.name(), "Name");
        assertEq(randomOffsetToken.symbol(), "SYMBOL");

        randomOffsetToken.setMaxSupply(1);
        vm.prank(seadrop);
        randomOffsetToken.mintSeaDrop(minter, 1);
        assertEq(randomOffsetToken.ownerOf(1), minter);
    }

    /// @dev Pin every field of the upgradeable storage layout to the slot
    ///      deployed proxies already use, by writing through the token and
    ///      reading the raw storage.
    function testStorageLayout() public {
        address royaltyAddress = makeAddr("royaltyAddress");
        address validator = makeAddr("validator");
        address newOwner = makeAddr("newOwner");
        bytes32 provenanceHash = keccak256("provenance");

        // OpenZeppelin's Initializable, in slot 0 of the proxy:
        // _initialized = 1, _initializing = false.
        assertEq(vm.load(address(token), bytes32(0)), bytes32(uint256(1)));

        // ERC721A's initializable facet: _initialized = true.
        assertEq(_load(ERC721A_INITIALIZABLE_SLOT, 0), bytes32(uint256(1)));

        // ReentrancyGuard: locked = 1 (unlocked).
        assertEq(_load(REENTRANCY_GUARD_SLOT, 0), bytes32(uint256(1)));

        token.setProvenanceHash(provenanceHash);
        token.setMaxSupply(100);
        token.setBaseURI("https://example.com/");
        token.setContractURI("https://example.com/contract");
        token.setRoyaltyInfo(
            ISeaDropTokenContractMetadata.RoyaltyInfo(royaltyAddress, 500)
        );
        token.setTransferValidator(validator);
        token.transferOwnership(newOwner);
        vm.prank(seadrop);
        token.mintSeaDrop(minter, 3);

        // ERC721ContractMetadata.
        assertEq(_load(CONTRACT_METADATA_SLOT, 0), bytes32(uint256(100)));
        assertEq(
            _load(CONTRACT_METADATA_SLOT, 1),
            _shortString("https://example.com/")
        );
        assertEq(
            _load(CONTRACT_METADATA_SLOT, 2),
            _shortString("https://example.com/contract")
        );
        assertEq(_load(CONTRACT_METADATA_SLOT, 3), provenanceHash);
        assertEq(
            _load(CONTRACT_METADATA_SLOT, 4),
            _word(royaltyAddress) | bytes32(uint256(500) << 160)
        );
        assertEq(_load(CONTRACT_METADATA_SLOT, 5), _word(validator));

        // ERC721SeaDrop: the _allowedSeaDrop mapping, then the
        // _enumeratedAllowedSeaDrop array.
        assertEq(
            vm.load(
                address(token), keccak256(abi.encode(seadrop, SEADROP_SLOT))
            ),
            bytes32(uint256(1))
        );
        assertEq(_load(SEADROP_SLOT, 1), bytes32(uint256(1)));
        assertEq(
            vm.load(
                address(token), keccak256(abi.encode(uint256(SEADROP_SLOT) + 1))
            ),
            _word(seadrop)
        );

        // TwoStepOwnable: _owner, then potentialOwner.
        assertEq(_load(TWO_STEP_OWNABLE_SLOT, 0), _word(address(this)));
        assertEq(_load(TWO_STEP_OWNABLE_SLOT, 1), _word(newOwner));

        // ERC721A: _currentIndex (the next token id), _burnCounter, _name,
        // _symbol.
        assertEq(_load(ERC721A_SLOT, 0), bytes32(uint256(4)));
        assertEq(_load(ERC721A_SLOT, 1), bytes32(0));
        assertEq(_load(ERC721A_SLOT, 2), _shortString("Name"));
        assertEq(_load(ERC721A_SLOT, 3), _shortString("SYMBOL"));
    }

    function testStorageLayout_randomOffset() public {
        ERC721SeaDropRandomOffsetUpgradeable offsetToken =
            ERC721SeaDropRandomOffsetUpgradeable(
                _deployProxy(
                    address(new ERC721SeaDropRandomOffsetUpgradeable()), "", ""
                )
            );
        offsetToken.setMaxSupply(10);
        vm.prank(seadrop);
        offsetToken.mintSeaDrop(minter, 10);
        offsetToken.setRandomOffset();
        assertTrue(offsetToken.revealed());

        // randomOffset, then revealed.
        assertEq(
            vm.load(address(offsetToken), RANDOM_OFFSET_SLOT),
            bytes32(offsetToken.randomOffset())
        );
        assertEq(
            vm.load(
                address(offsetToken), bytes32(uint256(RANDOM_OFFSET_SLOT) + 1)
            ),
            bytes32(uint256(1))
        );
    }

    function testExampleToken_onlyBurnAddressCanBurn() public {
        ExampleToken example =
            ExampleToken(_deployProxy(address(new ExampleToken()), "", ""));
        address burnAddress = makeAddr("burnAddress");

        example.setMaxSupply(2);
        vm.prank(seadrop);
        example.mintSeaDrop(minter, 2);

        vm.prank(minter);
        vm.expectRevert(TwoStepOwnableUpgradeable.OnlyOwner.selector);
        example.setBurnAddress(burnAddress);

        example.setBurnAddress(burnAddress);
        assertEq(example.getBurnAddress(), burnAddress);
        assertEq(
            vm.load(address(example), EXAMPLE_TOKEN_SLOT), _word(burnAddress)
        );

        // Not even the token's holder can burn it.
        vm.prank(minter);
        vm.expectRevert(ExampleToken.BurnIncorrectSender.selector);
        example.burn(1);

        // The burn address can, without an approval.
        vm.prank(burnAddress);
        example.burn(1);
        assertEq(example.totalSupply(), 1);
        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        example.ownerOf(1);
    }
}
