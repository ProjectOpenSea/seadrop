# Bring Your Own Token Contract

Token creators who would like to use their own token contract functionality can inherit `ERC721SeaDrop`. There are also several extensions in `src/extensions` such as RandomOffset and Lockable, which can pause trading or make tokens non-transferable ([ERC-6982](https://eips.ethereum.org/EIPS/eip-6982) and [ERC-8451](https://github.com/ethereum/ERCs/pull/2084)).

SeaDrop tokens use ERC721A for efficient multiple-quantity mint, along with additional tracking metadata like number of tokens minted by address used for enforcing wallet limits. Please do not override or modify any SeaDrop-related functionality on the token like `getMintStats()` to remain compatible and secure with SeaDrop.

For deploy steps, see [SeaDrop Token Deployment](./SeaDropTokenDeployment.md).

If your contract is already deployed without SeaDrop support, an adapter can run the drop for it instead. See [Drops for an existing contract](./ExistingContractAdapters.md).
