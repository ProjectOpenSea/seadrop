// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { Vm } from "forge-std/Vm.sol";

import {
    ERC721SeaDropAgents
} from "seadrop/extensions/ERC721SeaDropAgents.sol";

import { ERC8048OnchainMetadata } from "seadrop/lib/ERC8048OnchainMetadata.sol";

import { IERC8048Metadata } from "seadrop/interfaces/IERC8048Metadata.sol";

import {
    IERC8048MetadataAuthority
} from "seadrop/interfaces/IERC8048MetadataAuthority.sol";

import { MockAgentAdapter } from "seadrop/test/MockAgentAdapter.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

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

contract ERC721SeaDropAgentsTest is TestHelper {
    bytes32 constant METADATA_SET =
        keccak256("MetadataSet(uint256,string,string,bytes)");
    bytes32 constant METADATA_UPDATE = keccak256("MetadataUpdate(uint256)");

    MockAgentAdapter adapter;
    ERC721SeaDropAgentsWithMint agents;

    address holder = makeAddr("holder");
    address otherHolder = makeAddr("otherHolder");
    address writer = makeAddr("writer");
    address agentWallet = makeAddr("agentWallet");
    address stranger = makeAddr("stranger");

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

    function _writeUnauthorized(uint256 tokenId)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            ERC8048OnchainMetadata.MetadataWriteUnauthorized.selector, tokenId
        );
    }

    function _authorityUnauthorized(uint256 tokenId)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            ERC8048OnchainMetadata.MetadataAuthorityUnauthorized.selector,
            tokenId
        );
    }

    function _keyIsLocked(string memory key)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            ERC8048OnchainMetadata.MetadataKeyIsLocked.selector, key
        );
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
        assertTrue(agents.supportsInterface(0xf9cb127d));
        assertEq(type(IERC8048Metadata).interfaceId, bytes4(0xdf670be1));
        assertEq(
            type(IERC8048MetadataAuthority).interfaceId, bytes4(0xf9cb127d)
        );
        // ERC-4906, ERC-721 and ERC-165 still answer.
        assertTrue(agents.supportsInterface(0x49064906));
        assertTrue(agents.supportsInterface(0x80ac58cd));
        assertTrue(agents.supportsInterface(0x01ffc9a7));
        assertFalse(agents.supportsInterface(0xffffffff));
    }

    function testOwnerSetsMetadataBeforeAndAfterMint() public {
        // Before the token exists.
        vm.expectEmit(true, true, false, true, address(agents));
        emit IERC8048Metadata.MetadataSet(1, "context", "context", "lore");
        vm.expectEmit(false, false, false, true, address(agents));
        emit ERC8048OnchainMetadata.MetadataUpdate(1);
        agents.setMetadata(1, "context", "lore");
        assertEq(agents.metadata(1, "context"), bytes("lore"));

        agents.mint(holder, 1);
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

    function testStrangerAndHolderCannotWriteWithoutAuthority() public {
        agents.mint(holder, 1);

        vm.prank(stranger);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");

        // The holder writes only through the metadata authority.
        vm.prank(holder);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");
    }

    function testMetadataWriter() public {
        vm.prank(stranger);
        vm.expectRevert(ERC8048OnchainMetadata.MetadataAdminOnly.selector);
        agents.setMetadataWriter(writer, true);

        vm.expectEmit(true, false, false, true, address(agents));
        emit ERC8048OnchainMetadata.MetadataWriterUpdated(writer, true);
        agents.setMetadataWriter(writer, true);
        assertTrue(agents.isMetadataWriter(writer));

        vm.prank(writer);
        agents.setMetadata(7, "context", "written");
        assertEq(agents.metadata(7, "context"), bytes("written"));

        // A writer can't do anything else the owner can.
        vm.startPrank(writer);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        agents.setBaseURI("ipfs://other/");
        vm.expectRevert(ERC8048OnchainMetadata.MetadataAdminOnly.selector);
        agents.lockMetadataKey("context");
        vm.expectRevert(ERC8048OnchainMetadata.MetadataAdminOnly.selector);
        agents.setMetadataWriter(stranger, true);
        vm.stopPrank();

        agents.setMetadataWriter(writer, false);
        assertFalse(agents.isMetadataWriter(writer));
        vm.prank(writer);
        vm.expectRevert(_writeUnauthorized(7));
        agents.setMetadata(7, "context", "again");
    }

    function testSetMetadataBatch() public {
        uint256[] memory tokenIds = new uint256[](4);
        string[] memory keys = new string[](4);
        bytes[] memory values = new bytes[](4);
        (tokenIds[0], keys[0], values[0]) = (1, "context", "one");
        (tokenIds[1], keys[1], values[1]) = (1, "endpoint[mcp]", "mcp://one");
        (tokenIds[2], keys[2], values[2]) = (2, "context", "two");
        (tokenIds[3], keys[3], values[3]) = (1, "endpoint[a2a]", "a2a://one");

        vm.recordLogs();
        agents.setMetadataBatch(tokenIds, keys, values);
        Vm.Log[] memory logs = vm.getRecordedLogs();

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

        // One bad entry reverts the whole batch.
        agents.mint(holder, 2);
        vm.prank(holder);
        agents.setMetadataAuthority(2, holder);
        values[0] = "changed";
        vm.expectRevert(_writeUnauthorized(2));
        agents.setMetadataBatch(tokenIds, keys, values);
        assertEq(agents.metadata(1, "context"), bytes("one"));
    }

    function testLockMetadataKey() public {
        agents.mint(holder, 1);
        agents.setMetadataWriter(writer, true);
        agents.setMetadata(1, "context", "lore");

        vm.prank(stranger);
        vm.expectRevert(ERC8048OnchainMetadata.MetadataAdminOnly.selector);
        agents.lockMetadataKey("context");

        vm.expectEmit(true, false, false, true, address(agents));
        emit ERC8048OnchainMetadata.MetadataKeyLocked("context", "context");
        agents.lockMetadataKey("context");
        assertTrue(agents.metadataKeyLocked("context"));
        assertFalse(agents.metadataKeyLocked("endpoint[web]"));

        vm.expectRevert(_keyIsLocked("context"));
        agents.lockMetadataKey("context");

        // Nobody writes a locked key, for any token, minted or not.
        vm.expectRevert(_keyIsLocked("context"));
        agents.setMetadata(1, "context", "new lore");
        vm.expectRevert(_keyIsLocked("context"));
        agents.setMetadata(50, "context", "new lore");
        vm.prank(writer);
        vm.expectRevert(_keyIsLocked("context"));
        agents.setMetadata(1, "context", "new lore");

        // Authorities included.
        vm.prank(holder);
        agents.setMetadataAuthority(1, holder);
        vm.startPrank(holder);
        vm.expectRevert(_keyIsLocked("context"));
        agents.setMetadata(1, "context", "new lore");
        agents.setMetadata(1, "endpoint[web]", "https://holder.example");
        vm.stopPrank();

        assertEq(agents.metadata(1, "context"), bytes("lore"));
    }

    function testHolderTakesOverWithMetadataAuthority() public {
        agents.mint(holder, 1);
        agents.setMetadataWriter(writer, true);
        assertEq(agents.metadataAuthority(1), address(0));

        vm.expectEmit(true, true, false, true, address(agents));
        emit IERC8048MetadataAuthority.MetadataAuthoritySet(1, holder);
        vm.prank(holder);
        agents.setMetadataAuthority(1, holder);
        assertEq(agents.metadataAuthority(1), holder);

        // Only the authority writes now, not the owner or a writer.
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "endpoint[mcp]", "mcp://owner");
        vm.prank(writer);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "endpoint[mcp]", "mcp://writer");
        vm.prank(holder);
        agents.setMetadata(1, "endpoint[mcp]", "mcp://holder");
        assertEq(agents.metadata(1, "endpoint[mcp]"), bytes("mcp://holder"));

        // Other tokens keep the contract's write policy.
        agents.setMetadata(2, "endpoint[mcp]", "mcp://owner");

        // The authority hands the role to the agent's wallet.
        vm.prank(holder);
        agents.setMetadataAuthority(1, agentWallet);
        vm.prank(agentWallet);
        agents.setMetadata(1, "endpoint[mcp]", "mcp://agent");

        // The agent's wallet clears it, and the owner writes again.
        vm.prank(agentWallet);
        agents.setMetadataAuthority(1, address(0));
        assertEq(agents.metadataAuthority(1), address(0));
        agents.setMetadata(1, "endpoint[mcp]", "mcp://owner");
    }

    function testHolderOverridesAuthority() public {
        agents.mint(holder, 1);

        vm.prank(holder);
        agents.setMetadataAuthority(1, agentWallet);

        // A former authority can't take the role back.
        vm.prank(agentWallet);
        agents.setMetadataAuthority(1, stranger);
        assertEq(agents.metadataAuthority(1), stranger);
        vm.prank(agentWallet);
        vm.expectRevert(_authorityUnauthorized(1));
        agents.setMetadataAuthority(1, agentWallet);

        // The holder can always replace the authority.
        vm.prank(holder);
        agents.setMetadataAuthority(1, holder);
        assertEq(agents.metadataAuthority(1), holder);
        vm.prank(stranger);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "context", "x");
    }

    function testOnlyHolderSetsMetadataAuthority() public {
        agents.mint(holder, 1);
        agents.mint(otherHolder, 1);

        // Not the contract owner.
        vm.expectRevert(_authorityUnauthorized(1));
        agents.setMetadataAuthority(1, address(this));

        // Not another token's holder.
        vm.prank(otherHolder);
        vm.expectRevert(_authorityUnauthorized(1));
        agents.setMetadataAuthority(1, otherHolder);

        // Not an approved operator.
        vm.prank(holder);
        agents.setApprovalForAll(stranger, true);
        vm.prank(stranger);
        vm.expectRevert(_authorityUnauthorized(1));
        agents.setMetadataAuthority(1, stranger);

        // Nobody, for a token that doesn't exist.
        vm.expectRevert(_authorityUnauthorized(3));
        agents.setMetadataAuthority(3, address(this));
        vm.prank(address(0));
        vm.expectRevert(_authorityUnauthorized(3));
        agents.setMetadataAuthority(3, stranger);
    }

    function testTransferClearsMetadataAuthority() public {
        agents.mint(holder, 1);
        vm.prank(holder);
        agents.setMetadataAuthority(1, agentWallet);

        vm.expectEmit(true, true, false, true, address(agents));
        emit IERC8048MetadataAuthority.MetadataAuthoritySet(1, address(0));
        vm.prank(holder);
        agents.transferFrom(holder, otherHolder, 1);
        assertEq(agents.metadataAuthority(1), address(0));

        // The seller's authority can't write the buyer's records.
        vm.prank(agentWallet);
        vm.expectRevert(_writeUnauthorized(1));
        agents.setMetadata(1, "endpoint[mcp]", "mcp://seller");

        // A transfer without an authority emits nothing extra.
        vm.recordLogs();
        vm.prank(otherHolder);
        agents.transferFrom(otherHolder, holder, 1);
        assertEq(
            _count(
                vm.getRecordedLogs(),
                IERC8048MetadataAuthority.MetadataAuthoritySet.selector
            ),
            0
        );
    }

    function testBurnClearsMetadataAuthority() public {
        agents.mint(holder, 1);
        vm.prank(holder);
        agents.setMetadataAuthority(1, holder);

        vm.prank(holder);
        agents.burn(1);
        assertEq(agents.metadataAuthority(1), address(0));

        // The records stay, and the owner can still write them.
        agents.setMetadata(1, "context", "retired");
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

    /// @dev Registers through the ERC-8217 adapter deployed on Base. Runs
    ///      only when AGENT_ADAPTER_FORK_URL names a Base RPC URL.
    function testRegisterAgentsWithDeployedAdapter() public {
        string memory forkUrl = vm.envOr("AGENT_ADAPTER_FORK_URL", string(""));
        if (bytes(forkUrl).length == 0) {
            vm.skip(true);
            return;
        }

        vm.createSelectFork(forkUrl);
        assertEq(block.chainid, 8453);
        address baseAdapter = 0x270d25D2c59A8bcA1B0f40ad95fF7806c0025c27;

        ERC721SeaDropAgentsWithMint forked = _deploy(baseAdapter);
        forked.setMaxSupply(10);
        forked.registerAgents(1, 2, "https://agents.example/", ".json");

        IAgentAdapterView view_ = IAgentAdapterView(baseAdapter);
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
