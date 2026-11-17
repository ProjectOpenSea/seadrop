// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC721SeaDropV3 } from "./ERC721SeaDropV3.sol";

import { ERC1155SeaDropV3 } from "./ERC1155SeaDropV3.sol";

import { ISeaDropMinter } from "./interfaces/ISeaDropMinter.sol";

import { Clones } from "openzeppelin-contracts/proxy/Clones.sol";

/**
 * @title  SeaDropTokenFactory
 * @notice Deploys v3 tokens as EIP-1167 clones and registers them with the
 *         chain's SeaDropMinter.
 *
 *         Each chain gets one factory, deployed with that chain's minter and
 *         OpenSea conduit. The factory deploys both implementations itself,
 *         so the conduit is fixed in their bytecode and every clone
 *         preapproves it. A clone's creator chooses its name, symbol and
 *         salt, and nothing else: not the conduit, not the implementation,
 *         and not the first allowed minter.
 *
 *         Clone addresses are deterministic. The CREATE2 salt hashes the
 *         creator with the creator's salt, so no one else can deploy to an
 *         address a creator predicted.
 */
contract SeaDropTokenFactory {
    /// @notice The chain's SeaDropMinter. Every clone allows it and is
    ///         registered with it.
    address public immutable minter;

    /// @notice The conduit every clone preapproves, or address(0) for
    ///         none.
    address public immutable conduit;

    /// @notice The ERC-721 implementation clones delegate to.
    address public immutable erc721Implementation;

    /// @notice The ERC-1155 implementation clones delegate to.
    address public immutable erc1155Implementation;

    /**
     * @notice A token was deployed, initialized and registered.
     *
     * @param token          The clone.
     * @param implementation The implementation it delegates to, which
     *                       tells ERC-721 from ERC-1155.
     * @param creator        The caller, who owns the token.
     * @param salt           The creator's salt.
     */
    event TokenCreated(
        address indexed token,
        address indexed implementation,
        address indexed creator,
        bytes32 salt
    );

    error MinterIsZeroAddress();

    /**
     * @param minter_  The chain's SeaDropMinter.
     * @param conduit_ OpenSea's conduit on this chain.
     */
    constructor(address minter_, address conduit_) {
        if (minter_ == address(0)) revert MinterIsZeroAddress();
        minter = minter_;
        conduit = conduit_;
        erc721Implementation = address(new ERC721SeaDropV3(conduit_));
        erc1155Implementation = address(new ERC1155SeaDropV3(conduit_));
    }

    /**
     * @notice Deploy an ERC-721 token owned by the caller.
     *
     * @param name   The token's name.
     * @param symbol The token's symbol.
     * @param salt   Any value. The same caller can't reuse one.
     */
    function createERC721(
        string calldata name,
        string calldata symbol,
        bytes32 salt
    ) external returns (address token) {
        token = Clones.cloneDeterministic(
            erc721Implementation, _cloneSalt(msg.sender, salt)
        );
        ERC721SeaDropV3(token).initialize(msg.sender, minter, name, symbol);
        _register(token, erc721Implementation, salt);
    }

    /**
     * @notice Deploy an ERC-1155 token owned by the caller.
     *
     * @param salt Any value. The same caller can't reuse one.
     */
    function createERC1155(bytes32 salt) external returns (address token) {
        token = Clones.cloneDeterministic(
            erc1155Implementation, _cloneSalt(msg.sender, salt)
        );
        ERC1155SeaDropV3(token).initialize(msg.sender, minter);
        _register(token, erc1155Implementation, salt);
    }

    /// @notice The address `createERC721` deploys to for `creator` and
    ///         `salt`.
    function predictERC721Address(address creator, bytes32 salt)
        external
        view
        returns (address)
    {
        return Clones.predictDeterministicAddress(
            erc721Implementation, _cloneSalt(creator, salt)
        );
    }

    /// @notice The address `createERC1155` deploys to for `creator` and
    ///         `salt`.
    function predictERC1155Address(address creator, bytes32 salt)
        external
        view
        returns (address)
    {
        return Clones.predictDeterministicAddress(
            erc1155Implementation, _cloneSalt(creator, salt)
        );
    }

    function _register(address token, address implementation, bytes32 salt)
        internal
    {
        ISeaDropMinter(minter).registerToken(token);
        emit TokenCreated(token, implementation, msg.sender, salt);
    }

    function _cloneSalt(address creator, bytes32 salt)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(creator, salt));
    }
}
