// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropV3TestHelper } from "./utils/SeaDropV3TestHelper.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { SeaDropTokenV3Base } from "seadrop/v3/SeaDropTokenV3Base.sol";

import { ERC721SeaDropV3 } from "seadrop/v3/ERC721SeaDropV3.sol";

import { ERC1155SeaDropV3 } from "seadrop/v3/ERC1155SeaDropV3.sol";

import { SeaDropTokenFactory } from "seadrop/v3/SeaDropTokenFactory.sol";

import { Clones } from "openzeppelin-contracts/proxy/Clones.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

import {
    ConstructorInitializable
} from "utility-contracts/ConstructorInitializable.sol";

contract SeaDropTokenFactoryTest is SeaDropV3TestHelper {
    event TokenCreated(
        address indexed token,
        address indexed implementation,
        address indexed creator,
        bytes32 salt
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event AllowedMinterUpdated(address indexed minter, bool allowed);

    bytes32 internal constant SALT = bytes32(uint256(1));

    /// @dev ERC721A-Upgradeable 4.2.2's diamond storage slot.
    bytes32 internal constant ERC721A_SLOT =
        keccak256("ERC721A.contracts.storage.ERC721A");

    // ---------------------------------------------------------------------
    // Factory and implementations
    // ---------------------------------------------------------------------

    function test_factoryDeploysImplementationsWithItsConduit() public view {
        assertEq(factory.minter(), address(minter));
        assertEq(factory.conduit(), CONDUIT);

        ERC721SeaDropV3 impl721 =
            ERC721SeaDropV3(factory.erc721Implementation());
        ERC1155SeaDropV3 impl1155 =
            ERC1155SeaDropV3(factory.erc1155Implementation());
        assertEq(impl721.preapprovedConduit(), CONDUIT);
        assertEq(impl1155.preapprovedConduit(), CONDUIT);
        assertEq(impl721.factory(), address(factory));
        assertEq(impl1155.factory(), address(factory));
        // The implementations have no owner and allow no minter.
        assertEq(impl721.owner(), address(0));
        assertEq(impl1155.owner(), address(0));
        assertFalse(impl721.allowedMinters(address(minter)));
        assertFalse(impl1155.allowedMinters(address(minter)));
    }

    function test_revert_factoryMinterIsZeroAddress() public {
        vm.expectRevert(SeaDropTokenFactory.MinterIsZeroAddress.selector);
        new SeaDropTokenFactory(address(0), CONDUIT);
    }

    function test_revert_implementationsCantBeInitialized() public {
        ERC721SeaDropV3 impl721 =
            ERC721SeaDropV3(factory.erc721Implementation());
        ERC1155SeaDropV3 impl1155 =
            ERC1155SeaDropV3(factory.erc1155Implementation());

        // Not even by the factory.
        vm.startPrank(address(factory));
        vm.expectRevert(ConstructorInitializable.AlreadyInitialized.selector);
        impl721.initialize(alice, address(minter), "X", "X");
        vm.expectRevert(ConstructorInitializable.AlreadyInitialized.selector);
        impl1155.initialize(alice, address(minter));
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.OnlyFactory.selector, alice
            )
        );
        impl721.initialize(alice, alice, "X", "X");
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.OnlyFactory.selector, alice
            )
        );
        impl1155.initialize(alice, alice);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // Clone initialization
    // ---------------------------------------------------------------------

    function test_createERC721_initializesAndRegisters() public {
        address predicted = factory.predictERC721Address(alice, SALT);

        vm.expectEmit(predicted);
        emit OwnershipTransferred(address(0), alice);
        vm.expectEmit(predicted);
        emit AllowedMinterUpdated(address(minter), true);
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.TokenRegistered(
            minter.CONFIG_EVENT_VERSION(),
            predicted,
            address(factory)
        );
        vm.expectEmit(address(factory));
        emit TokenCreated(
            predicted,
            factory.erc721Implementation(),
            alice,
            SALT
        );
        vm.prank(alice);
        address token = factory.createERC721("Name", "SYM", SALT);

        assertEq(token, predicted);
        _assertCloneOf(token, factory.erc721Implementation());
        ERC721SeaDropV3 clone = ERC721SeaDropV3(token);
        assertEq(clone.name(), "Name");
        assertEq(clone.symbol(), "SYM");
        assertEq(clone.owner(), alice);
        assertEq(clone.factory(), address(factory));
        assertEq(clone.preapprovedConduit(), CONDUIT);
        assertTrue(clone.allowedMinters(address(minter)));
        assertEq(clone.totalSupply(), 0);
        assertEq(clone.maxSupply(), 0);
        assertEq(minter.tokenFactoryOf(token), address(factory));

        // The clone mints through the minter, from token id 1.
        vm.prank(alice);
        clone.setMaxSupply(10);
        vm.prank(alice);
        minter.ownerMint(token, 0, bob, 2);
        assertEq(clone.ownerOf(1), bob);
        assertEq(clone.ownerOf(2), bob);
    }

    function test_createERC1155_initializesAndRegisters() public {
        address predicted = factory.predictERC1155Address(alice, SALT);

        vm.expectEmit(predicted);
        emit OwnershipTransferred(address(0), alice);
        vm.expectEmit(predicted);
        emit AllowedMinterUpdated(address(minter), true);
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.TokenRegistered(
            minter.CONFIG_EVENT_VERSION(),
            predicted,
            address(factory)
        );
        vm.expectEmit(address(factory));
        emit TokenCreated(
            predicted,
            factory.erc1155Implementation(),
            alice,
            SALT
        );
        vm.prank(alice);
        address token = factory.createERC1155(SALT);

        assertEq(token, predicted);
        _assertCloneOf(token, factory.erc1155Implementation());
        ERC1155SeaDropV3 clone = ERC1155SeaDropV3(token);
        assertEq(clone.owner(), alice);
        assertEq(clone.preapprovedConduit(), CONDUIT);
        assertTrue(clone.allowedMinters(address(minter)));
        assertEq(clone.uri(1), "");
        assertEq(minter.tokenFactoryOf(token), address(factory));

        vm.startPrank(alice);
        clone.setMaxSupply(3, 10);
        minter.ownerMint(token, 3, bob, 4);
        vm.stopPrank();
        assertEq(clone.balanceOf(bob, 3), 4);
    }

    function test_revert_cloneCantBeInitializedTwice() public {
        vm.startPrank(address(factory));
        // ERC721A-Upgradeable's own guard runs first on the ERC-721.
        vm.expectRevert(
            bytes("ERC721A__Initializable: contract is already initialized")
        );
        token721.initialize(alice, alice, "X", "X");
        vm.expectRevert(ConstructorInitializable.AlreadyInitialized.selector);
        token1155.initialize(alice, alice);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(
            bytes("ERC721A__Initializable: contract is already initialized")
        );
        token721.initialize(alice, alice, "X", "X");
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.OnlyFactory.selector, alice
            )
        );
        token1155.initialize(alice, alice);

        assertEq(token721.owner(), address(this));
        assertEq(token1155.owner(), address(this));
        assertFalse(token721.allowedMinters(alice));
    }

    /// @dev A clone of the implementation made outside the factory can't be
    ///      initialized by anyone, so it has no owner and can't mint.
    function test_revert_cloneOutsideFactoryCantBeInitialized() public {
        address rogue721 = Clones.clone(factory.erc721Implementation());
        address rogue1155 = Clones.clone(factory.erc1155Implementation());

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.OnlyFactory.selector, alice
            )
        );
        ERC721SeaDropV3(rogue721).initialize(alice, alice, "X", "X");
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.OnlyFactory.selector, alice
            )
        );
        ERC1155SeaDropV3(rogue1155).initialize(alice, alice);
        vm.stopPrank();

        assertEq(ERC721SeaDropV3(rogue721).owner(), address(0));
        assertEq(minter.tokenFactoryOf(rogue721), address(0));
    }

    // ---------------------------------------------------------------------
    // Conduit
    // ---------------------------------------------------------------------

    /// @dev Clones of each factory preapprove that factory's conduit, and
    ///      creating a token takes no conduit argument.
    function test_conduitIsFixedByTheFactory() public {
        address otherConduit = makeAddr("otherConduit");
        SeaDropTokenFactory otherFactory =
            new SeaDropTokenFactory(address(minter), otherConduit);
        minter.setTokenFactory(address(otherFactory), true);

        vm.startPrank(alice);
        ERC721SeaDropV3 a =
            ERC721SeaDropV3(factory.createERC721("A", "A", SALT));
        ERC721SeaDropV3 b =
            ERC721SeaDropV3(otherFactory.createERC721("B", "B", SALT));
        ERC1155SeaDropV3 c = ERC1155SeaDropV3(otherFactory.createERC1155(SALT));
        vm.stopPrank();

        assertEq(a.preapprovedConduit(), CONDUIT);
        assertEq(b.preapprovedConduit(), otherConduit);
        assertEq(c.preapprovedConduit(), otherConduit);
        assertTrue(b.isApprovedForAll(bob, otherConduit));
        assertFalse(b.isApprovedForAll(bob, CONDUIT));

        // The conduit is in the implementation's bytecode, not in storage.
        // Writing every namespaced and sequential slot the token uses
        // wouldn't change it.
        assertEq(
            ERC721SeaDropV3(factory.erc721Implementation())
                .preapprovedConduit(),
            CONDUIT
        );
    }

    // ---------------------------------------------------------------------
    // Registration
    // ---------------------------------------------------------------------

    function test_setTokenFactory() public {
        address other = makeAddr("otherFactory");
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.TokenFactoryUpdated(
            minter.CONFIG_EVENT_VERSION(),
            other,
            true
        );
        minter.setTokenFactory(other, true);
        assertTrue(minter.tokenFactories(other));

        minter.setTokenFactory(other, false);
        assertFalse(minter.tokenFactories(other));
    }

    function test_revert_setTokenFactory_notAdmin() public {
        vm.prank(alice);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        minter.setTokenFactory(alice, true);
    }

    function test_revert_registerToken_notFactory() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.OnlyTokenFactory.selector, alice
            )
        );
        minter.registerToken(alice);
    }

    function test_revert_registerToken_twice() public {
        vm.prank(address(factory));
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.TokenAlreadyRegistered.selector,
                address(token721),
                address(factory)
            )
        );
        minter.registerToken(address(token721));
    }

    /// @dev A factory the admin disallowed can't create tokens, and the
    ///      tokens it registered stay registered and keep minting.
    function test_disallowedFactoryCantCreate() public {
        minter.setTokenFactory(address(factory), false);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.OnlyTokenFactory.selector, address(factory)
            )
        );
        factory.createERC721("X", "X", SALT);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.OnlyTokenFactory.selector, address(factory)
            )
        );
        factory.createERC1155(SALT);

        assertEq(minter.tokenFactoryOf(address(token721)), address(factory));
        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );
        assertEq(token721.ownerOf(1), alice);
    }

    // ---------------------------------------------------------------------
    // Deterministic addresses
    // ---------------------------------------------------------------------

    function test_addressesAreScopedToTheCreator() public {
        address aliceAddr = factory.predictERC721Address(alice, SALT);
        address bobAddr = factory.predictERC721Address(bob, SALT);
        assertTrue(aliceAddr != bobAddr);
        // The two standards don't share addresses for the same salt.
        assertTrue(aliceAddr != factory.predictERC1155Address(alice, SALT));

        // Bob using alice's salt gets his own address, not hers.
        vm.prank(bob);
        assertEq(factory.createERC721("B", "B", SALT), bobAddr);
        assertEq(aliceAddr.code.length, 0);

        vm.prank(alice);
        assertEq(factory.createERC721("A", "A", SALT), aliceAddr);
        assertEq(ERC721SeaDropV3(aliceAddr).owner(), alice);
        assertEq(ERC721SeaDropV3(bobAddr).owner(), bob);
    }

    function test_revert_reusedSalt() public {
        vm.startPrank(alice);
        factory.createERC721("A", "A", SALT);
        vm.expectRevert(bytes("ERC1167: create2 failed"));
        factory.createERC721("A", "A", SALT);
        factory.createERC1155(SALT);
        vm.expectRevert(bytes("ERC1167: create2 failed"));
        factory.createERC1155(SALT);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // Storage layout
    // ---------------------------------------------------------------------

    function test_namespaceSlotsMatchERC7201() public pure {
        assertEq(
            _erc7201("seadrop.v3.SeaDropTokenV3Base"),
            0x1cefbe2c3ccb7feb740a1ec48f16b0ca795114b40813c3af6640cac9f1a78d00
        );
        assertEq(
            _erc7201("seadrop.v3.ERC721SeaDropV3"),
            0xe88258efc68c2124d32107a295743c18ce3fcb3efcd888edc1efbbb996fd2f00
        );
        assertEq(
            _erc7201("seadrop.v3.ERC1155SeaDropV3"),
            0x2032b18d202658b0d56f376a10c2e031b632a48d257145366b93b7ac14da9d00
        );
    }

    /// @dev Reads the ERC-721 clone's state from the slots
    ///      docs/v3/AuditScope.md lists, so a layout change fails here.
    function test_ERC721_storageSlots() public {
        bytes32 base = _erc7201("seadrop.v3.SeaDropTokenV3Base");
        bytes32 own = _erc7201("seadrop.v3.ERC721SeaDropV3");
        address t = address(token721);

        token721.setContractURI("c");
        token721.transferOwnership(alice);
        vm.prank(alice);
        token721.setApprovalForAll(CONDUIT, false);
        minter.ownerMint(t, 0, bob, 3);

        // TwoStepOwnable: owner at 0, pending owner at 1.
        assertEq(_loadAddress(t, 0), address(this));
        assertEq(_loadAddress(t, bytes32(uint256(1))), alice);

        // Base namespace: initialized, allowedMinters, conduitRevoked,
        // contractURI.
        assertEq(uint256(vm.load(t, base)), 1);
        assertEq(uint256(vm.load(t, _mapSlot(address(minter), base, 1))), 1);
        assertEq(uint256(vm.load(t, _mapSlot(alice, base, 2))), 1);
        assertEq(vm.load(t, _add(base, 3)), _shortString("c"));

        // ERC-721 namespace: maxSupply, baseURI.
        assertEq(uint256(vm.load(t, own)), MAX_SUPPLY);
        token721.setBaseURI("b");
        assertEq(vm.load(t, _add(own, 1)), _shortString("b"));

        // ERC721A-Upgradeable's diamond storage: _currentIndex first.
        assertEq(uint256(vm.load(t, ERC721A_SLOT)), 4);

        // Nothing else in the low sequential slots.
        for (uint256 i = 2; i < 8; ++i) {
            assertEq(vm.load(t, bytes32(i)), bytes32(0));
        }
    }

    function test_ERC1155_storageSlots() public {
        bytes32 base = _erc7201("seadrop.v3.SeaDropTokenV3Base");
        bytes32 own = _erc7201("seadrop.v3.ERC1155SeaDropV3");
        address t = address(token1155);

        token1155.setURI("u");
        token1155.setContractURI("c");
        minter.ownerMint(t, ID_1155, bob, 3);

        // OpenZeppelin 4.9 ERC1155: _balances at 0, _operatorApprovals at
        // 1, and _uri at 2, which stays empty.
        bytes32 balanceSlot = keccak256(
            abi.encode(bob, keccak256(abi.encode(ID_1155, uint256(0))))
        );
        assertEq(uint256(vm.load(t, balanceSlot)), 3);
        assertEq(vm.load(t, bytes32(uint256(2))), bytes32(0));

        // TwoStepOwnable: owner at 3, pending owner at 4.
        assertEq(_loadAddress(t, bytes32(uint256(3))), address(this));

        // Base namespace.
        assertEq(uint256(vm.load(t, base)), 1);
        assertEq(uint256(vm.load(t, _mapSlot(address(minter), base, 1))), 1);
        assertEq(vm.load(t, _add(base, 3)), _shortString("c"));

        // ERC-1155 namespace: supply[id] packs totalMinted and maxSupply,
        // then uri.
        bytes32 supply = vm.load(t, keccak256(abi.encode(ID_1155, own)));
        assertEq(uint256(supply) & type(uint128).max, 3);
        assertEq(uint256(supply) >> 128, MAX_SUPPLY);
        assertEq(vm.load(t, _add(own, 1)), _shortString("u"));
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _assertCloneOf(address clone, address implementation)
        internal
        view
    {
        assertEq(
            clone.code,
            abi.encodePacked(
                hex"363d3d373d3d3d363d73",
                implementation,
                hex"5af43d82803e903d91602b57fd5bf3"
            )
        );
    }

    function _erc7201(string memory id) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1))
            & ~bytes32(uint256(0xff));
    }

    function _add(bytes32 slot, uint256 offset)
        internal
        pure
        returns (bytes32)
    {
        return bytes32(uint256(slot) + offset);
    }

    function _mapSlot(address key, bytes32 base, uint256 offset)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(key, _add(base, offset)));
    }

    function _loadAddress(address t, bytes32 slot)
        internal
        view
        returns (address)
    {
        return address(uint160(uint256(vm.load(t, slot))));
    }

    /// @dev Solidity's in-place encoding of a string under 32 bytes.
    function _shortString(string memory s) internal pure returns (bytes32) {
        return bytes32(bytes(s)) | bytes32(bytes(s).length * 2);
    }
}
