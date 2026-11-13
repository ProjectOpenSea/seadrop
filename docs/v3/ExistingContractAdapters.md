# Drops for an existing contract (v3)

`SeaDropMinter` mints by calling `mintSeaDrop(to, id, quantity)` on the drop's token, so an ERC-721 deployed without SeaDrop can't run a v3 drop directly. An adapter fills that gap. It's a small contract the minter treats as the drop's token, and it delivers each mint on your existing ERC-721 (the target).

Stages, payout recipients, wallet counts and `SeaDropMint` events are keyed by the adapter's address. Minted tokens are ordinary tokens of the target, so they appear in your existing collection with its metadata and royalties.

This is the v3 version of the v1 adapters in [seadrop#234](https://github.com/ProjectOpenSea/seadrop/pull/234).

## Pick an adapter

| Adapter                          | Use it when                                                                                    | How a mint is delivered                                                     |
| -------------------------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `ERC721SeaDropV3MintAdapter`     | The target lets its owner grant another address the right to mint (a minter role or allowlist) | Calls the target's `(address to, uint256 quantity)` mint function           |
| `ERC721SeaDropV3TransferAdapter` | The target only lets its owner mint, but the owner can mint to any address                     | Transfers tokens the owner deposited in the adapter, in the order they came |

If the target can do neither, neither adapter works.

For the mint adapter, the target needs a mint function taking `(address to, uint256 quantity)` that mints `quantity` new tokens to `to`, a way to let the adapter's address call it, and room in its own max supply. After each call the adapter checks that exactly `quantity` tokens were minted, by the target's `totalSupply()` when it has one and by the recipient's balance otherwise, and reverts the whole mint if not. A function whose second argument is a token id mints one token, so purchases of two or more revert with `UnexpectedMintCount`. A single-token purchase passes the check, so confirm the function takes a quantity before you deploy, for example from the target's verified source.

For the transfer adapter, the adapter queues a token only when the target calls its `onERC721Received`, and only for tokens from the adapter's owner, as the operator or the sender. If the owner's mint skips that callback, mint to your wallet first and then `safeTransferFrom` each token to the adapter. If the target restricts transfers, allow the adapter as a sender.

## Deploy and configure

1. Deploy the adapter with the target, the chain's `SeaDropMinter` and the owner who will run the drop. The mint adapter also takes the mint function's selector, for example `$(cast sig 'mintTo(address,uint256)')`.
2. Give it something to deliver. For the mint adapter, grant its address minting rights on the target. For the transfer adapter, mint the drop's tokens to it from the owner wallet, or send them with `safeTransferFrom`, and check `queuedTokenCount`.
3. Set the drop's supply with `setMaxSupply`. It caps this drop only, so for a drop of your next 60 tokens set it to 60. The transfer adapter also caps the drop at the tokens it holds.
4. From the adapter's owner, configure the drop on the minter with the adapter as the token and id 0: `setPayoutRecipients(adapter, recipients)` and `setStage(adapter, 0, stageIndex, stage)`. The adapter only mints at id 0.

Minters call the minter with the adapter's address as the token, for example `mint(MintParams({ token: adapter, id: 0, ... }), authorization)`.

## What stays on the target

The adapter doesn't change the target's metadata or royalties. `royaltyInfo` reads the target's EIP-2981 royalty, or returns none if it has none. `mintStats` and `totalMinted` count this drop's mints only, so stage supply caps ignore tokens the target minted before.

## On OpenSea

The adapter emits `SeaDropShimDeployed(target)` when it's deployed. OpenSea confirms the target's owner set up the adapter; contact OpenSea to link the drop.

## Ending the drop

Ending a stage stops only that stage. To stop every stage at once, revoke the adapter's minting rights on the target, or call `setAllowedMinter(minter, false)` on the adapter. With the transfer adapter, `withdraw` any unsold tokens.
