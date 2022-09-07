# Deployment

## SeaDrop deployment

SeaDrop will live at the same address across chains once officially deployed.

If you would like to deploy your own instance, you can do so with:

`forge create --rpc-url [rpc_url] src/SeaDrop.sol:SeaDrop --private-key [priv_key] --etherscan-api-key [api_key] --verify`

## Token deployment checklist

1. Deploy `src/ERC721SeaDrop.sol` with constructor args `string name, string symbol, address administrator, address[] allowedSeaDrop`
   1. e.g. `forge create --rpc-url [rpc_url] src/ERC721SeaDrop.sol:ERC721SeaDrop --constructor-args "TokenTest1" "TEST1" [administrator_address] \[seadrop_address\] --private-key [priv_key] --etherscan-api-key [api_key] --verify`
1. Required to be sent by token `owner`:
   1. Set the creator payout address with `token.updateCreatorPayoutAddress()`
   1. Set the token max supply with `token.setMaxSupply()`
   1. Set the contract URI with `token.setContractURI()`
   1. Set the baseURI with `token.setBaseURI()`
      1. Optionally emit an event to notify a range of token updates with `token.setBatchTokenURIs()`
1. Can be sent by token `owner` or `administrator`:
   1. Set the drop URI with `token.setDropURI()`
1. Optionally:
   1. Set the provenance hash for random metadata reveals with `token.setProvenanceHash()`
      1. Must be set before first token is minted
   1. Set an allow list drop stage with `token.setAllowListURI()`
   1. Set a token gated drop stage with `token.updateTokenGatedDrop()`
1. Set a public drop stage with `token.updatePublicDrop()`
   1. Following required to be sent by token `administrator`:
      1. Set allowed fee recipient with `token.updateAllowedFeeRecipient()`
      1. Update public drop feeBps with `token.updatePublicDrop()`
