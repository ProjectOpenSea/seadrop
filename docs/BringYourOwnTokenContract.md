# Bring Your Own Token Contract

Token creators who would like to use their own token contract functionality can inherit `ERC721SeaDrop`, or for Owner and Administrator roles `ERC721PartnerSeaDrop`.

SeaDrop tokens use ERC721A for efficient multi-mint, along with additional tracking metadata like number minted by address, used for enforcing wallet limits. Please do not override or modify any SeaDrop-related functionality to remain compatible and secure with SeaDrop.
