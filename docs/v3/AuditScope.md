# SeaDrop v3 audit scope

Draft for requesting an audit from Spearbit. SeaDrop is the contract set behind OpenSea drops. v3 extends v1's minter architecture with a single minter contract per chain and thin token contracts. Scope and remaining work are in [the v3 tracker](https://github.com/ProjectOpenSea/seadrop/issues/235), and the prototype is on the [v3 source tree](../../src/v3).

Contact: Ryan Ghods.

## Timeline

The plan runs in weekly steps. These are targets, and the audit slot decides them. If the slot lands later, we'd rather move go-live than ship unaudited.

| Week | Dates (2026)  | Work                                                          |
| ---- | ------------- | ------------------------------------------------------------- |
| 0    | Nov 9 to 13   | Design, prototype, and this scope                             |
| 1    | Nov 16 to 20  | Build the final contracts. Code freeze at the end of the week |
| 2    | Nov 23 to 27  | Audit. US Thanksgiving is Nov 26                              |
| 3    | Nov 30 onward | Fix review, deploy, first drops on v3                         |

We plan to let live v1 drops opt in to v3 only after the audit's findings are resolved, since that path touches existing collections.

## In scope

The repository is `ProjectOpenSea/seadrop`, branch `main`. The audit commit will be set at code freeze. The measurements below are historical prototype measurements; remeasure the frozen commit before audit.

| File                                                   | nSLOC | What it does                                                                                                           |
| ------------------------------------------------------ | ----: | ---------------------------------------------------------------------------------------------------------------------- |
| `src/v3/SeaDropMinter.sol`                             |   578 | Drop configuration, mint checks, payments and payouts for every v3 drop on a chain                                     |
| `src/v3/SeaDropTokenFactory.sol`                       |    67 | Deploys both token implementations, then clones them at creator-salted addresses and emits its creation event          |
| `src/v3/ERC721SeaDropV3.sol`                           |    96 | ERC-721 token (ERC721A-Upgradeable) with max supply and an initializer for clones                                      |
| `src/v3/ERC721SeaDropV3Standalone.sol`                 |    14 | Direct deployment of the ERC-721 token with owner, minter, name, symbol and conduit                                    |
| `src/v3/ERC1155SeaDropV3.sol`                          |   100 | ERC-1155 token (OpenZeppelin) with per-id max supply, ids from 1, and an initializer for clones                        |
| `src/v3/ERC1155SeaDropV3Standalone.sol`                |    13 | The ERC-1155 token deployed directly, with its owner, first minter, URI and conduit set in the constructor             |
| `src/v3/SeaDropTokenV3Base.sol`                        |    86 | Ownership, allowed minters, preapproved conduit, contract URI and initialization for both tokens                       |
| `src/v3/adapters/ERC721SeaDropV3Adapter.sol`           |   117 | Base for adapters that run a drop for an existing ERC-721: allowed minters, this drop's supply and count, royalty read |
| `src/v3/adapters/ERC721SeaDropV3MintAdapter.sol`       |    44 | Adapter that calls a mint function the existing contract granted it, and checks the count minted                       |
| `src/v3/adapters/ERC721SeaDropV3TransferAdapter.sol`   |   127 | Adapter that sells tokens its owner deposited, in arrival order                                                        |
| `src/v3/interfaces/ISeaDropMinter.sol`                 |   188 | Structs, events, errors and entry points of the minter                                                                 |
| `src/v3/interfaces/ISeaDropTokenV3.sol`                |     8 | The mint entry point tokens expose to the minter                                                                       |
| `src/v3/interfaces/IDelegateRegistry.sol`              |     9 | The delegate.xyz v2 call the minter makes                                                                              |
| `src/v3/extensions/ERC721SeaDropV3Agents.sol`          |   122 | Optional agent registration and metadata extension                                                                     |
| `src/v3/interfaces/IAgentAdapter.sol`                  |     9 | Agent registration interface                                                                                           |
| `src/v3/interfaces/IERC8048Metadata.sol`               |    13 | Onchain metadata interface                                                                                             |
| `src/v3/interfaces/IERC8048TokenMetadataAuthority.sol` |     5 | Metadata authority interface                                                                                           |
| `src/v3/lib/ERC8048OnchainMetadata.sol`                |   174 | Metadata storage and writer authorization                                                                              |
| `src/v3/lib/MetadataWriterPolicy.sol`                  |   160 | Delegated metadata writes and write-once keys                                                                          |

The 19 in-scope files contain 1,930 nonblank, noncomment source lines. Recompute the count at code freeze.

The two pieces proposed for clones are now in scope. `SeaDropTokenFactory` deploys v3 tokens as EIP-1167 clones, and the tokens keep their own state in ERC-7201 namespaced storage. "Token deployment" and "Storage layout" below describe them.

The adapters in `src/v3/adapters` let an ERC-721 deployed without SeaDrop support run a v3 drop. They port the v1 adapters in public [seadrop#234](https://github.com/ProjectOpenSea/seadrop/pull/234) to the minter. "Adapters for existing contracts" below describes them.

## Agent extension

The standalone agent token and its metadata policy are also in scope:

- `src/v3/extensions/ERC721SeaDropV3Agents.sol`: ERC-8004 registration through an ERC-8217 adapter, registration bounds and duplicate-registration tracking.
- `src/v3/lib/ERC8048OnchainMetadata.sol`: collection-wide authority, holder and owner write permissions, permanent authority locks, batch writes and metadata events.
- `src/v3/lib/MetadataWriterPolicy.sol`: additional writers, holder delegation, write-once values, authority handoff and cancellation of pending ownership on renunciation.
- `src/v3/interfaces/IAgentAdapter.sol`, `IERC8048Metadata.sol` and `IERC8048TokenMetadataAuthority.sol`: the external adapter and metadata interfaces.

Review the integration with the external ERC-8217 adapter, including its upgrade authority, registration callbacks and how agent control follows NFT ownership. The external adapter implementation is a dependency, not part of this repository's audit scope. Registration and locked metadata policies can be irreversible. Check batch authorization, write-once enforcement, transfer-dependent delegates, and the ability to hand off a locked authority. The agent token is standalone; the standard clone factory does not deploy it.

The extension adds two ERC-7201 namespaces, covered by `testStorageSlots` in `test/v3/ERC721SeaDropV3Agents.t.sol`:

- `seadrop.v3.ERC8048OnchainMetadata` at `0xfc7a356b7c4fc14ef0fb4888fa6feb6db813951f1163492fbc23ac5c95c77600` holds metadata values and collection authority settings.
- `seadrop.v3.ERC721SeaDropV3Agents` at `0x81d23eda6b422c7dfc16f0a75c57549cf4ff057c8b7855458b38a2f38fc85900` holds token-to-agent registrations.

See [Agent NFTs on v3](AgentNFTs.md) for deployment and authority behavior. Audit the final extension bytecode size and the frozen interface versions alongside the minter and tokens.

## Out of scope

- SeaDrop v1 and v2. v1 tokens are in scope only as targets the minter mints into (see "v1 compatibility" below).
- Dependencies: OpenZeppelin 4.9 (`EIP712`, `SignatureChecker`, `SafeERC20`, `ERC1155`, `Clones`), ERC721A-Upgradeable 4.2.2, `TwoStepOwnable` from utility-contracts, and delegate.xyz's v2 registry.
- Offchain parts: OpenSea's signing service, indexing and Studio.
- A Seaport adapter. It's deferred: of 21 million SeaDrop mints in the 90 days to Nov 9, 3 went through Seaport.

## How it works

Each mint involves three roles: the payer (`msg.sender`), the eligible wallet, whose signatures and wallet limits apply, and the recipient of the tokens.

- `mint(params, authorization)`: the caller pays, and any caller can pay for any wallet. Tokens go to the eligible wallet unless the caller is the wallet or its delegate.xyz delegate for the token, who can name another recipient. A signed stage's authorization with a nonzero `sender` can only be used by that sender.
- `ownerMint`: the token's owner mints without payment, stages or wallet limits. Owner mints still raise the token's total minted, which stage caps compare against.

The paid mint proceeds as follows:

1. Check the stage is active and the quantity is nonzero.
2. For a signed stage, check the authorization. Its signer must be the stage's signer or a member of the stage's signer set, and it can be an EOA or an ERC-1271 contract. The authorization can override the wallet's price and limit, and a nonzero `sender` must be the caller.
3. Add the quantity to the eligible wallet's total for the token and id, which counts its mints through this minter from every stage. The stage's limit (`maxPerWallet`, or the authorization's `maxQuantity`) caps that total, as v1's `maxTotalMintableByWallet` caps the wallet's total minted. A limit of 0 means unlimited, but the mint still counts toward the total.
4. Check the currency's policy again, in case the admin changed it after the stage was set.
5. Check supply. A v1 token's total minted and max supply come from `getMintStats`. When the stage has a cap (`maxTokenSupplyForStage`), the token's total minted plus the quantity must not exceed it. A v3 token's total comes from `mintStats(id)`, read only when there's a cap, and a v1 token's from the same `getMintStats` call. A v3 token checks its own max supply when it mints.
6. Collect the payment. ETH must match the total exactly. For ERC-20s, the minter checks the balance it actually received.
7. Mint through `ISeaDropTokenV3`, or through v1's `mintSeaDrop`.
8. Pay the stage fee and the token's payout recipients, from a copy of the recipient list taken before the payment is collected. ETH goes out with 100,000 gas. Each ERC-20 transfer runs in a gas-capped call back into the minter (`pushERC20`), so one that the token rejects, that runs out of gas, or that answers with anything other than nothing or `true` is rolled back. A failed push emits `PaymentCredited` and credits the recipient, who withdraws later. The ERC-20 push budget starts at 100,000 gas and includes the four balance reads. The admin can adjust it for the chain's gas schedule. A low budget sends more payouts to credit. A high budget increases the gas a mint may need for each recipient. Withdrawals use the caller's gas.
9. Emit `SeaDropMint` with the token, id, stage, payer, wallet, recipient, quantity, unit price, currency, fee recipient and fee bps.

## Token deployment

Each chain gets one `SeaDropTokenFactory`, deployed with that chain's minter and OpenSea conduit. Its constructor deploys both token implementations, so the conduit and the factory's address are immutables in their bytecode.

- `createERC721(name, symbol, salt)` and `createERC1155(salt)` deploy an EIP-1167 clone with CREATE2, at a salt of `keccak256(abi.encode(creator, salt))`. Two creators with the same salt get different addresses, and no one can deploy to an address another creator predicted. `predictERC721Address` and `predictERC1155Address` return the address in advance.
- In the same call the factory initializes the clone, with the caller as owner and the factory's minter as the first allowed minter. The factory then emits `TokenCreated`.
- A clone's `initialize` accepts only the factory as caller, and only once. The implementations mark themselves initialized and give up ownership in their constructors, so even the factory can't initialize them.
- A clone made from the implementation outside the factory can't be initialized by anyone, so it has no owner and can't mint.

`ERC721SeaDropV3Standalone` takes `(address initialOwner, address minter, string name, string symbol, address conduit)`. Its constructor sets ownership, minter permissions and ERC721A metadata. Minting uses the same supply checks and sequential ids as a factory clone. Both standalone variants reject a zero owner or minter.

`ERC1155SeaDropV3Standalone` is the ERC-1155 token deployed directly, for when the factory isn't available. Its constructor takes `(address initialOwner, address minter, string uri, address conduit)` and sets all four in the deployment, so there is no initialization to front-run, and `initialize` always reverts. Its runtime code is the clone implementation's, so it behaves the same, but `factory` returns its deployer. Nothing onchain ties its conduit to OpenSea's, so OpenSea recognizes one by checking that its creation input is the reviewed creation code followed by the ABI-encoded constructor arguments, the conduit among them.

ERC-1155 token ids start at 1, as in SeaDrop's ERC-721s, in the clone and the standalone token. `mintSeaDrop` and `setMaxSupply` revert with `TokenIdIsZero` for id 0. The minter keeps no per-token id rules, so a stage can be set for id 0, but no mint at it succeeds.

Deploying a token costs 236k gas for the ERC-721 and 144k for the ERC-1155, including initialization, against about 2.5M for a full deployment of either contract. Each mint through a clone costs about 2.85k more than through a full deployment: 2.6k for the first access to the implementation's address, and the rest for the `DELEGATECALL`.

### Upgradeable token deployments

[`DeployUpgradeableToken.s.sol`](../../script/v3/DeployUpgradeableToken.s.sol) deploys either standard behind an OpenZeppelin 4.9 transparent proxy. Both use the existing v3 token implementation. The minter address must already contain code. Use one of these Forge script signatures:

- `deployERC721(address,address,address,string,string)` takes the initial token owner, minter, conduit, name and symbol.
- `deployERC1155(address,address,address)` takes the initial token owner, minter and conduit.

Use the returned proxy address for collection administration, minting and indexing. Each deployment has its own implementation and ProxyAdmin. The proxy calls the token initializer during construction. The implementation's immutable `factory` is its deployer.

The broadcaster owns ProxyAdmin. Token ownership transfers and renunciation leave that upgrade authority in place. ProxyAdmin ownership can be transferred separately. Before upgrading, review the replacement implementation's storage layout and verify its immutable conduit against the current one. Changing that address changes which operator receives default approval for holders. Call `ProxyAdmin.upgrade(proxy, implementation)` from the ProxyAdmin owner for a compatible implementation that needs no migration. Implementation constructors run only on the implementation and do not update proxy state.

## Storage layout

The tokens keep their own state in ERC-7201 namespaces. The tests read every field from these slots, so a layout change fails them.

| Namespace                       | Slot                                                                 | Fields                                                           |
| ------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `seadrop.v3.SeaDropTokenV3Base` | `0x1cefbe2c3ccb7feb740a1ec48f16b0ca795114b40813c3af6640cac9f1a78d00` | `initialized`, `allowedMinters`, `conduitRevoked`, `contractURI` |
| `seadrop.v3.ERC721SeaDropV3`    | `0xe88258efc68c2124d32107a295743c18ce3fcb3efcd888edc1efbbb996fd2f00` | `maxSupply`, `baseURI`                                           |
| `seadrop.v3.ERC1155SeaDropV3`   | `0x2032b18d202658b0d56f376a10c2e031b632a48d257145366b93b7ac14da9d00` | `supply` (per id: `totalMinted`, `maxSupply`), `uri`             |

Not everything could move:

- The ERC-721 now builds on ERC721A-Upgradeable 4.2.2 instead of ERC721A 4.2.2. It's the same release, transpiled from the same ERC721A commit, with its state in one hashed slot, `keccak256("ERC721A.contracts.storage.ERC721A")`, and an initializer instead of a constructor. Clones need the initializer to set the name and symbol in any case. That slot is diamond storage, which predates ERC-7201 and doesn't subtract 1 or clear the last byte, but it's just as independent of inheritance order. Its transfer functions stay non-payable. Together with the namespaced fields, the switch changed a mint's gas by under 60 either way (measured by running the implementation's code directly at a clone's address) and added about 3 KB to the ERC-721's bytecode.
- OpenZeppelin 4.9's `ERC1155` keeps balances at slot 0 and operator approvals at slot 1. No 4.9 release namespaces them: 4.9's upgradeable variant uses gaps, and namespaced storage arrived in 5.0. Moving to 5.0 would add a second major version of OpenZeppelin as a dependency for two mappings. Its URI slot (2) stays empty, since `uri` reads the namespaced URI.
- `TwoStepOwnable` from utility-contracts keeps the owner and pending owner in sequential slots: 0 and 1 in the ERC-721, 3 and 4 in the ERC-1155. Namespacing them means replacing an audited dependency with new ownership code in scope.

To be plain about what namespacing buys: an EIP-1167 clone always runs the implementation it was deployed with, so no library update can shift a deployed clone's storage, namespaced or not. A new implementation means a new factory, and old clones keep the old code. Namespacing keeps this repo's own fields fixed across future implementations and independent of base contract order, and lets the transparent proxy deployments use the same token implementations.

## Adapters for existing contracts

An adapter is a small contract that the minter treats as the drop's token. It implements `ISeaDropTokenV3`, and it delivers each mint on an existing ERC-721 (the target). Stages, payout recipients, wallet counts and `SeaDropMint` events are keyed by the adapter's address. The tokens are ordinary tokens of the target, with its metadata and royalties.

- `ERC721SeaDropV3MintAdapter` calls a `(address to, uint256 quantity)` mint function that the target's owner granted the adapter, chosen by selector at deployment. After the call it checks that exactly `quantity` tokens were minted, by the target's `totalSupply()` when the constructor finds one and by the recipient's balance otherwise, and reverts the whole mint otherwise, payment included.
- `ERC721SeaDropV3TransferAdapter` queues target tokens its owner mints or `safeTransferFrom`s to it, and each mint transfers the next queued tokens in arrival order. The drop can sell at most the lower of the max supply and the tokens queued. The owner takes back unsold tokens with `withdraw`, and unqueued ones (sent without the receiver callback) with `rescue`.

How they fit the minter:

- The adapter's owner configures the drop on the minter directly (`setStage`, `setPayoutRecipients`, `ownerMint`), since the minter checks the token's `owner()`. The v1 adapters forwarded configuration to SeaDrop. These don't need to.
- `mintStats` counts this drop's mints only, and `setMaxSupply` caps this drop only, so stage supply caps ignore tokens the target minted before. The minter counts wallet limits as for any token.
- An adapter isn't an ERC-721, so the minter doesn't limit its stages to id 0. `mintSeaDrop` rejects any other id with `IdNotZero`, so a stage at another id can't mint and can't give a wallet a second wallet limit.
- `mintSeaDrop` runs inside the minter's mint, after payment and before payout, under the minter's guard. The adapter has its own transient guard too, so a second allowed minter can't reenter it from a recipient's callback.
- `royaltyInfo` reads the target's EIP-2981 with a raw `staticcall` and decodes only 64 bytes or more, so a target with a fallback returns no royalty instead of reverting.
- The constructor emits `SeaDropShimDeployed(address indexed tokenContract)` naming the target. OpenSea confirms the target's owner set up the adapter; contact OpenSea to link the drop.

The creator deploys adapters directly. OpenSea confirms the target's owner before linking an adapter to the collection. Each adapter also has its own immutables (the target, and for the mint adapter its selector and how it counts), which a clone would have to move into storage behind an initializer. Adapters are rare enough that their deployment cost (about 1.25M gas for the mint adapter and 1.64M for the transfer adapter) doesn't matter.

A mint through the mint adapter costs about 3.4k more gas than one through a v3 clone, and through the transfer adapter about 12k more, measured in the same test with warm accounts. Neither has a preapproved conduit of its own. The transfer adapter approves no operator for the tokens it holds, but its custody depends on the target: an operator the target approves for every holder, such as a preapproved conduit, is approved for the adapter's tokens too. With OpenSea's conduit, Seaport moves a holder's tokens only for an order the holder signed or validated, and the adapter can do neither. Another channel opened on that conduit, or any other operator the target trusts, can move them, as it can any holder's.

## Trust assumptions

- The minter's admin (OpenSea, through `TwoStepOwnable`) chooses the allowed currencies, each currency's minimum fee and fee recipient, and the members of signer sets. The admin can't change a token's stages or payouts, and can't move credited balances.
- ERC-20s default to disabled. The admin can set default terms for contract addresses and override individual currencies to allow or deny them. Clearing an override restores the current default. Native currency always has its own policy. An admin can set an override before a token is deployed. `CurrencyUpdated` records the stored terms. `getCurrency` reports a non-native address as disabled until it has code, even if an override already allows it. Deployment can therefore change the effective policy without another minter event. Transfers require exact receipt on collection and exact debit and receipt on payout and withdrawal. These checks rely on truthful balances. Rebasing tokens are unsupported because credits can outlive the balance that backs them.
- A token's owner sets its stages and payout recipients, and can mint without payment.
- A stage's signers are trusted for that stage. An authorization sets the wallet's price and limit, and a nonzero `sender` restricts who can use it.
- OpenSea's signer binds every authorization it issues to a `sender`, by default the eligible wallet itself. It names a different sender (an embedded wallet, a gift payer, a card provider's wallet) only when the request comes from a signed-in web or mobile session whose account has proven ownership of the eligible wallet by signing in with it. An API key alone never gets a different sender. Authorizations expire in about 15 minutes and carry an exact `maxQuantity`. The signing service logs the wallet, the sender and the account.
- Any caller can pay for a wallet, but only the wallet and its delegates can send the tokens anywhere else.
- A delegate can mint against the vault's eligibility and choose the recipient.
- A token's preapproved conduit can move any holder's tokens until that holder revokes it. OpenSea's conduit differs by chain (the canonical `0x1E00…3c71` on most chains, others on chains such as Gunzilla, Monad and Abstract), so each chain's factory is deployed with that chain's conduit. The factory deploys the implementations with it as an immutable, so every clone preapproves it, and a creator can't choose it or change it.
- A factory deployer chooses its minter and conduit. Indexers identify OpenSea clones by the emitting factory address on the deployment chain. A third-party factory can emit the same event signature.
- Anyone can deploy an adapter naming any target. A mint adapter can only mint if the target's owner granted it the right, and a transfer adapter only sells tokens its owner deposited. OpenSea confirms the target's owner set up the adapter before showing the drop on the target's collection.
- The target's mint function trusts the adapter as a minter. Granting it lets the adapter's owner mint the target's tokens, up to the adapter's max supply, through paid stages or `ownerMint` without payment. The target's owner grants the right only to an adapter whose owner they trust, normally themselves, and revokes it when the drop ends.
- The adapter trusts the target. A target that mints the wrong count fails the mint adapter's check and reverts the mint. The target's own transfer rules, approved operators, callbacks and royalty are outside the adapter's control, so the transfer adapter's inventory is only as safe as any holder's tokens of the target.

## Where we want the most attention

1. Signatures. Check the EIP-712 domain (`SeaDrop`, version `3`) and the authorization typehash. Check for replay across tokens, ids, stages, chains and minter deployments. Check ERC-1271 signers and authorization expiry.
2. Who may pay and who receives. Check the recipient rule in `mint`, the `sender` binding, and the delegate.xyz lookup (`checkDelegateForContract`). Anyone can pay for a wallet, so any payer can use up a wallet's limit at their own cost, and the tokens still go to the wallet. We accept that trade-off. Greenlight flagged it on #28. On signed stages OpenSea's signer binds each authorization to one `sender`, so the exposure is mostly on public stages.
3. Payments and accounting. Check exact ETH, the ERC-20 balance check, fee and split arithmetic, and the rounding remainder that goes to the last recipient. Check the 100,000-gas ETH push, the gas-capped `pushERC20` self-call and its rollback, the credit fallback for both, and `withdraw`. The minter should never hold less of a currency than it has credited.
4. Reentrancy. Paid mints make external calls: payers' ERC-20 tokens, ETH recipients, `onERC721Received` from ERC721A's `_safeMint`, `onERC1155Received` from OpenZeppelin's `_mint`, ERC-1271 signers, and the delegate registry. Check them against the minter's `nonReentrant` guard and its ordering, where the mint comes before the payout.
5. Currency policy. A currency's allowed flag and minimum fee are checked again at mint. A new fee recipient applies only to stages set afterwards.
6. Wallet limits and stage caps. Both keep v1's meaning, as levels of a running total rather than counts of one stage's mints. The minter counts each eligible wallet's mints per token and id (`mintedByWallet`), across every stage, and a stage's wallet limit caps that total, so what a wallet leaves unused in an earlier stage carries forward. Every paid mint writes the count, in limited and unlimited stages alike, so a later limited stage sees earlier mints. An authorization's `maxQuantity` replaces the stage's limit with a level of that total, as OpenSea's signer set `maxTotalMintableByWallet` in v1. A limit of 0 means unlimited. Owner mints don't count toward any wallet, and the count follows the eligible wallet, not the recipient. For v1 tokens the count starts at zero and doesn't include mints made through v1's SeaDrop, and for v3 tokens it doesn't include mints by other allowed minters. A stage's `maxTokenSupplyForStage` keeps v1's meaning: the stage stops once the token's total minted (for ERC-1155, the id's) reaches it. The minter keeps no count of its own for it. It reads the total from the token before payment, through `mintStats(id)` for v3 tokens and `getMintStats` for v1 tokens, so mints from every stage, owner mints and mints by other allowed minters all count, and what an earlier stage leaves unused carries forward. The read is a view call made under the minter's `nonReentrant` guard. A cap of 0 means none, and a cap at or below the current total closes the stage. Owner mints aren't capped. ERC-721 stages and owner mints require id 0, including for v1 tokens.
7. v1 compatibility. A live v1 `ERC721SeaDrop` token can allow the minter with `updateAllowedSeaDrop`. The minter then calls `mintSeaDrop(recipient, quantity)`, after checking supply with `getMintStats`. v1 tokens trust their allowed SeaDrop contracts to enforce limits and fees, so the minter must not open a path that v1 SeaDrop closed. ERC-165 detection decides between the v3 and v1 interfaces.
8. Tokens. Check the minter allowlist, the max supply checks, the preapproved conduit and each holder's revocation of it, and the ownership transfer: renouncing cancels a pending transfer. ERC721A-Upgradeable 4.2.2 keeps the transfer functions non-payable.
9. The factory and initialization. Check that only the factory can initialize a clone, only once, and that the implementations can't be initialized. Check that the conduit can't be chosen by a creator, that CREATE2 salts can't be squatted across creators, and that each clone creation emits the predicted token address. Check the namespaced slots against "Storage layout", and that no namespaced field overlaps ERC721A-Upgradeable's slot or the sequential ones.
10. Adapters. Check the mint adapter's count check (including recipients that forward or burn tokens in their callback, and targets without `totalSupply()`), the transfer adapter's queue, `withdraw` and `rescue`, the deposit rules in `onERC721Received` and the rejection of deposits during a transfer out, the id 0 rule, and that `mintStats` counts only the adapter's own mints. Check what an adapter's owner can do on a target that granted it minting rights.
11. Events. Indexers rely on `SeaDropMint` and the versioned configuration events to rebuild every drop's state. Owner mints emit the reserved stage index `OWNER_MINT_STAGE`, which `setStage` rejects.

## Known and intended behavior

- Excess ETH is rejected, not refunded.
- A failed payout push credits the recipient instead of reverting the mint, so a bad recipient can't block minting.
- The last payout recipient receives the rounding remainder.
- A mint's proceeds follow the recipient list as it stood before the payment was collected, even if a callback during the mint, from the token's receiver or a payee, changes the list.
- The minter can't be a payout recipient or fee recipient, since nothing could withdraw what it paid itself.
- An authorization has no nonce. It can be reused until it expires, within the wallet's limit, and without a limit it can be reused freely until then.
- A wallet limit is a level of the wallet's total minted through this minter, so a limit added to a live stage includes what the wallet already minted in every stage, and a limit at or below that total closes the stage to the wallet. The total doesn't include a v1 token's mints through v1's SeaDrop, so a v1 drop that moves to the minter starts every wallet at 0.
- A stage cap is a level of the token's total minted, not a count of the stage's own mints, so a cap added to a live stage includes everything already minted, and one at or below the current total closes the stage.
- Owner mints aren't capped by stages, but they raise the total that later stage caps compare against.
- The stage cap is checked before payment. An ERC-20 transfer hook during payment can't reenter this minter, but it could mint through another minter the token allows and push the total past the stage cap. The token's own max supply still holds, including when a creator selects a currency under the open ERC-20 default.
- Any payer can use up a wallet's limit by paying for mints to that wallet.
- On a chain without delegate.xyz's registry, no address counts as a delegate.
- Every holder starts with the token's conduit approved for all their tokens. `setApprovalForAll(conduit, false)` revokes it for that holder, and `true` restores it. A token deployed with no conduit preapproves nothing.
- A creator can't reuse a salt for the same token standard. The second `create` call reverts.
- A clone made outside the factory stays uninitialized forever, with no owner.
- On a target without `totalSupply()`, the mint adapter counts by the recipient's balance, so a recipient that forwards or burns the token in `onERC721Received` makes the mint revert, with the payment refunded. Targets with `totalSupply()` count by supply, which forwarding doesn't change.
- An adapter's single-token purchase can't tell a quantity mint function from one that takes a token id, since both mint one token. Its deployer confirms the selector takes a quantity, for example from the target's verified source. Purchases of two or more catch it and revert.
- If an operator the target trusts moves a queued token out of the transfer adapter, mints stall at that token, since delivering it reverts, and `withdraw` can't pass it either. The owner withdraws the tokens queued behind it and moves the drop to a new adapter. No token is lost beyond the one the operator moved.
- A target mint that skips the receiver callback, or a plain `transferFrom` to the transfer adapter, isn't queued. The owner gets those tokens back with `rescue`.
- The transfer adapter's owner can't renounce ownership while the adapter holds any of the target's tokens, queued or not, since only the owner can get them out.
- Ending a stage stops only that stage. Revoking the adapter's minting rights on the target, or `setAllowedMinter(minter, false)` on the adapter, stops every stage at once.
- Merkle and token-gated stages are left out. OpenSea doesn't use them, and the v1 contracts that ever set one account for at most 0.2% of mints in the 90 days to Nov 9.

## Event schema

Nothing indexes v3 yet, and no v3 contract has been deployed anywhere, so the schema below ships as version 1. The original prototype changed `Stage` (wallet limits and `maxTokenSupplyForStage` took v1's meanings, `signerSetId` became `uint32`) while `CONFIG_EVENT_VERSION` stayed 1. Bumping it now would describe a version 1 that no chain ever emitted. From the first deployment on, changing a config event's fields bumps `CONFIG_EVENT_VERSION` and is coordinated with os2-core's indexer. `test/v3/SeaDropV3EventSchema.t.sol` pins every signature below and the version, and emits each event to check which fields are topics and how the data is encoded.

The configuration events carry `version` first. `SeaDropMint` and the payment events don't: their topic0 changes with any field type, and their meanings aren't expected to change.

Minter configuration events, with `version` = 1:

| Event                         | Fields, in order (indexed marked)                                                                                                                                                                                                                                                                                                         | When                                          |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| `StageUpdated`                | `uint256 version`, `address token` (indexed), `uint256 id` (indexed), `uint256 stageIndex` (indexed), `Stage stage` = (`uint96 price`, `address currency`, `uint40 startTime`, `uint40 endTime`, `uint16 feeBps`, `address feeRecipient`, `uint32 maxPerWallet`, `uint32 maxTokenSupplyForStage`, `uint32 signerSetId`, `address signer`) | A token's owner sets a stage                  |
| `PayoutRecipientsUpdated`     | `uint256 version`, `address token` (indexed), `PayoutRecipient[] recipients` = (`address recipient`, `uint16 bps`)[]                                                                                                                                                                                                                      | A token's owner sets payout recipients        |
| `ERC20PayoutGasUpdated`       | `uint256 version`, `uint256 gasLimit`                                                                                                                                                                                                                                                                                                     | The admin sets the gas budget per ERC-20 push |
| `DefaultERC20CurrencyUpdated` | `uint256 version`, `CurrencyConfig config` = (`bool allowed`, `uint16 minFeeBps`, `address feeRecipient`)                                                                                                                                                                                                                                 | The admin sets the fallback policy            |
| `CurrencyOverrideCleared`     | `uint256 version`, `address currency` (indexed)                                                                                                                                                                                                                                                                                           | The currency inherits the fallback policy     |
| `CurrencyUpdated`             | `uint256 version`, `address currency` (indexed), `CurrencyConfig config` = (`bool allowed`, `uint16 minFeeBps`, `address feeRecipient`)                                                                                                                                                                                                   | The admin sets a currency's terms             |
| `SignerSetUpdated`            | `uint256 version`, `uint32 signerSetId` (indexed), `address signer` (indexed), `bool allowed`                                                                                                                                                                                                                                             | The admin adds or removes a signer set member |

Minter mint and payment events:

| Event             | Fields, in order (indexed marked)                                                                                                                                                                                                                | When                                                                                                                                    |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| `SeaDropMint`     | `address token` (indexed), `uint256 id` (indexed), `uint256 stageIndex`, `address payer`, `address wallet` (indexed), `address recipient`, `uint256 quantity`, `uint256 unitPrice`, `address currency`, `address feeRecipient`, `uint256 feeBps` | Every mint. Owner mints use stage index `OWNER_MINT_STAGE` (`type(uint256).max`), the owner as payer and wallet, and zero price and fee |
| `PaymentCredited` | `address account` (indexed), `address currency` (indexed), `uint256 amount`                                                                                                                                                                      | A payout push failed                                                                                                                    |
| `Withdrawal`      | `address account` (indexed), `address currency` (indexed), `address to`, `uint256 amount`                                                                                                                                                        | An account withdrew its credit                                                                                                          |

Factory event:

| Event          | Fields, in order (indexed marked)                                                                          | When                                                     |
| -------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| `TokenCreated` | `address token` (indexed), `address implementation` (indexed), `address creator` (indexed), `bytes32 salt` | After a clone is deployed, initialized, in the same call |

Index `TokenCreated` from the configured factory address on each chain. Its implementation field identifies the token standard. Standalone tokens have a separate discovery path. The November 25 Base QA contracts use the earlier registry ABI at `c0ec779`; their factory also emits `TokenCreated`.

Token events: a clone's initialization emits `OwnershipTransferred(address(0), owner)` and `AllowedMinterUpdated(minter, true)`. After that the tokens emit `AllowedMinterUpdated`, `MaxSupplyUpdated` (`uint256 maxSupply` on the ERC-721, `uint256 id` (indexed) and `uint256 maxSupply` on the ERC-1155), ERC-7572's `ContractURIUpdated()`, ERC-4906's `BatchMetadataUpdate(0, type(uint256).max)` on a URI change, the ownership events and the standard ERC-721 and ERC-1155 events.

## Build and tests

- Foundry, with solc 0.8.38 targeting Cancun and 1,000,000 optimizer runs, without via-IR. Every network we deploy to supports Cancun's opcodes.
- Build with `forge build`, and run the v3 tests with `forge test --match-path 'test/v3/*'`.
- CI runs both v1 and v3 tests, including agent metadata, registration and storage-slot coverage and distinct payer/wallet/recipient event assertions. The root suite passed 653 tests across 48 suites and skipped two fork tests. Refresh these counts at code freeze. The stateful suites in `test/v3/SeaDropMinterInvariant.t.sol` and `test/v3/TransferAdapterInvariant.t.sol` check native/ERC-20 conservation, exact payout liabilities, failed withdrawals, unsolicited surplus, currency/gas policy updates, cross-stage wallet and supply accounting, rejected payment and authorization paths, and transfer adapter queue accounting. They seed or fuzz action sequences with unexpected reverts treated as failures.
- A public mint through a clone costs 144k to 169k gas, against 129k for v1 and 202k for v2. About 2.85k of that is the clone's `DELEGATECALL` (see "Token deployment"). Every paid mint writes the wallet's count, even in a stage with no wallet limit. That costs about 23k on a wallet's first mint of a token and id, and about 5k on later ones. Skipping it in unlimited stages would save the write, but a later limited stage couldn't see those mints. A stage cap adds about 1.1k to every mint in the stage, for the view call that reads the token's total. It writes nothing, so the first mint costs the same as later ones. The minter's runtime bytecode is 21,702 bytes, 2,874 under the EIP-170 limit. The ERC-721 implementation is 11,134 bytes and the ERC-1155 11,439. The factory's runtime is 2,230 bytes, and its init code, which carries both implementations, is 26,345 bytes, 22,807 under EIP-3860's limit. The mint adapter's runtime is 5,156 bytes and the transfer adapter's 8,005.

## Deployment

One minter and one token factory per chain, on every network OpenSea deploys SeaDrop to. The factory is deployed with the chain's minter and OpenSea conduit. Adapters are deployed per drop by the creator, standalone. We haven't settled whether every chain gets the same address, or who holds the admin role. We'd welcome your recommendations on both.

## Questions for Spearbit

- How soon could a review start, and does the week of Nov 23 work?
- What team size and length do you suggest for this scope?
- Is a fix review included, and how long does it take?
- What would it cost?
