// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Selectors for getters used in the fallback function.
bytes4 constant GET_ALLOWED_FEE_RECIPIENTS_SELECTOR = 0xd59ff1fc;
bytes4 constant GET_CREATOR_PAYOUTS_SELECTOR = 0x62337196;
bytes4 constant GET_PUBLIC_DROP_SELECTOR = 0xca7f1f86;
bytes4 constant GET_ALLOW_LIST_MERKLE_ROOT_SELECTOR = 0x82daf2a1;
bytes4 constant GET_SIGNERS_SELECTOR = 0x94cf795e;
bytes4 constant GET_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR = 0xea44b0d6;
bytes4 constant GET_TOKEN_GATED_ALLOWED_TOKENS_SELECTOR = 0x712f8460;
bytes4 constant GET_TOKEN_GATED_DROP_SELECTOR = 0x4508f9f2;
bytes4 constant GET_ALLOWED_NFT_TOKEN_ID_REDEEMED_COUNT_SELECTOR = 0x1656d82a;
bytes4 constant GET_PAYERS_SELECTOR = 0x1055d708;
bytes4 constant GET_MINT_STATS_SELECTOR = 0x840e15d4;

/// @dev Selectors for setters used in the fallback function.
bytes4 constant UPDATE_ALLOWED_SEAPORT_SELECTOR = 0x6aba5018;
bytes4 constant UPDATE_DROP_URI_SELECTOR = 0xb957d0cb;
bytes4 constant UPDATE_CREATOR_PAYOUTS_SELECTOR = 0x1ecdfb8c;
bytes4 constant UPDATE_ALLOWED_FEE_RECIPIENT_SELECTOR = 0x8e7d1e43;
bytes4 constant UPDATE_PUBLIC_DROP_SELECTOR = 0x176d67e7;
bytes4 constant UPDATE_ALLOW_LIST_SELECTOR = 0xebb4a55f;
bytes4 constant UPDATE_TOKEN_GATED_DROP_SELECTOR = 0x978960fc;
bytes4 constant UPDATE_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR = 0xe179b554;
bytes4 constant UPDATE_PAYER_SELECTOR = 0x7f2a5cca;

/// @dev Selectors for Seaport contract offerer methods used in the fallback function.
bytes4 constant PREVIEW_ORDER_SELECTOR = 0x582d4241;
bytes4 constant GENERATE_ORDER_SELECTOR = 0x98919765;
bytes4 constant RATIFY_ORDER_SELECTOR = 0xf4dd92ce;
bytes4 constant SAFE_TRANSFER_FROM_1155_SELECTOR = 0xf242432a;
bytes4 constant GET_SEAPORT_METADATA_SELECTOR = 0x2e778efc;
//bytes4 constant SUPPORTS_INTERFACE_SELECTOR = 0x01ffc9a7;