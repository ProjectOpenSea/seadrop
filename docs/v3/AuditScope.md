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
| `src/v3/SeaDropMinter.sol`                |   569 | Drop configuration, mint checks, payments and payouts for every v3 drop on a chain |
| `src/v3/ERC721SeaDropV3.sol`              |    56 | ERC-721 token (ERC721A) with max supply and a minter allowlist                     |
| `src/v3/ERC1155SeaDropV3.sol`             |    57 | ERC-1155 token (solmate) with per-id max supply                                    |
| `src/v3/SeaDropTokenV3Base.sol`           |    36 | Ownership, allowed minters and contract URI shared by both tokens                  |
| `src/v3/interfaces/ISeaDropMinter.sol`    |   202 | Structs, events, errors and entry points of the minter                             |
| `src/v3/interfaces/ISeaDropTokenV3.sol`   |     8 | The mint entry point tokens expose to the minter                                   |
| `src/v3/interfaces/IDelegateRegistry.sol` |     9 | The delegate.xyz v2 call the minter makes                                          |

That's about 718 nSLOC of logic and 219 of interfaces. nSLOC here counts lines that aren't blank or comments.

#27 proposes two pieces the prototype doesn't have yet, and either may join the scope before the freeze:

- A factory that deploys v3 tokens as clones and registers them with the minter.
- ERC-7201 namespaced storage in the tokens, so clones can't have storage shifted by a library update.

## Out of scope

- SeaDrop v1 and v2. v1 tokens are in scope only as targets the minter mints into (see "v1 compatibility" below).
- Dependencies: OpenZeppelin 4.9 (`EIP712`, `SignatureChecker`, `SafeERC20`), solmate's `ERC1155`, ERC721A 4.2.2, `TwoStepOwnable` from utility-contracts, and delegate.xyz's v2 registry.
- Offchain parts: OpenSea's signing service, indexing and Studio.
- A Seaport adapter. It's deferred: of 21 million SeaDrop mints in the 90 days to Nov 9, 3 went through Seaport.

## How it works

Each mint involves three roles: the payer (`msg.sender`), the eligible wallet, whose signatures and wallet limits apply, and the recipient of the tokens.

- `mint(params, authorization)`: the caller pays. A caller other than the eligible wallet must be its delegate.xyz delegate for the token, a payer the admin trusts, a payer the token's owner allowed, or the `sender` that a signed stage's authorization links to the wallet. Tokens go to the eligible wallet unless the caller is the wallet or its delegate.
- `mintWithIntent(intent, signature, authorization)`: the eligible wallet signs an EIP-712 intent covering the mint, recipient, maximum total price, nonce and expiry, and anyone can submit it and pay.
- `ownerMint`: the token's owner mints without payment, stages or wallet limits.

Both paid paths then share `_mint`:

1. Check the stage is active and the quantity is nonzero.
2. For a signed stage, check the authorization. Its signer must be the stage's signer or a member of the stage's signer set, and it can be an EOA or an ERC-1271 contract. The authorization can override the wallet's price and limit, and can link a `sender`.
3. Count the quantity against the wallet's limit for the stage.
4. Check the currency's policy again, in case the admin changed it after the stage was set.
5. Collect the payment. ETH must match the total exactly. For ERC-20s, the minter checks the balance it actually received.
6. Mint through `ISeaDropTokenV3`, or through v1's `mintSeaDrop` after checking supply with `getMintStats`.
7. Pay the stage fee and the token's payout recipients, from a copy of the recipient list. ETH goes out with 100,000 gas. Each ERC-20 transfer runs in a gas-capped call back into the minter (`pushERC20`), so one that the token rejects, that runs out of gas, or that answers with anything other than nothing or `true` is rolled back. A failed push credits the recipient, who withdraws later.
8. Emit `SeaDropMint` with the token, id, stage, payer, wallet, recipient, quantity, unit price, currency, fee recipient and fee bps.

## Trust assumptions

- The minter's admin (OpenSea, through `TwoStepOwnable`) chooses the allowed currencies, each currency's minimum fee and fee recipient, the members of signer sets, and the payers trusted for every token. The admin can't change a token's stages or payouts, and can't move credited balances.
- A token's owner sets its stages, payout recipients and allowed payers, and can mint without payment.
- A stage's signers are trusted for that stage. An authorization sets the wallet's price and limit, and its `sender` lets another address mint against the wallet's spot. OpenSea's signer checks offchain that one user controls both addresses.
- Trusted payers, allowed payers and linked senders can pay for a wallet, but can only mint to that wallet.
- A delegate can mint against the vault's eligibility and choose the recipient.

## Where we want the most attention

1. Signatures. Check the EIP-712 domain (`SeaDrop`, version `3`) and the three typehashes. Check for replay across tokens, ids, stages, chains and minter deployments. Check ERC-1271 signers, intent nonces and `cancelIntent`.
2. Who may pay and who receives. Check the rules in `mint` and `mintWithIntent`, the linked `sender`, the delegate.xyz lookup (`checkDelegateForContract`), and trusted and allowed payers. One rule is still an open decision. Today, a trusted payer, an allowed payer or a linked sender can use up a wallet's limit without the wallet's consent. Greenlight flagged this on #28, and we want your view.
3. Payments and accounting. Check exact ETH, the ERC-20 balance check, fee and split arithmetic, and the rounding remainder that goes to the last recipient. Check the 100,000-gas ETH push, the gas-capped `pushERC20` self-call and its rollback, the credit fallback for both, and `withdraw`. The minter should never hold less of a currency than it has credited.
4. Reentrancy. The paid paths make external calls: payers' ERC-20 tokens, ETH recipients, `onERC721Received` from ERC721A's `_safeMint`, `onERC1155Received` from solmate's `_mint`, ERC-1271 signers, and the delegate registry. Check them against the minter's `nonReentrant` guard and its ordering, where the mint comes before the payout.
5. Currency policy. A currency's allowed flag and minimum fee are checked again at mint. A new fee recipient applies only to stages set afterwards.
6. Wallet limits. They count per token, id, stage and wallet. A limit of 0 means unlimited and nothing is counted. ERC-721 tokens ignore ids, so `setStage` only accepts id 0 for them, v1 tokens included.
7. v1 compatibility. A live v1 `ERC721SeaDrop` token can allow the minter with `updateAllowedSeaDrop`. The minter then calls `mintSeaDrop(recipient, quantity)`, after checking supply with `getMintStats`. v1 tokens trust their allowed SeaDrop contracts to enforce limits and fees, so the minter must not open a path that v1 SeaDrop closed. ERC-165 detection decides between the v3 and v1 interfaces.
8. Tokens. Check the minter allowlist, the max supply checks, and the ownership transfer: renouncing cancels a pending transfer. ERC721A 4.2.2 keeps the transfer functions non-payable.
9. Events. Indexers rely on `SeaDropMint` and the versioned configuration events to rebuild every drop's state.

## Known and intended behavior

- Excess ETH is rejected, not refunded.
- A failed payout push credits the recipient instead of reverting the mint, so a bad recipient can't block minting.
- The last payout recipient receives the rounding remainder.
- A payout follows the recipient list as it stood when the payout started, even if a recipient changes the list from a callback.
- The minter can't be a payout recipient or fee recipient, since nothing could withdraw what it paid itself.
- An authorization has no nonce. It can be reused until it expires, within the wallet's limit, and without a limit it can be reused freely until then.
- A wallet limit added to a live stage starts every wallet at 0.
- On a chain without delegate.xyz's registry, no address counts as a delegate.
- Merkle and token-gated stages are left out. OpenSea doesn't use them, and the v1 contracts that ever set one account for at most 0.2% of mints in the 90 days to Nov 9.

## Build and tests

- Foundry, with solc 0.8.38 targeting Cancun and 1,000,000 optimizer runs, without via-IR. Every network we deploy to supports Cancun's opcodes.
- Build with `forge build`, and run the v3 tests with `forge test --match-path 'test/v3/*'`.
- The prototype has 128 tests: 104 for the minter, 11 for the tokens, 7 for v1 compatibility and 6 gas snapshots. One is a fuzz test (`testFuzz_payoutSplitsPayEverything`), and there are no invariant tests yet. Before the freeze we plan invariant tests for payment accounting and wallet limits.
- A public mint costs 141k to 164k gas, against 129k for v1 and 202k for v2. The minter's runtime bytecode is 21,803 bytes, 2,773 under the EIP-170 limit.

## Deployment

One minter per chain, on every network OpenSea deploys SeaDrop to. We haven't settled whether every chain gets the same address, or who holds the admin role. We'd welcome your recommendations on both.

## Questions for Spearbit

- How soon could a review start, and does the week of Nov 23 work?
- What team size and length do you suggest for this scope?
- Is a fix review included, and how long does it take?
- What would it cost?
