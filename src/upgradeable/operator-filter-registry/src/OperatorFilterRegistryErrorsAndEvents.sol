// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract OperatorFilterRegistryErrorsAndEvents {
    error CannotFilterEOAs();
    error AddressAlreadyFiltered(address operator);
    error AddressNotFiltered(address operator);
    error CodeHashAlreadyFiltered(bytes32 codeHash);
    error CodeHashNotFiltered(bytes32 codeHash);
    error OnlyAddressOrOwner();
    error NotRegistered(address registrant);
    error AlreadyRegistered();
    error AlreadySubscribed(address subscription);
    error NotSubscribed();
    error CannotUpdateWhileSubscribed(address subscription);
    error CannotSubscribeToSelf();
    error CannotSubscribeToZeroAddress();
    error NotOwnable();
    error AddressFiltered(address filtered);
    error CodeHashFiltered(address account, bytes32 codeHash);
    error CannotSubscribeToRegistrantWithSubscription(address registrant);
    error CannotCopyFromSelf();

    event RegistrationUpdated(address indexed registrant, bool indexed registered);
    event OperatorUpdated(address indexed registrant, address indexed operator, bool indexed filtered);
    event OperatorsUpdated(address indexed registrant, address[] operators, bool indexed filtered);
    event CodeHashUpdated(address indexed registrant, bytes32 indexed codeHash, bool indexed filtered);
    event CodeHashesUpdated(address indexed registrant, bytes32[] codeHashes, bool indexed filtered);
    event SubscriptionUpdated(address indexed registrant, address indexed subscription, bool indexed subscribed);
}
