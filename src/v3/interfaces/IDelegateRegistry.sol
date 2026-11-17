// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

/**
 * @notice The one delegate.xyz v2 registry call SeaDropMinter makes. The
 *         registry's canonical address is
 *         0x00000000000000447e69651d841bD8D104Bed493.
 */
interface IDelegateRegistry {
    /**
     * @notice Whether `to` may act for `from` on `contract_`. True for a
     *         delegation of the whole wallet or of that contract.
     */
    function checkDelegateForContract(
        address to,
        address from,
        address contract_,
        bytes32 rights
    ) external view returns (bool);
}
