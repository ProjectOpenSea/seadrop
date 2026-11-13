# Drops for an existing contract

SeaDrop mints by calling `mintSeaDrop` on the token contract, so a contract deployed without SeaDrop's functions can't run a drop directly. An adapter fills that gap. It is a small contract that SeaDrop treats as the drop's token contract, and it delivers each mint on your existing ERC-721 contract (the target).

Drop stages, payout settings, mint stats and SeaDrop's events are all keyed by the adapter's address. Minted tokens are ordinary tokens of the target, so they show up in your existing collection and keep its metadata and royalties.

## Pick an adapter

Both adapters live in `src/adapters` and share `ERC721SeaDropAdapter`.

| Adapter                        | Use it when                                                                                    | How a mint is delivered                                                       |
| ------------------------------ | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `ERC721SeaDropMintAdapter`     | The target lets its owner grant another address the right to mint (a minter role or allowlist) | Calls the target's `(address to, uint256 quantity)` mint function             |
| `ERC721SeaDropTransferAdapter` | The target only lets its owner mint, but the owner can mint to any address                     | Transfers tokens the owner minted to the adapter beforehand, in arrival order |

If the target can do neither (no way to mint to another address, and no tokens left to mint), neither adapter works, because nothing outside the contract can create new tokens.

### What the target needs

For `ERC721SeaDropMintAdapter`:

- A mint function taking `(address to, uint256 quantity)` that mints `quantity` new tokens to `to`, such as `mint(address,uint256)` or `mintTo(address,uint256)`. Pass its selector to the constructor.
- A way to let the adapter's address call it, such as `grantRole(MINTER_ROLE, adapter)` or `setMinter(adapter, true)`.
- Room in the target's own max supply for the drop.

After each call the adapter checks that exactly `quantity` tokens were minted. It counts by the target's `totalSupply()` when there is one, and by the minter's balance otherwise. A function whose second argument is a token ID (OpenZeppelin's `safeMint(address,uint256)`) mints one token where the drop asked for several, so those purchases revert with `UnexpectedMintCount`. A single-token purchase passes the check, so confirm the function takes a quantity before you deploy, for example by reading the verified source. A target with another mint signature, such as `mint(address)` or a batch airdrop, needs its own subclass of `ERC721SeaDropAdapter` that implements `_deliver`.

For `ERC721SeaDropTransferAdapter`:

- The owner can mint to, or `safeTransferFrom` to, the adapter. The adapter queues a token only when the target calls its `onERC721Received`, and only for tokens that arrive from the adapter's owner, either as the operator or the sender. If the target's owner mint uses a plain `_mint`, which skips that callback, mint to the owner's wallet first and then `safeTransferFrom` each token to the adapter.
- Transfers out of the adapter are allowed. If the target restricts transfers (for example an ERC721-C transfer validator), allow the adapter as a sender.

## Deploy and configure

1. Deploy the adapter from the wallet that will run the drop. The deployer becomes the adapter's owner.

   ```sh
   # Mint adapter: the target, its mint selector, and the SeaDrop address.
   forge create src/adapters/ERC721SeaDropMintAdapter.sol:ERC721SeaDropMintAdapter \
     --rpc-url "$RPC_URL" --account deployer --broadcast \
     --constructor-args "$TARGET" "$(cast sig 'mintTo(address,uint256)')" \
     "[0x00005EA00Ac477B1030CE78506496e8C2dE24bf5]"

   # Transfer adapter: the target and the SeaDrop address.
   forge create src/adapters/ERC721SeaDropTransferAdapter.sol:ERC721SeaDropTransferAdapter \
     --rpc-url "$RPC_URL" --account deployer --broadcast \
     --constructor-args "$TARGET" "[0x00005EA00Ac477B1030CE78506496e8C2dE24bf5]"
   ```

2. Give the adapter something to deliver:
   - Mint adapter: grant the adapter's address minting rights on the target.
   - Transfer adapter: mint the drop's tokens to the adapter from the owner wallet, or send ones you hold with `safeTransferFrom`. Tokens minted without the receiver callback or sent with plain `transferFrom` aren't queued. Check `queuedTokenCount`, and get unqueued tokens back with `rescue`.

3. Set the drop's supply with `setMaxSupply`. It caps this drop only, so for a drop of your next 60 tokens set it to 60. The transfer adapter also caps the drop at the tokens it holds. Marketplaces read the max supply you set, not that cap, so set it to the number of tokens you deposit, and lower it if you `withdraw` some.

4. Configure the drop on the adapter as you would on an `ERC721SeaDrop` token, passing the SeaDrop address as `seaDropImpl`: `updateCreatorPayoutAddress`, `updatePublicDrop`, `updateSignedMintValidationParams`, `updateAllowedFeeRecipient` and `updateDropURI`. OpenSea runs public stages through `mintPublic` and allowlist stages through signed mints (`mintSigned`).

Minters call SeaDrop with the adapter's address as `nftContract`, for example `mintPublic(adapter, feeRecipient, address(0), quantity)`.

## What stays on the target

The adapter doesn't change the target's metadata or royalties. `setBaseURI` and `setRoyaltyInfo` revert with `NotSupportedByAdapter`, `baseURI` returns an empty string, and the royalty getters read the target's EIP-2981 `royaltyInfo`, or return nothing if it has none. Update metadata and royalties on the target as you do today.

`getMintStats` and `totalMinted` count this drop's mints only, so wallet limits and the drop's supply ignore tokens the target minted before.

## On OpenSea

The adapter emits `SeaDropShimDeployed(target)` when it's deployed. OpenSea uses it to show the drop on the target's collection rather than on a new collection for the adapter. Since anyone can deploy an adapter naming any contract, OpenSea first confirms that the target's owner set it up. Contact OpenSea to link the drop to your collection.

## Ending the drop

When the drop is over, revoke the adapter's minting rights on the target, or with the transfer adapter, `withdraw` any unsold tokens. Ending a stage only stops that stage: the public drop and each signed stage keep their own time windows. Revoking the adapter's rights, or removing it from the target, stops every stage at once. You can also call `updateAllowedSeaDrop` on the adapter with an empty list.
