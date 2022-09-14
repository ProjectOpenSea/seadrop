# Provenance Hash

The provenance hash is an optional way for token creators to show that they have not altered their random token metadata since minting started. It can only be set before the first item is minted, and afterwards is expected to match the hash of the metadata.

We recommend token creators to set their provenance hash to the keccak256 hash of the ipfs hash of the folder with the metadata inside as expected to be returned by `tokenURI()`.

To generate consistent ipfs hashes, we recommend to use CID version 1 and sha2-256, as shown below:

```console
❯ brew install ipfs

❯ ipfs add -Qr --only-hash --cid-version=1 --hash=sha2-256 metadata/json
bafybeiawolpr2o2b33js3bvpzt2buvrp6b3xdor45u44qybkhgvqv46pqq

❯ cast keccak $(ipfs add -Qr --only-hash --cid-version=1 --hash=sha2-256 metadata/json)
0xa61351a696813e65b2a71768ca1f5ad69f1f5515b93978cede59b82628a29509
```

If you don't have foundry for `cast`, you can use [this keccak256 tool](https://keccak-256.cloxy.net/) to input the ipfs hash for the provenance hash output.

The provenance hash can be set on the token contract by the owner with `setProvenanceHash()`.
