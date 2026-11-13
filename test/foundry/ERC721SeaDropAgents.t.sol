// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { Vm } from "forge-std/Vm.sol";

import {
    ERC721SeaDropAgents
} from "seadrop/extensions/ERC721SeaDropAgents.sol";

import { ERC8048OnchainMetadata } from "seadrop/lib/ERC8048OnchainMetadata.sol";

import { IERC8048Metadata } from "seadrop/interfaces/IERC8048Metadata.sol";

import { MetadataWriterPolicy } from "seadrop/lib/MetadataWriterPolicy.sol";

import { MockAgentAdapter } from "seadrop/test/MockAgentAdapter.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

import { ERC721 } from "openzeppelin-contracts/token/ERC721/ERC721.sol";

import {
    ERC721URIStorage
} from "openzeppelin-contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract ERC721SeaDropAgentsWithMint is ERC721SeaDropAgents {
    constructor(address[] memory allowedSeaDrop, address adapter)
        ERC721SeaDropAgents("Agents", "AGENT", allowedSeaDrop, adapter)
    { }

    function mint(address to, uint256 quantity) public onlyOwner {
        _mint(to, quantity);
    }
}

/// @dev The parts of the deployed ERC-8217 adapter the fork test reads.
interface IAgentAdapterView {
    struct Binding {
        uint8 standard;
        address boundAddress;
        uint256 tokenId;
    }

    function bindingOf(uint256 agentId) external view returns (Binding memory);

    function isController(uint256 agentId, address account)
        external
        view
        returns (bool);

    function tokenURI(uint256 agentId) external view returns (string memory);
}

/// @dev ERC8048OnchainMetadata next to OpenZeppelin's ERC721URIStorage,
///      which declares ERC-4906's events itself.
contract URIStorageWithOnchainMetadata is
    ERC721URIStorage,
    ERC8048OnchainMetadata
{
    address internal immutable _ADMIN = msg.sender;

    constructor() ERC721("Reuse", "REUSE") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IERC8048Metadata).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function _isMetadataAdmin(address account)
        internal
        view
        override
        returns (bool)
    {
        return account == _ADMIN;
    }

    function _metadataHolderOf(uint256 tokenId)
        internal
        view
        override
        returns (address)
    {
        return _ownerOf(tokenId);
    }

    function _emitMetadataUpdate(uint256 tokenId) internal override {
        if (_exists(tokenId)) {
            emit MetadataUpdate(tokenId);
        }
    }
}

contract ERC721SeaDropAgentsTest is TestHelper {
    bytes32 constant METADATA_SET =
        keccak256("MetadataSet(uint256,string,string,bytes)");
    bytes32 constant METADATA_UPDATE = keccak256("MetadataUpdate(uint256)");
    bytes32 constant COLLECTION_AUTHORITY_UPDATED =
        keccak256("CollectionAuthorityUpdated(address,bool,bool)");

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    MockAgentAdapter adapter;
    ERC721SeaDropAgentsWithMint agents;

    address holder = makeAddr("holder");
    address otherHolder = makeAddr("otherHolder");
    address writer = makeAddr("writer");
    address agentWallet = makeAddr("agentWallet");
    address stranger = makeAddr("stranger");
    address policyAdmin = makeAddr("policyAdmin");

    function setUp() public {
        adapter = new MockAgentAdapter();
        agents = _deploy(address(adapter));
        agents.setMaxSupply(100);
    }

    function _deploy(address adapter_)
        internal
        returns (ERC721SeaDropAgentsWithMint)
    {
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        return new ERC721SeaDropAgentsWithMint(allowedSeaDrop, adapter_);
    }

    /// @dev Deploys a MetadataWriterPolicy for `agents` that `policyAdmin`
    ///      runs.
    function _deployPolicy() internal returns (MetadataWriterPolicy policy) {
        vm.prank(policyAdmin);
        policy = new MetadataWriterPolicy(address(agents));
    }

    function _writeUnauthorized(uint256 tokenId)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            ERC8048OnchainMetadata.MetadataWriteUnauthorized.selector, tokenId
        );
    }

    function _policyWriteUnauthorized(uint256 tokenId)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            MetadataWriterPolicy.WriteUnauthorized.selector, tokenId
        );
    }

    function _writeOnceValueSet(uint256 tokenId, string memory key)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            MetadataWriterPolicy.WriteOnceValueSet.selector, tokenId, key
        );
    }

    function _assertCollectionAuthority(
        address authority,
        bool holderCanWrite,
        bool authorityLocked
    ) internal view {
        (address a, bool canWrite, bool locked) = agents.collectionAuthority();
        assertEq(a, authority);
        assertEq(canWrite, holderCanWrite);
        assertEq(locked, authorityLocked);
    }

    /// @dev Counts the logs with `topic` emitted by the token contract.
    function _count(Vm.Log[] memory logs, bytes32 topic)
        internal
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(agents) && logs[i].topics[0] == topic
            ) {
                ++count;
            }
        }
    }

    function testSupportsInterface() public view {
        assertTrue(agents.supportsInterface(0xdf670be1));
        assertEq(type(IERC8048Metadata).interfaceId, bytes4(0xdf670be1));
        // Not ERC-8048's Metadata Authority extension, since no token has
        // its own authority.
        assertFalse(agents.supportsInterface(0xf9cb127d));
        // ERC-4906, ERC-721 and ERC-165 still answer.
        assertTrue(agents.supportsInterface(0x49064906));
        assertTrue(agents.supportsInterface(0x80ac58cd));
        assertTrue(agents.supportsInterface(0x01ffc9a7));
        assertFalse(agents.supportsInterface(0xffffffff));
    }

    function testOwnerSetsMetadataBeforeAndAfterMint() public {
        // Before the token exists: MetadataSet, but no ERC-4906 refresh
        // for a token that isn't there yet.
        vm.recordLogs();
        vm.expectEmit(true, true, false, true, address(agents));
        emit IERC8048Metadata.MetadataSet(1, "context", "context", "lore");
        agents.setMetadata(1, "context", "lore");
        assertEq(_count(vm.getRecordedLogs(), METADATA_UPDATE), 0);
        assertEq(agents.metadata(1, "context"), bytes("lore"));

        // After mint, every write refreshes the token too.
        agents.mint(holder, 1);
        vm.expectEmit(true, true, false, true, address(agents));
        emit IERC8048Metadata.MetadataSet(
            1,
            "endpoint[web]",
            "endpoint[web]",
            "https://agent.example"
        );
        vm.expectEmit(false, false, false, true, address(agents));
        emit ERC721SeaDropAgents.MetadataUpdate(1);
        agents.setMetadata(1, "endpoint[web]", "https://agent.example");
        assertEq(
            agents.metadata(1, "endpoint[web]"), bytes("https://agent.example")
        );

        // Keys are exact bytes.
        assertEq(agents.metadata(1, "endpoint[WEB]").length, 0);

        // An empty value clears the key.
        agents.setMetadata(1, "context", "");
        assertEq(agents.metadata(1, "context").length, 0);
    }

    /// @dev Case 2: a blank authority with both settings false. Only the
    ///      owner writes.
    function testOwnerOnlyByDefault() public {
        _assertCollectionAuthority(address(0), false, false);
        agents.mint(holder, 1);

        vm.prank(stranger);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");

        vm.prank(holder);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");

        agents.setMetadata(1, "context", "owner");
        assertEq(agents.metadata(1, "context"), bytes("owner"));

        // A new owner takes over a blank authority.
        agents.transferOwnership(otherHolder);
        vm.prank(otherHolder);
        agents.acceptOwnership();
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "old owner");
        vm.prank(otherHolder);
        agents.setMetadata(1, "context", "new owner");
    }

    function testOnlyOwnerOrAuthoritySetsCollectionAuthority() public {
        agents.mint(holder, 1);

        // Not a stranger, a holder, or an approved operator.
        vm.prank(stranger);
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityUnauthorized.selector
        );
        agents.setCollectionAuthority(stranger, true, false);

        vm.prank(holder);
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityUnauthorized.selector
        );
        agents.setCollectionAuthority(address(0), true, false);

        vm.prank(holder);
        agents.setApprovalForAll(stranger, true);
        vm.prank(stranger);
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityUnauthorized.selector
        );
        agents.setCollectionAuthority(address(0), true, false);

        // The owner sets all three at once, with an event.
        vm.expectEmit(true, false, false, true, address(agents));
        emit ERC8048OnchainMetadata.CollectionAuthorityUpdated(
            writer,
            true,
            false
        );
        agents.setCollectionAuthority(writer, true, false);
        _assertCollectionAuthority(writer, true, false);

        // The authority can change them too.
        vm.prank(writer);
        agents.setCollectionAuthority(agentWallet, false, false);
        _assertCollectionAuthority(agentWallet, false, false);

        // A former authority can't.
        vm.prank(writer);
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityUnauthorized.selector
        );
        agents.setCollectionAuthority(writer, false, false);

        // The owner can return it to blank.
        agents.setCollectionAuthority(address(0), false, false);
        _assertCollectionAuthority(address(0), false, false);
    }

    function testCannotLockBlankAuthority() public {
        vm.expectRevert(
            ERC8048OnchainMetadata.CannotLockBlankAuthority.selector
        );
        agents.setCollectionAuthority(address(0), false, true);

        vm.expectRevert(
            ERC8048OnchainMetadata.CannotLockBlankAuthority.selector
        );
        agents.setCollectionAuthority(address(0), true, true);

        // Nor can a locked authority hand itself to blank.
        agents.setCollectionAuthority(writer, false, true);
        vm.prank(writer);
        vm.expectRevert(
            ERC8048OnchainMetadata.CannotLockBlankAuthority.selector
        );
        agents.setCollectionAuthority(address(0), false, true);

        // It can unlock while it clears itself.
        vm.prank(writer);
        agents.setCollectionAuthority(address(0), false, false);
        _assertCollectionAuthority(address(0), false, false);
    }

    function testWritesBeforeMint() public {
        agents.setCollectionAuthority(address(0), true, false);

        // The authority writes a token that isn't minted.
        agents.setMetadata(5, "context", "lore");
        assertEq(agents.metadata(5, "context"), bytes("lore"));

        // Nobody is its holder yet.
        vm.prank(holder);
        vm.expectRevert(_writeUnauthorized(5));
        agents.setMetadata(5, "context", "x");
        vm.prank(address(0));
        vm.expectRevert(_writeUnauthorized(5));
        agents.setMetadata(5, "context", "x");

        // A policy authority writes before mint too.
        MetadataWriterPolicy policy = _deployPolicy();
        agents.setCollectionAuthority(address(policy), false, false);
        vm.prank(policyAdmin);
        policy.setWriter(writer, true);
        vm.prank(writer);
        policy.setMetadata(6, "context", "policy lore");
        assertEq(agents.metadata(6, "context"), bytes("policy lore"));

        // Nobody can delegate a token that isn't minted.
        vm.prank(holder);
        vm.expectRevert(
            abi.encodeWithSelector(
                MetadataWriterPolicy.NotTokenHolder.selector, 6
            )
        );
        policy.setDelegate(6, agentWallet);
        assertEq(policy.delegateOf(6), address(0));
    }

    /// @dev Case 1: a city and its homeowners. A policy contract is the
    ///      authority, holders write only under its rules, and the owner
    ///      can replace it.
    function testPolicyAuthority() public {
        agents.mint(holder, 1);
        MetadataWriterPolicy city = _deployPolicy();
        agents.setCollectionAuthority(address(city), false, false);

        // Neither the holder nor the owner writes past the policy.
        vm.prank(holder);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");

        // The holder writes through the policy, under its rules.
        vm.prank(holder);
        city.setDelegate(1, holder);
        vm.prank(holder);
        city.setMetadata(1, "context", "homeowner");
        assertEq(agents.metadata(1, "context"), bytes("homeowner"));

        // The owner replaces the policy, and the old one can't write.
        MetadataWriterPolicy newCity = _deployPolicy();
        agents.setCollectionAuthority(address(newCity), false, false);
        _assertCollectionAuthority(address(newCity), false, false);
        vm.prank(holder);
        vm.expectRevert(_writeUnauthorized(1));
        city.setMetadata(1, "context", "old city");
    }

    /// @dev Case 3: holders write their own tokens, and the owner can
    ///      change the rules. Transfers need no claim.
    function testHoldersWrite() public {
        agents.mint(holder, 1);
        agents.mint(otherHolder, 1);
        agents.setCollectionAuthority(address(0), true, false);

        vm.prank(holder);
        agents.setMetadata(1, "endpoint[mcp]", "mcp://seller");
        assertEq(agents.metadata(1, "endpoint[mcp]"), bytes("mcp://seller"));

        // Not another holder's token, nor through an operator approval.
        vm.prank(holder);
        vm.expectRevert(_writeUnauthorized(2));
        agents.setMetadata(2, "context", "x");
        vm.prank(holder);
        agents.setApprovalForAll(stranger, true);
        vm.prank(stranger);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");

        // The owner still writes every token.
        agents.setMetadata(2, "context", "owner");

        // A transfer changes nothing in the settings and emits no
        // authority event.
        vm.recordLogs();
        vm.prank(holder);
        agents.transferFrom(holder, otherHolder, 1);
        assertEq(_count(vm.getRecordedLogs(), COLLECTION_AUTHORITY_UPDATED), 0);
        _assertCollectionAuthority(address(0), true, false);

        // The records stay with the token.
        assertEq(agents.metadata(1, "endpoint[mcp]"), bytes("mcp://seller"));

        // The new holder writes right away, and the old holder can't.
        vm.prank(otherHolder);
        agents.setMetadata(1, "endpoint[mcp]", "mcp://buyer");
        vm.prank(holder);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "endpoint[mcp]", "mcp://seller");

        // The owner changes the rules back.
        agents.setCollectionAuthority(address(0), false, false);
        vm.prank(otherHolder);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "endpoint[mcp]", "mcp://buyer");
    }

    function testHolderWriteFollowsOnlyTheMovedToken() public {
        // One batch mint of two tokens.
        agents.mint(holder, 2);
        agents.setCollectionAuthority(address(0), true, false);

        vm.prank(holder);
        agents.safeTransferFrom(holder, otherHolder, 2);

        vm.startPrank(holder);
        agents.setMetadata(1, "context", "still mine");
        vm.expectRevert(_writeUnauthorized(2));
        agents.setMetadata(2, "context", "x");
        vm.stopPrank();

        vm.prank(otherHolder);
        agents.setMetadata(2, "context", "mine now");
    }

    function testBurnedTokenHasNoHolder() public {
        agents.mint(holder, 1);
        agents.setCollectionAuthority(address(0), true, false);

        vm.prank(holder);
        agents.burn(1);

        vm.prank(holder);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");

        // The records stay, and the owner can still write them, without
        // refreshing a token that no longer exists.
        vm.recordLogs();
        agents.setMetadata(1, "context", "retired");
        assertEq(_count(vm.getRecordedLogs(), METADATA_UPDATE), 0);
        assertEq(agents.metadata(1, "context"), bytes("retired"));
    }

    /// @dev Case 4: holders control their metadata for good. The
    ///      authority is a burn address and locked.
    function testHoldersControlForGood() public {
        agents.mint(holder, 1);
        agents.setMetadata(1, "context", "owner lore");
        agents.setCollectionAuthority(DEAD, true, true);
        _assertCollectionAuthority(DEAD, true, true);

        // Nobody changes the settings again.
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityIsLocked.selector
        );
        agents.setCollectionAuthority(address(0), false, false);
        vm.prank(holder);
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityUnauthorized.selector
        );
        agents.setCollectionAuthority(holder, true, true);

        // The owner can't write.
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "owner again");

        // The holder writes, and after a sale the buyer does.
        vm.prank(holder);
        agents.setMetadata(1, "context", "holder lore");
        vm.prank(holder);
        agents.transferFrom(holder, otherHolder, 1);
        vm.prank(otherHolder);
        agents.setMetadata(1, "context", "buyer lore");
        assertEq(agents.metadata(1, "context"), bytes("buyer lore"));

        // A new owner can't take it back either.
        agents.transferOwnership(stranger);
        vm.prank(stranger);
        agents.acceptOwnership();
        vm.prank(stranger);
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityIsLocked.selector
        );
        agents.setCollectionAuthority(address(0), false, false);
    }

    /// @dev Case 5: a locked policy. The owner can't replace it, and only
    ///      the policy can hand the authority on.
    function testLockedPolicy() public {
        agents.mint(holder, 1);
        MetadataWriterPolicy policy = _deployPolicy();
        agents.setCollectionAuthority(address(policy), false, true);

        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityIsLocked.selector
        );
        agents.setCollectionAuthority(address(0), false, false);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");

        // The policy's admin, not the token owner, hands it on.
        MetadataWriterPolicy next = _deployPolicy();
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        policy.setCollectionAuthority(address(next), false, true);

        vm.expectEmit(true, false, false, true, address(agents));
        emit ERC8048OnchainMetadata.CollectionAuthorityUpdated(
            address(next),
            false,
            true
        );
        vm.prank(policyAdmin);
        policy.setCollectionAuthority(address(next), false, true);
        _assertCollectionAuthority(address(next), false, true);

        // The old policy is out, and the owner is still locked out.
        vm.prank(policyAdmin);
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityUnauthorized.selector
        );
        policy.setCollectionAuthority(address(policy), false, true);
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityIsLocked.selector
        );
        agents.setCollectionAuthority(address(policy), false, false);
    }

    function testOwnerAsLockedAuthority() public {
        // An owner named as the locked authority is the authority, so it
        // still changes the settings, until ownership moves.
        agents.setCollectionAuthority(address(this), false, true);
        agents.setCollectionAuthority(address(this), true, true);
        agents.setMetadata(1, "context", "x");

        agents.transferOwnership(otherHolder);
        vm.prank(otherHolder);
        agents.acceptOwnership();
        vm.prank(otherHolder);
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityIsLocked.selector
        );
        agents.setCollectionAuthority(otherHolder, true, true);
        agents.setMetadata(1, "context", "former owner, still authority");
    }

    function testSetMetadataBatch() public {
        uint256[] memory tokenIds = new uint256[](4);
        string[] memory keys = new string[](4);
        bytes[] memory values = new bytes[](4);
        (tokenIds[0], keys[0], values[0]) = (1, "context", "one");
        (tokenIds[1], keys[1], values[1]) = (1, "endpoint[mcp]", "mcp://one");
        (tokenIds[2], keys[2], values[2]) = (2, "context", "two");
        (tokenIds[3], keys[3], values[3]) = (1, "endpoint[a2a]", "a2a://one");

        // Before mint, the batch emits no ERC-4906 refreshes.
        vm.recordLogs();
        agents.setMetadataBatch(tokenIds, keys, values);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(_count(logs, METADATA_SET), 4);
        assertEq(_count(logs, METADATA_UPDATE), 0);

        agents.mint(holder, 2);
        vm.recordLogs();
        agents.setMetadataBatch(tokenIds, keys, values);
        logs = vm.getRecordedLogs();

        assertEq(agents.metadata(1, "context"), bytes("one"));
        assertEq(agents.metadata(1, "endpoint[mcp]"), bytes("mcp://one"));
        assertEq(agents.metadata(2, "context"), bytes("two"));
        assertEq(agents.metadata(1, "endpoint[a2a]"), bytes("a2a://one"));

        // One MetadataSet per entry, one MetadataUpdate per run of entries
        // for the same token: [1, 1], [2], [1].
        assertEq(_count(logs, METADATA_SET), 4);
        assertEq(_count(logs, METADATA_UPDATE), 3);

        string[] memory shortKeys = new string[](3);
        vm.expectRevert(
            ERC8048OnchainMetadata.MetadataBatchLengthMismatch.selector
        );
        agents.setMetadataBatch(tokenIds, shortKeys, values);

        bytes[] memory shortValues = new bytes[](3);
        vm.expectRevert(
            ERC8048OnchainMetadata.MetadataBatchLengthMismatch.selector
        );
        agents.setMetadataBatch(tokenIds, keys, shortValues);

        // A holder batches their own tokens.
        agents.setCollectionAuthority(address(0), true, false);
        values[0] = "holder";
        vm.prank(holder);
        agents.setMetadataBatch(tokenIds, keys, values);
        assertEq(agents.metadata(1, "context"), bytes("holder"));

        // One bad entry reverts the whole batch.
        vm.prank(holder);
        agents.transferFrom(holder, otherHolder, 2);
        values[0] = "changed";
        vm.prank(holder);
        vm.expectRevert(_writeUnauthorized(2));
        agents.setMetadataBatch(tokenIds, keys, values);
        assertEq(agents.metadata(1, "context"), bytes("holder"));
    }

    /// @dev Freezing every record: no holder writes, and a locked
    ///      authority nobody controls.
    function testFreezeEverything() public {
        agents.mint(holder, 1);
        agents.setMetadata(1, "context", "final");
        agents.setMetadata(2, "context", "final before mint");
        agents.setCollectionAuthority(DEAD, false, true);

        // Nobody writes any token, minted or not.
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");
        vm.prank(holder);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");
        vm.expectRevert(_writeUnauthorized(2));
        agents.setMetadata(2, "context", "x");

        // Nobody changes the settings back.
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityIsLocked.selector
        );
        agents.setCollectionAuthority(address(0), false, false);
        vm.prank(holder);
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityUnauthorized.selector
        );
        agents.setCollectionAuthority(address(0), false, false);

        assertEq(agents.metadata(1, "context"), bytes("final"));
        assertEq(agents.metadata(2, "context"), bytes("final before mint"));
    }

    /// @dev Prem's case: an artist signs the first tokens, and tokens
    ///      minted later can still be signed once.
    function testPolicyWriteOnceKey() public {
        MetadataWriterPolicy policy = _deployPolicy();
        agents.setCollectionAuthority(address(policy), false, false);
        address artist = makeAddr("artist");

        vm.prank(stranger);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        policy.setWriteOnceKey("artist.signature", true);

        vm.startPrank(policyAdmin);
        policy.setWriter(artist, true);
        vm.expectEmit(true, false, false, true, address(policy));
        emit MetadataWriterPolicy.WriteOnceKeyUpdated(
            "artist.signature",
            "artist.signature",
            true
        );
        policy.setWriteOnceKey("artist.signature", true);
        vm.stopPrank();
        assertTrue(policy.isWriteOnceKey("artist.signature"));
        assertFalse(policy.isWriteOnceKey("context"));

        // The artist signs tokens 1 and 2.
        agents.mint(holder, 2);
        vm.startPrank(artist);
        policy.setMetadata(1, "artist.signature", "sig1");
        policy.setMetadata(2, "artist.signature", "sig2");

        // Nobody overwrites them, the artist included.
        vm.expectRevert(_writeOnceValueSet(1, "artist.signature"));
        policy.setMetadata(1, "artist.signature", "forged");
        vm.expectRevert(_writeOnceValueSet(2, "artist.signature"));
        policy.setMetadata(2, "artist.signature", "");

        // Other keys stay writable.
        policy.setMetadata(1, "context", "one");
        policy.setMetadata(1, "context", "one, again");
        vm.stopPrank();

        // Not the holder's delegate, and not the owner past the policy.
        vm.prank(holder);
        policy.setDelegate(1, agentWallet);
        vm.prank(agentWallet);
        vm.expectRevert(_writeOnceValueSet(1, "artist.signature"));
        policy.setMetadata(1, "artist.signature", "forged");
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "artist.signature", "forged");

        // Token 3 mints later and can still be signed, once. An empty
        // write leaves it unsigned.
        agents.mint(otherHolder, 1);
        vm.startPrank(artist);
        policy.setMetadata(3, "artist.signature", "");
        policy.setMetadata(3, "artist.signature", "sig3");
        vm.expectRevert(_writeOnceValueSet(3, "artist.signature"));
        policy.setMetadata(3, "artist.signature", "sig3, again");
        vm.stopPrank();

        assertEq(agents.metadata(1, "artist.signature"), bytes("sig1"));
        assertEq(agents.metadata(2, "artist.signature"), bytes("sig2"));
        assertEq(agents.metadata(3, "artist.signature"), bytes("sig3"));

        // The admin can unmark the key, so a lasting freeze locks the
        // authority to the policy and renounces the policy.
        agents.setCollectionAuthority(address(policy), false, true);
        vm.prank(policyAdmin);
        policy.renounceOwnership();
        vm.prank(policyAdmin);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        policy.setWriteOnceKey("artist.signature", false);
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityIsLocked.selector
        );
        agents.setCollectionAuthority(address(0), false, false);
        vm.prank(artist);
        vm.expectRevert(_writeOnceValueSet(1, "artist.signature"));
        policy.setMetadata(1, "artist.signature", "forged");
    }

    function testPolicyWriteOnceKeyUnmarked() public {
        MetadataWriterPolicy policy = _deployPolicy();
        agents.setCollectionAuthority(address(policy), false, false);
        vm.startPrank(policyAdmin);
        policy.setWriter(writer, true);
        policy.setWriteOnceKey("artist.signature", true);
        vm.stopPrank();

        vm.prank(writer);
        policy.setMetadata(1, "artist.signature", "sig1");

        // While the admin can act, it can unmark the key.
        vm.prank(policyAdmin);
        policy.setWriteOnceKey("artist.signature", false);
        assertFalse(policy.isWriteOnceKey("artist.signature"));
        vm.prank(writer);
        policy.setMetadata(1, "artist.signature", "sig1, fixed");
        assertEq(agents.metadata(1, "artist.signature"), bytes("sig1, fixed"));
    }

    function testPolicyWriteOnceKeyBatch() public {
        MetadataWriterPolicy policy = _deployPolicy();
        agents.setCollectionAuthority(address(policy), false, false);
        vm.startPrank(policyAdmin);
        policy.setWriter(writer, true);
        policy.setWriteOnceKey("artist.signature", true);
        vm.stopPrank();
        agents.mint(holder, 2);

        uint256[] memory tokenIds = new uint256[](2);
        string[] memory keys = new string[](2);
        bytes[] memory values = new bytes[](2);
        (tokenIds[0], keys[0], values[0]) = (1, "artist.signature", "sig1");
        (tokenIds[1], keys[1], values[1]) = (2, "artist.signature", "sig2");

        vm.startPrank(writer);
        policy.setMetadataBatch(tokenIds, keys, values);
        assertEq(agents.metadata(1, "artist.signature"), bytes("sig1"));
        assertEq(agents.metadata(2, "artist.signature"), bytes("sig2"));

        // A batch can't overwrite a signature on the token.
        (tokenIds[0], keys[0], values[0]) = (1, "context", "one");
        (tokenIds[1], keys[1], values[1]) = (1, "artist.signature", "forged");
        vm.expectRevert(_writeOnceValueSet(1, "artist.signature"));
        policy.setMetadataBatch(tokenIds, keys, values);

        // Nor sign a token twice within the batch.
        (tokenIds[0], keys[0], values[0]) = (3, "artist.signature", "sig3");
        (tokenIds[1], keys[1], values[1]) = (3, "artist.signature", "forged");
        vm.expectRevert(_writeOnceValueSet(3, "artist.signature"));
        policy.setMetadataBatch(tokenIds, keys, values);
        assertEq(agents.metadata(3, "artist.signature").length, 0);

        // Earlier entries count only for the same token and key, with a
        // value.
        uint256[] memory ids = new uint256[](4);
        string[] memory ks = new string[](4);
        bytes[] memory vs = new bytes[](4);
        (ids[0], ks[0], vs[0]) = (3, "artist.signature", "");
        (ids[1], ks[1], vs[1]) = (4, "artist.signature", "sig4");
        (ids[2], ks[2], vs[2]) = (3, "context", "three");
        (ids[3], ks[3], vs[3]) = (3, "artist.signature", "sig3");
        policy.setMetadataBatch(ids, ks, vs);
        assertEq(agents.metadata(3, "artist.signature"), bytes("sig3"));
        assertEq(agents.metadata(4, "artist.signature"), bytes("sig4"));

        // The policy checks lengths before it reads entries.
        string[] memory shortKeys = new string[](1);
        vm.expectRevert(MetadataWriterPolicy.BatchLengthMismatch.selector);
        policy.setMetadataBatch(tokenIds, shortKeys, values);
        bytes[] memory shortValues = new bytes[](1);
        vm.expectRevert(MetadataWriterPolicy.BatchLengthMismatch.selector);
        policy.setMetadataBatch(tokenIds, keys, shortValues);
        vm.stopPrank();
    }

    function testPolicyWriters() public {
        MetadataWriterPolicy policy = _deployPolicy();
        assertEq(address(policy.token()), address(agents));
        agents.setCollectionAuthority(address(policy), false, false);

        vm.prank(stranger);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        policy.setWriter(writer, true);

        vm.expectEmit(true, false, false, true, address(policy));
        emit MetadataWriterPolicy.WriterUpdated(writer, true);
        vm.prank(policyAdmin);
        policy.setWriter(writer, true);
        assertTrue(policy.isWriter(writer));
        assertFalse(policy.isWriter(stranger));

        // A writer writes any token, minted or not, one at a time or in a
        // batch.
        agents.mint(holder, 1);
        vm.startPrank(writer);
        policy.setMetadata(7, "context", "written");
        policy.setMetadata(1, "context", "written");
        uint256[] memory tokenIds = new uint256[](2);
        string[] memory keys = new string[](2);
        bytes[] memory values = new bytes[](2);
        (tokenIds[0], keys[0], values[0]) = (1, "endpoint[mcp]", "mcp://1");
        (tokenIds[1], keys[1], values[1]) = (7, "endpoint[mcp]", "mcp://7");
        policy.setMetadataBatch(tokenIds, keys, values);
        vm.stopPrank();
        assertEq(agents.metadata(7, "context"), bytes("written"));
        assertEq(agents.metadata(1, "endpoint[mcp]"), bytes("mcp://1"));
        assertEq(agents.metadata(7, "endpoint[mcp]"), bytes("mcp://7"));

        // A writer can't do anything else the admins can.
        vm.startPrank(writer);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        agents.setBaseURI("ipfs://other/");
        vm.expectRevert(
            ERC8048OnchainMetadata.CollectionAuthorityUnauthorized.selector
        );
        agents.setCollectionAuthority(writer, false, false);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        policy.setWriteOnceKey("context", true);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        policy.setWriter(stranger, true);
        vm.stopPrank();

        // Strangers can't write through the policy.
        vm.prank(stranger);
        vm.expectRevert(_policyWriteUnauthorized(7));
        policy.setMetadata(7, "context", "x");

        vm.prank(policyAdmin);
        policy.setWriter(writer, false);
        assertFalse(policy.isWriter(writer));
        vm.prank(writer);
        vm.expectRevert(_policyWriteUnauthorized(7));
        policy.setMetadata(7, "endpoint[mcp]", "again");
    }

    function testPolicyHolderDelegate() public {
        MetadataWriterPolicy policy = _deployPolicy();
        agents.setCollectionAuthority(address(policy), false, false);
        agents.mint(holder, 2);

        // Only the token's holder delegates, not an operator or the
        // policy's admin.
        vm.prank(holder);
        agents.setApprovalForAll(stranger, true);
        bytes memory notHolder = abi.encodeWithSelector(
            MetadataWriterPolicy.NotTokenHolder.selector, 1
        );
        vm.prank(stranger);
        vm.expectRevert(notHolder);
        policy.setDelegate(1, stranger);
        vm.prank(policyAdmin);
        vm.expectRevert(notHolder);
        policy.setDelegate(1, policyAdmin);

        vm.expectEmit(true, true, true, true, address(policy));
        emit MetadataWriterPolicy.DelegateSet(1, holder, agentWallet);
        vm.prank(holder);
        policy.setDelegate(1, agentWallet);
        assertEq(policy.delegateOf(1), agentWallet);
        assertEq(policy.delegateOf(2), address(0));

        // The agent's wallet writes its token, and not the holder's other
        // token.
        vm.startPrank(agentWallet);
        policy.setMetadata(1, "endpoint[mcp]", "mcp://agent");
        vm.expectRevert(_policyWriteUnauthorized(2));
        policy.setMetadata(2, "endpoint[mcp]", "mcp://agent");

        uint256[] memory tokenIds = new uint256[](2);
        string[] memory keys = new string[](2);
        bytes[] memory values = new bytes[](2);
        (tokenIds[0], keys[0], values[0]) = (1, "context", "agent lore");
        (tokenIds[1], keys[1], values[1]) = (1, "endpoint[a2a]", "a2a://1");
        policy.setMetadataBatch(tokenIds, keys, values);
        tokenIds[1] = 2;
        vm.expectRevert(_policyWriteUnauthorized(2));
        policy.setMetadataBatch(tokenIds, keys, values);
        vm.stopPrank();
        assertEq(agents.metadata(1, "endpoint[mcp]"), bytes("mcp://agent"));
        assertEq(agents.metadata(1, "endpoint[a2a]"), bytes("a2a://1"));

        // The agent's wallet can't write the token directly.
        vm.prank(agentWallet);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");

        // The delegation lapses when the token is sold.
        vm.prank(holder);
        agents.transferFrom(holder, otherHolder, 1);
        assertEq(policy.delegateOf(1), address(0));
        vm.prank(agentWallet);
        vm.expectRevert(_policyWriteUnauthorized(1));
        policy.setMetadata(1, "endpoint[mcp]", "mcp://seller");

        // The old holder can't delegate it again, and the buyer can.
        vm.prank(holder);
        vm.expectRevert(notHolder);
        policy.setDelegate(1, agentWallet);
        vm.prank(otherHolder);
        policy.setDelegate(1, writer);
        vm.prank(writer);
        policy.setMetadata(1, "endpoint[mcp]", "mcp://buyer");

        // Clearing it with the zero address.
        vm.prank(otherHolder);
        policy.setDelegate(1, address(0));
        assertEq(policy.delegateOf(1), address(0));
        vm.prank(writer);
        vm.expectRevert(_policyWriteUnauthorized(1));
        policy.setMetadata(1, "endpoint[mcp]", "x");

        // A burned token has no holder, so no delegate.
        vm.prank(holder);
        policy.setDelegate(2, agentWallet);
        vm.prank(holder);
        agents.burn(2);
        assertEq(policy.delegateOf(2), address(0));
        vm.prank(agentWallet);
        vm.expectRevert(_policyWriteUnauthorized(2));
        policy.setMetadata(2, "context", "x");
    }

    function testPolicyRenounceCancelsPendingOwner() public {
        MetadataWriterPolicy policy = _deployPolicy();
        agents.setCollectionAuthority(address(policy), false, true);

        vm.startPrank(policyAdmin);
        policy.transferOwnership(stranger);
        policy.renounceOwnership();
        vm.stopPrank();
        assertEq(policy.owner(), address(0));

        // The pending owner can't take back the renounced policy.
        vm.prank(stranger);
        vm.expectRevert(TwoStepOwnable.NotNextOwner.selector);
        policy.acceptOwnership();
        vm.prank(stranger);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        policy.setWriter(stranger, true);
        vm.prank(stranger);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        policy.setCollectionAuthority(stranger, false, false);
    }

    function testReusableNextToOpenZeppelinERC4906() public {
        URIStorageWithOnchainMetadata reuse =
            new URIStorageWithOnchainMetadata();
        reuse.mint(holder, 7);

        vm.expectEmit(true, true, true, true, address(reuse));
        emit ERC721SeaDropAgents.MetadataUpdate(7);
        reuse.setMetadata(7, "context", "hello");
        assertEq(reuse.metadata(7, "context"), bytes("hello"));

        vm.prank(holder);
        vm.expectRevert(_writeUnauthorized(7));
        reuse.setMetadata(7, "context", "bye");

        reuse.setCollectionAuthority(address(0), true, false);
        vm.prank(holder);
        reuse.setMetadata(7, "context", "bye");
        assertEq(reuse.metadata(7, "context"), bytes("bye"));
    }

    function testRegisterAgents() public {
        agents.registerAgents(1, 3, "https://agents.example/", ".json");

        assertEq(adapter.registrations(), 3);
        for (uint256 tokenId = 1; tokenId <= 3; ++tokenId) {
            (bool registered, uint256 agentId) = agents.agentOf(tokenId);
            assertTrue(registered);
            assertEq(agentId, tokenId);
            (address bound, uint256 boundTokenId, string memory agentURI) =
                adapter.bindings(agentId);
            assertEq(bound, address(agents));
            assertEq(boundTokenId, tokenId);
            assertEq(
                agentURI,
                string.concat(
                    "https://agents.example/", vm.toString(tokenId), ".json"
                )
            );
        }
        (bool none,) = agents.agentOf(4);
        assertFalse(none);

        // A repeated or overlapping range skips registered tokens.
        agents.registerAgents(2, 5, "https://agents.example/", ".json");
        assertEq(adapter.registrations(), 5);
        (, uint256 agentFive) = agents.agentOf(5);
        assertEq(agentFive, 5);

        // The holder controls the agent after mint.
        agents.mint(holder, 1);
        (, uint256 agentOne) = agents.agentOf(1);
        assertTrue(adapter.isController(agentOne, holder));
        assertFalse(adapter.isController(agentOne, address(agents)));
    }

    function testRegisterAgentsRanges() public {
        agents.mint(holder, 2);

        // Minted tokens can't be registered by the contract.
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropAgents.InvalidAgentTokenIdRange.selector, 2, 4
            )
        );
        agents.registerAgents(2, 4, "", "");

        // Empty range.
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropAgents.InvalidAgentTokenIdRange.selector, 5, 4
            )
        );
        agents.registerAgents(5, 4, "", "");

        // Past the max supply.
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropAgents.InvalidAgentTokenIdRange.selector, 99, 101
            )
        );
        agents.registerAgents(99, 101, "", "");

        // The next token to mint, up to the max supply, is fine.
        agents.registerAgents(3, 3, "", "");
        agents.registerAgents(100, 100, "", "");
        assertEq(adapter.registrations(), 2);
    }

    function testRegisterAgentsOnlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        agents.registerAgents(1, 1, "", "");
    }

    function testRegisterAgentsWithoutAdapter() public {
        ERC721SeaDropAgentsWithMint noAdapter = _deploy(address(0));
        noAdapter.setMaxSupply(10);
        assertEq(noAdapter.agentAdapter(), address(0));

        vm.expectRevert(ERC721SeaDropAgents.AgentAdapterNotSet.selector);
        noAdapter.registerAgents(1, 1, "", "");

        // Metadata works without an adapter.
        noAdapter.setMetadata(1, "context", "lore");
        assertEq(noAdapter.metadata(1, "context"), bytes("lore"));
    }

    /// @dev The ERC-8217 adapter docs/AgentNFTs.md lists for `chainId`.
    function _deployedAdapter(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) return 0xde152AfB7db5373F34876E1499fbD893A82dD336;
        if (chainId == 8453) return 0x270d25D2c59A8bcA1B0f40ad95fF7806c0025c27;
        if (chainId == 4663) return 0x000000009d62675362a58911e3f32FEcf46F5E18;
        if (chainId == 11_155_111) {
            return 0x7621630cB63a73a194f45A3E6801B8C6A7eC2f92;
        }
        revert("no adapter listed for this chain");
    }

    /// @dev Registers through the ERC-8217 adapter deployed on the chain
    ///      AGENT_ADAPTER_FORK_URL names: Ethereum, Base, Robinhood Chain or
    ///      Sepolia. Skipped when it isn't set.
    function testRegisterAgentsWithDeployedAdapter() public {
        string memory forkUrl = vm.envOr("AGENT_ADAPTER_FORK_URL", string(""));
        if (bytes(forkUrl).length == 0) {
            vm.skip(true);
            return;
        }

        vm.createSelectFork(forkUrl);
        address deployedAdapter = _deployedAdapter(block.chainid);

        ERC721SeaDropAgentsWithMint forked = _deploy(deployedAdapter);
        forked.setMaxSupply(10);
        forked.registerAgents(1, 2, "https://agents.example/", ".json");

        IAgentAdapterView view_ = IAgentAdapterView(deployedAdapter);
        (bool registered, uint256 agentId) = forked.agentOf(1);
        assertTrue(registered);
        IAgentAdapterView.Binding memory binding = view_.bindingOf(agentId);
        assertEq(binding.standard, 0);
        assertEq(binding.boundAddress, address(forked));
        assertEq(binding.tokenId, 1);
        assertEq(view_.tokenURI(agentId), "https://agents.example/1.json");

        // The holder controls the agent after mint, and the contract
        // can't register the minted token again.
        forked.mint(holder, 1);
        assertTrue(view_.isController(agentId, holder));
        assertFalse(view_.isController(agentId, address(forked)));
        assertFalse(view_.isController(agentId, address(this)));
    }
}
