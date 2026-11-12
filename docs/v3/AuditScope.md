# SeaDrop v3 audit scope

Draft for requesting an audit from Spearbit. SeaDrop is the contract set behind OpenSea drops. v3 replaces v2's Seaport-based design with a single minter contract per chain and thin token contracts. The design and its reasoning are in [seadrop-priv#27](https://github.com/ProjectOpenSea/seadrop-priv/issues/27), and the prototype is in [seadrop-priv#28](https://github.com/ProjectOpenSea/seadrop-priv/pull/28).

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

The repository is `ProjectOpenSea/seadrop-priv`. The commit is set at code freeze. Today's numbers come from the prototype on the `ryan/v3-research` branch.

| File                                      | nSLOC | What it does                                                                       |
| ----------------------------------------- | ----: | ---------------------------------------------------------------------------------- |
| `src/v3/SeaDropMinter.sol`                |   593 | Drop configuration, mint checks, payments and payouts for every v3 drop on a chain |
| `src/v3/ERC721SeaDropV3.sol`              |    78 | ERC-721 token (ERC721A) with max supply and a minter allowlist                     |
| `src/v3/ERC1155SeaDropV3.sol`             |    76 | ERC-1155 token (OpenZeppelin) with per-id max supply                               |
| `src/v3/SeaDropTokenV3Base.sol`           |    42 | Ownership, allowed minters, preapproved conduit and contract URI for both tokens   |
| `src/v3/interfaces/ISeaDropMinter.sol`    |   193 | Structs, events, errors and entry points of the minter                             |
| `src/v3/interfaces/ISeaDropTokenV3.sol`   |     8 | The mint entry point tokens expose to the minter                                   |
| `src/v3/interfaces/IDelegateRegistry.sol` |     9 | The delegate.xyz v2 call the minter makes                                          |

That's about 789 nSLOC of logic and 210 of interfaces. nSLOC here counts lines that aren't blank or comments.

#27 proposes two pieces the prototype doesn't have yet, and either may join the scope before the freeze:

- A factory that deploys v3 tokens as clones and registers them with the minter. Each chain's factory would be deployed with that chain's OpenSea conduit and pass it to every clone, so a clone's creator can't choose the preapproved operator.
- ERC-7201 namespaced storage in the tokens, so clones can't have storage shifted by a library update.

## Out of scope

- SeaDrop v1 and v2. v1 tokens are in scope only as targets the minter mints into (see "v1 compatibility" below).
- Dependencies: OpenZeppelin 4.9 (`EIP712`, `SignatureChecker`, `SafeERC20`, `ERC1155`), ERC721A 4.2.2, `TwoStepOwnable` from utility-contracts, and delegate.xyz's v2 registry.
- Offchain parts: OpenSea's signing service, indexing and Studio.
- A Seaport adapter. It's deferred: of 21 million SeaDrop mints in the 90 days to Nov 9, 3 went through Seaport.

## How it works

Each mint involves three roles: the payer (`msg.sender`), the eligible wallet, whose signatures and wallet limits apply, and the recipient of the tokens.

- `mint(params, authorization)`: the caller pays, and any caller can pay for any wallet. Tokens go to the eligible wallet unless the caller is the wallet or its delegate.xyz delegate for the token, who can name another recipient. A signed stage's authorization with a nonzero `sender` can only be used by that sender.
- `mintWithIntent(intent, signature, authorization)`: the eligible wallet signs an EIP-712 intent covering the mint, recipient, maximum total price, nonce and expiry, and anyone can submit it and pay.
- `ownerMint`: the token's owner mints without payment, stages or wallet limits. Owner mints still raise the token's total minted, which stage caps compare against.

Both paid paths then share `_mint`:

1. Check the stage is active and the quantity is nonzero.
2. For a signed stage, check the authorization. Its signer must be the stage's signer or a member of the stage's signer set, and it can be an EOA or an ERC-1271 contract. The authorization can override the wallet's price and limit, and a nonzero `sender` must be the caller.
3. Add the quantity to the eligible wallet's total for the token and id, which counts its mints through this minter from every stage. The stage's limit (`maxPerWallet`, or the authorization's `maxQuantity`) caps that total, as v1's `maxTotalMintableByWallet` caps the wallet's total minted. A limit of 0 means unlimited, but the mint still counts toward the total.
4. Check the currency's policy again, in case the admin changed it after the stage was set.
5. Check supply. A v1 token's total minted and max supply come from `getMintStats`. When the stage has a cap (`maxTokenSupplyForStage`), the token's total minted plus the quantity must not exceed it. A v3 token's total comes from `mintStats(id)`, read only when there's a cap, and a v1 token's from the same `getMintStats` call. A v3 token checks its own max supply when it mints.
6. Collect the payment. ETH must match the total exactly. For ERC-20s, the minter checks the balance it actually received.
7. Mint through `ISeaDropTokenV3`, or through v1's `mintSeaDrop`.
8. Pay the stage fee and the token's payout recipients, from a copy of the recipient list taken before the payment is collected. ETH goes out with 100,000 gas. Each ERC-20 transfer runs in a gas-capped call back into the minter (`pushERC20`), so one that the token rejects, that runs out of gas, or that answers with anything other than nothing or `true` is rolled back. A failed push credits the recipient, who withdraws later.
9. Emit `SeaDropMint` with the token, id, stage, payer, wallet, recipient, quantity, unit price, currency, fee recipient and fee bps.

## Trust assumptions

- The minter's admin (OpenSea, through `TwoStepOwnable`) chooses the allowed currencies, each currency's minimum fee and fee recipient, and the members of signer sets. The admin can't change a token's stages or payouts, and can't move credited balances.
- At launch the admin allows native ETH (or the chain's native token), USDC or the chain's equivalent stablecoin, the wrapped native token, and other currencies verified in OpenSea's system. The minter's received-balance check rejects fee-on-transfer tokens. Rebasing tokens aren't supported, because a credited balance could drift from what the minter holds, so the admin doesn't allow them.
- A token's owner sets its stages and payout recipients, and can mint without payment.
- A stage's signers are trusted for that stage. An authorization sets the wallet's price and limit, and a nonzero `sender` restricts who can use it.
- OpenSea's signer binds every authorization it issues to a `sender`, by default the eligible wallet itself. It names a different sender (an embedded wallet, a gift payer, a card provider's wallet) only when the request comes from a signed-in web or mobile session whose account has proven ownership of the eligible wallet by signing in with it. An API key alone never gets a different sender. Authorizations expire in about 15 minutes and carry an exact `maxQuantity`. The signing service logs the wallet, the sender and the account.
- Any caller can pay for a wallet, but only the wallet and its delegates can send the tokens anywhere else.
- A delegate can mint against the vault's eligibility and choose the recipient.
- A token's preapproved conduit can move any holder's tokens until that holder revokes it. It's fixed when the token is deployed. OpenSea's conduit differs by chain (the canonical `0x1E00…3c71` on most chains, others on chains such as Gunzilla, Monad and Abstract), so the deployer passes the chain's conduit, and for clones that deployer would be the factory.

## Where we want the most attention

1. Signatures. Check the EIP-712 domain (`SeaDrop`, version `3`) and the three typehashes. Check for replay across tokens, ids, stages, chains and minter deployments. Check ERC-1271 signers, intent nonces and `cancelIntent`.
2. Who may pay and who receives. Check the recipient rule in `mint` and `mintWithIntent`, the `sender` binding, and the delegate.xyz lookup (`checkDelegateForContract`). Anyone can pay for a wallet, so any payer can use up a wallet's limit at their own cost, and the tokens still go to the wallet. We accept that trade-off. Greenlight flagged it on #28. On signed stages OpenSea's signer binds each authorization to one `sender`, so the exposure is mostly on public stages.
3. Payments and accounting. Check exact ETH, the ERC-20 balance check, fee and split arithmetic, and the rounding remainder that goes to the last recipient. Check the 100,000-gas ETH push, the gas-capped `pushERC20` self-call and its rollback, the credit fallback for both, and `withdraw`. The minter should never hold less of a currency than it has credited.
4. Reentrancy. The paid paths make external calls: payers' ERC-20 tokens, ETH recipients, `onERC721Received` from ERC721A's `_safeMint`, `onERC1155Received` from OpenZeppelin's `_mint`, ERC-1271 signers, and the delegate registry. Check them against the minter's `nonReentrant` guard and its ordering, where the mint comes before the payout.
5. Currency policy. A currency's allowed flag and minimum fee are checked again at mint. A new fee recipient applies only to stages set afterwards.
6. Wallet limits and stage caps. Both keep v1's meaning, as levels of a running total rather than counts of one stage's mints. The minter counts each eligible wallet's mints per token and id (`mintedByWallet`), across every stage, and a stage's wallet limit caps that total, so what a wallet leaves unused in an earlier stage carries forward. Every paid mint writes the count, in limited and unlimited stages alike, so a later limited stage sees earlier mints. An authorization's `maxQuantity` replaces the stage's limit with a level of that total, as OpenSea's signer set `maxTotalMintableByWallet` in v1. A limit of 0 means unlimited. Owner mints don't count toward any wallet, and the count follows the eligible wallet, not the recipient. For v1 tokens the count starts at zero and doesn't include mints made through v1's SeaDrop, and for v3 tokens it doesn't include mints by other allowed minters. A stage's `maxTokenSupplyForStage` keeps v1's meaning: the stage stops once the token's total minted (for ERC-1155, the id's) reaches it. The minter keeps no count of its own for it. It reads the total from the token before payment, through `mintStats(id)` for v3 tokens and `getMintStats` for v1 tokens, so mints from every stage, owner mints and mints by other allowed minters all count, and what an earlier stage leaves unused carries forward. The read is a view call made under the minter's `nonReentrant` guard. A cap of 0 means none, and a cap at or below the current total closes the stage. Owner mints aren't capped. ERC-721 tokens ignore ids, so `setStage` only accepts id 0 for them, v1 tokens included.
7. v1 compatibility. A live v1 `ERC721SeaDrop` token can allow the minter with `updateAllowedSeaDrop`. The minter then calls `mintSeaDrop(recipient, quantity)`, after checking supply with `getMintStats`. v1 tokens trust their allowed SeaDrop contracts to enforce limits and fees, so the minter must not open a path that v1 SeaDrop closed. ERC-165 detection decides between the v3 and v1 interfaces.
8. Tokens. Check the minter allowlist, the max supply checks, the preapproved conduit and each holder's revocation of it, and the ownership transfer: renouncing cancels a pending transfer. ERC721A 4.2.2 keeps the transfer functions non-payable.
9. Events. Indexers rely on `SeaDropMint` and the versioned configuration events to rebuild every drop's state. Owner mints emit the reserved stage index `OWNER_MINT_STAGE`, which `setStage` rejects.

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
- The stage cap is checked before payment. An ERC-20 transfer hook during payment can't reenter this minter, but it could mint through another minter the token allows and push the total past the stage cap. The token's own max supply still holds, and only admin-allowed currencies are exposed.
- Any payer can use up a wallet's limit by paying for mints to that wallet.
- On a chain without delegate.xyz's registry, no address counts as a delegate.
- Every holder starts with the token's conduit approved for all their tokens. `setApprovalForAll(conduit, false)` revokes it for that holder, and `true` restores it. A token deployed with no conduit preapproves nothing.
- Merkle and token-gated stages are left out. OpenSea doesn't use them, and the v1 contracts that ever set one account for at most 0.2% of mints in the 90 days to Nov 9.

## Build and tests

- Foundry, with solc 0.8.38 targeting Cancun and 1,000,000 optimizer runs, without via-IR. Every network we deploy to supports Cancun's opcodes.
- Build with `forge build`, and run the v3 tests with `forge test --match-path 'test/v3/*'`.
- The prototype has 155 tests: 124 for the minter, 15 for the tokens, 9 for v1 compatibility and 7 gas snapshots. Three are fuzz tests (`testFuzz_payoutSplitsPayEverything`, `testFuzz_stageCapNeverExceeded` and `testFuzz_walletTotalNeverExceedsStageLimit`), and there are no invariant tests yet. Before the freeze we plan invariant tests for payment accounting, wallet limits and stage caps.
- A public mint costs 141k to 166k gas, against 129k for v1 and 202k for v2. Every paid mint writes the wallet's count, even in a stage with no wallet limit. That costs about 23k on a wallet's first mint of a token and id, and about 5k on later ones. Skipping it in unlimited stages would save the write, but a later limited stage couldn't see those mints. A stage cap adds about 1.1k to every mint in the stage, for the view call that reads the token's total. It writes nothing, so the first mint costs the same as later ones. The minter's runtime bytecode is 21,431 bytes, 3,145 under the EIP-170 limit.

## Deployment

One minter per chain, on every network OpenSea deploys SeaDrop to. We haven't settled whether every chain gets the same address, or who holds the admin role. We'd welcome your recommendations on both.

## Questions for Spearbit

- How soon could a review start, and does the week of Nov 23 work?
- What team size and length do you suggest for this scope?
- Is a fix review included, and how long does it take?
- What would it cost?
