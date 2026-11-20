# Token Deployment

Example scripts deploy and configure a token, then mint through Seaport: [DeployAndConfigure721ExampleToken.s.sol](../script/DeployAndConfigure721ExampleToken.s.sol) for ERC-721 and [DeployAndConfigure1155ExampleToken.s.sol](../script/DeployAndConfigure1155ExampleToken.s.sol) for ERC-1155. Run one with `forge script script/DeployAndConfigure1155ExampleToken.s.sol --rpc-url ${RPC_URL} --broadcast -vvvv --private-key ${PK} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify --retries 10`.

## ERC1155SeaDrop and ERC721SeaDrop

Both tokens have one owner role, assigned to the deployer, that can call every method below.

1. Deploy a configurer (`ERC1155SeaDropConfigurer` or `ERC721SeaDropConfigurer`), then the token with constructor args `address allowedConfigurer, address allowedSeaport, string name, string symbol`.
1. Set the max supply with `token.setMaxSupply()`, per token id for ERC-1155.
1. Set the creator payouts with `token.updateCreatorPayouts()`.
1. Allow a fee recipient with `token.updateAllowedFeeRecipient()`.
1. Set the contract URI with `token.setContractURI()` and the base URI with `token.setBaseURI()`.
1. Optionally:
   1. Set the provenance hash for random metadata reveals with `token.setProvenanceHash()`, before minting starts. On ERC-721 it can't change after the first mint. On ERC-1155 it can be set only once, even before minting, so set it carefully.
   1. Set an allow list with `token.updateAllowList()`.
   1. Add server-side signers with `token.updateSigner()`.
   1. Allow payers who can mint for someone else with `token.updatePayer()`.
1. Set one or more public drops with `token.updatePublicDrop()`. ERC-1155 drops take an index, so a token can have several.
1. Set the drop URI with `token.updateDropURI()`. See [Format of Drop URI](#format-of-drop-uri).

The configurer's `multiConfigure(token, config)` sets any of these in one transaction, and it can also mint to the owner.

## Specifications

### Format of Drop URI

Like `tokenURI`, the drop URI points to the drop's metadata and its stages, either as onchain data or as an external URI such as IPFS.

#### Example

```json
{
  "name": "An Example Drop",
  "description": "This is the description for this example drop.",
  "stages": [
    {
      "name": "My Public Stage",
      "description": "My public stage description.",
      "uuid": "ecae5ad4-fa40-4e79-856b-ec304c3ea5d4",
      "isPublic": true,
      "mintPrice": 1000000000000000000,
      "maxTotalMintableByWallet": 50,
      "maxTokenSupplyForStage": 5000,
      "startTime": 1659045594,
      "endTime": 1659045594,
      "feeBps": 500
    },
    {
      "name": "My Private Allow List Stage",
      "description": "My private stage description",
      "uuid": "07e7a791-42ad-46e6-968a-564acf0c06dc",
      "isPublic": false,
      "mintPrice": 1000000000000000,
      "maxTotalMintableByWallet": 5,
      "maxTokenSupplyForStage": 1000,
      "startTime": 1659043594,
      "endTime": 1659044594,
      "feeBps": 500
    }
  ]
}
```

#### JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "type": "object",
  "properties": {
    "name": {
      "type": "string"
    },
    "description": {
      "type": "string"
    },
    "stages": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          },
          "description": {
            "type": "string"
          },
          "uuid": {
            "type": "string"
          },
          "isPublic": {
            "type": "boolean"
          },
          "allowListURI": {
            "type": "string"
          },
          "allowedTokenAddresses": {
            "type": "array",
            "items": {
              "type": "string"
            }
          },
          "mintPrice": {
            "type": "integer"
          },
          "maxTotalMintableByWallet": {
            "type": "integer"
          },
          "maxTokenSupplyForStage": {
            "type": "integer"
          },
          "startTime": {
            "type": "integer"
          },
          "endTime": {
            "type": "integer"
          },
          "feeBps": {
            "type": "integer"
          }
        }
      }
    }
  }
}
```

### Format of Allow List URI

The allow list may be optionally encrypted with PGP when emitted with `updateAllowList()` to retain privacy. The OpenSea public key is available [here](https://opensea.io/.well-known/allowlist-pubkeys/mainnet/ALLOWLIST_ENCRYPTION_KEY_0.txt), although it may be rotated in the future, so please ask an OpenSea team member if it is the right key to use at the time of update.

#### Example

```json
[
  {
    "address": "0xf0E16c071E2cd421974dCb76d9af4DeDB578E059",
    "mintPrice": 1000000000000000000,
    "maxTotalMintableByWallet": 10,
    "startTime": 1659045594,
    "endTime": 1659045594,
    "dropStageIndex": 1,
    "maxTokenSupplyForStage": 1000,
    "feeBps": 1000,
    "restrictFeeRecipients": true
  },
  {
    "address": "0x829bd824b016326a401d083b33d092293333a830",
    "mintPrice": 1000000000000000000,
    "maxTotalMintableByWallet": 5,
    "startTime": 1659045594,
    "endTime": 1659045594,
    "dropStageIndex": 2,
    "maxTokenSupplyForStage": 500,
    "feeBps": 1250,
    "restrictFeeRecipients": false
  }
]
```

#### JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "type": "object",
  "properties": {
    "address": {
      "type": "string"
    },
    "mintPrice": {
      "type": "integer"
    },
    "maxTotalMintableByWallet": {
      "type": "integer"
    },
    "startTime": {
      "type": "integer"
    },
    "endTime": {
      "type": "integer"
    },
    "dropStageIndex": {
      "type": "integer"
    },
    "maxTokenSupplyForStage": {
      "type": "integer"
    },
    "feeBps": {
      "type": "integer"
    },
    "restrictFeeRecipients": {
      "type": "boolean"
    }
  }
}
```
