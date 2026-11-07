// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";

/// @dev A DefaultLocked, Locked, or PermanentlyLocked event.
struct LockEvent {
    bytes32 topic;
    uint256 tokenId;
    bool isLocked;
}

/**
 * @dev Builds and decodes ERC-6982 and ERC-8451 lock events so tests can
 *      compare the exact order and contents of the events a call emitted.
 */
library LockEvents {
    bytes32 internal constant DEFAULT_LOCKED = keccak256("DefaultLocked(bool)");
    bytes32 internal constant LOCKED = keccak256("Locked(uint256,bool)");
    bytes32 internal constant PERMANENTLY_LOCKED =
        keccak256("PermanentlyLocked()");

    function defaultLocked(bool isLocked)
        internal
        pure
        returns (LockEvent memory)
    {
        return LockEvent(DEFAULT_LOCKED, 0, isLocked);
    }

    function locked(uint256 tokenId, bool isLocked)
        internal
        pure
        returns (LockEvent memory)
    {
        return LockEvent(LOCKED, tokenId, isLocked);
    }

    function permanentlyLocked() internal pure returns (LockEvent memory) {
        return LockEvent(PERMANENTLY_LOCKED, 0, false);
    }

    /// @dev Returns the lock events in `logs`, in order.
    function decode(Vm.Log[] memory logs)
        internal
        pure
        returns (LockEvent[] memory events)
    {
        events = new LockEvent[](logs.length);
        uint256 count;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length == 0) continue;
            bytes32 topic = logs[i].topics[0];
            if (topic == DEFAULT_LOCKED) {
                events[count++] =
                    defaultLocked(abi.decode(logs[i].data, (bool)));
            } else if (topic == LOCKED) {
                events[count++] = locked(
                    uint256(logs[i].topics[1]), abi.decode(logs[i].data, (bool))
                );
            } else if (topic == PERMANENTLY_LOCKED) {
                events[count++] = permanentlyLocked();
            }
        }
        assembly {
            mstore(events, count)
        }
    }
}
