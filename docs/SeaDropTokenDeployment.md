# Token Deployment

An example script to deploy a token contract is located at [DeployAndConfigureExampleToken.s.sol](../script/DeployAndConfigureExampleToken.s.sol). It can be run with `forge script script/DeployAndConfigureExampleToken.s.sol --rpc-url ${RPC_URL} --broadcast -vvvv --private-key ${PK} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify --retries 10`

### ERC721SeaDrop

`ERC721SeaDrop` contains only an Owner role (assigned to the deployer of the contract) that has authorization for all methods.

1. Deploy `src/ERC721SeaDrop.sol` with constructor args `string name, string symbol, address[] allowedSeaDrop`
   1. e.g. `forge create --rpc-url ${RPC_URL} src/ERC721SeaDrop.sol:ERC721SeaDrop --constructor-args "TokenTest1" "TEST1" \[${SEADROP_ADDRESS}\] --private-key ${PK} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify`
1. Set the token max supply with `token.setMaxSupply()`
1. Set the creator payout address with `token.updateCreatorPayoutAddress()`
1. Set the contract URI with `token.setContractURI()`
1. Set the base URI with `token.setBaseURI()`
1. Optionally:
   1. Set the provenance hash for random metadata reveals with `token.setProvenanceHash()`
      1. Must be set before first token is minted
   1. Set an allow list drop stage with `token.updateAllowList()`
   1. Set a token gated drop stage with `token.updateTokenGatedDrop()`
   1. Add server-side signers with `token.updateSignedMintValidationParams()`
1. Set a public drop stage with `token.updatePublicDrop()`
1. Set the drop URI with `token.updateDropURI()`
   1. See [Format of Drop URI](#format-of-drop-uri)

## Specifications

### Format of Drop URI

Follows the pattern of `tokenURI` — could be either on-chain data blob or external URI (IPFS) — that contains the metadata related to the drop and corresponding drop stages.

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
