# Deployment

## Token deployment checklist

### Required

1. Deploy `src/ERC721SeaDrop.sol` with constructor args `string name, string symbol, address administrator, address[] allowedSeaDrop`
1. Set the creator payout address with `token.updateCreatorPayoutAddress()`
1. Set the token max supply with `token.setMaxSupply()`
1. Set the contract URI with `token.setContractURI()`
1. Set the drop URI with `token.setDropURI()`
1. Set the baseURI with `token.setBaseURI()` and/or emit an event to notify a range of token updates with `token.setBatchTokenURIs()`

### Optional

1. Set the provenance hash for random metadata reveals with `token.setProvenanceHash()` before mint starts
1. Set an allow list drop stage with `token.setAllowListURI()`
1. Set a token gated drop stage with `token.updateTokenGatedDrop()`
1. Set a public drop stage with `token.updatePublicDrop()`
   1. Required to be sent by token `administrator`:
      1. Set allowed fee recipient with `token.updateAllowedFeeRecipient()`
      1. Update public drop fee with `token.updatePublicDropFee()`
