# Bring Your Own Token Contract

Token creators who would like to use their own token contract functionality can inherit `ERC721SeaDrop` or `ERC1155SeaDrop`. `ERC721SeaDrop` and `ERC1155SeaDrop` implement lockable tokens ([ERC-6982](https://eips.ethereum.org/EIPS/eip-6982) and [ERC-8451](https://github.com/ethereum/ERCs/pull/2084)): the owner can pause trading, and can make tokens permanently non-transferable before the first mint. There are also several extensions in `src/extensions` such as RandomOffset and Lockable, which picks the lock at deployment and can make it permanent at any time.

`ERC721SeaDrop` uses ERC721A for efficient multiple-quantity mint, along with additional tracking metadata like number of tokens minted by address used for enforcing wallet limits. Please do not override or modify any SeaDrop-related functionality on the token like `getMintStats()` to remain compatible and secure with SeaDrop.

For deploy steps, see [SeaDrop Token Deployment](./SeaDropTokenDeployment.md).
