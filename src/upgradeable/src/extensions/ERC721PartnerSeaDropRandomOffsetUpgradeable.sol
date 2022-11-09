// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
function c_6412f743(bytes8 c__6412f743) pure {}
function c_true6412f743(bytes8 c__6412f743) pure returns (bool){ return true; }
function c_false6412f743(bytes8 c__6412f743) pure returns (bool){ return false; }


import { ERC721PartnerSeaDropUpgradeable } from "../ERC721PartnerSeaDropUpgradeable.sol";
import { ERC721PartnerSeaDropRandomOffsetStorage } from "./ERC721PartnerSeaDropRandomOffsetStorage.sol";
import { ERC721ContractMetadataStorage } from "../ERC721ContractMetadataStorage.sol";

/**
 * @title  ERC721PartnerSeaDropRandomOffset
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721PartnerSeaDropRandomOffset is a token contract that extends
 *         ERC721PartnerSeaDrop to apply a randomOffset to the tokenURI,
 *         to enable fair metadata reveals.
 */
contract ERC721PartnerSeaDropRandomOffsetUpgradeable is ERC721PartnerSeaDropUpgradeable {
    using ERC721PartnerSeaDropRandomOffsetStorage for ERC721PartnerSeaDropRandomOffsetStorage.Layout;
    using ERC721ContractMetadataStorage for ERC721ContractMetadataStorage.Layout;
function c_22c8c15a(bytes8 c__22c8c15a) internal pure {}
function c_true22c8c15a(bytes8 c__22c8c15a) internal pure returns (bool){ return true; }
function c_false22c8c15a(bytes8 c__22c8c15a) internal pure returns (bool){ return false; }
modifier c_mod4bd05e6f{ c_22c8c15a(0x4c07426f1a753935); /* modifier-post */ 
 _; }
modifier c_mod7a763e17{ c_22c8c15a(0x5d1129c1acd597c0); /* modifier-pre */ 
 _; }

    /// @notice Revert when setting the randomOffset if already set.
    error AlreadyRevealed();

    /// @notice Revert when setting the randomOffset if the collection is
    ///         not yet fully minted.
    error NotFullyMinted();

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    function __ERC721PartnerSeaDropRandomOffset_init(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    ) internal onlyInitializing {
        __ERC721A_init_unchained(name, symbol);
        __ConstructorInitializable_init_unchained();
        __TwoStepOwnable_init_unchained();
        __ERC721ContractMetadata_init_unchained(name, symbol);
        __ReentrancyGuard_init_unchained();
        __ERC721SeaDrop_init_unchained(name, symbol, allowedSeaDrop);
        __TwoStepAdministered_init_unchained(administrator);
        __ERC721PartnerSeaDrop_init_unchained(name, symbol, administrator, allowedSeaDrop);
        __ERC721PartnerSeaDropRandomOffset_init_unchained(name, symbol, administrator, allowedSeaDrop);
    }

    function __ERC721PartnerSeaDropRandomOffset_init_unchained(
        string memory,
        string memory,
        address,
        address[] memory
    ) internal onlyInitializing {c_22c8c15a(0xd776d1c2935f71db); /* function */ 
}

    /**
     * @notice Set the random offset, for a fair metadata reveal. Only callable
     *         by the owner one time when the total number of minted tokens
     *         equals the max supply. Should be called immediately before
     *         reveal.
     */
    function setRandomOffset() external  c_mod7a763e17 onlyOwner c_mod4bd05e6f  {c_22c8c15a(0x5e38227374b7e308); /* function */ 

c_22c8c15a(0xd200ffb8b1eeb6fe); /* line */ 
        c_22c8c15a(0xd0cf920feb8452af); /* statement */ 
if (ERC721PartnerSeaDropRandomOffsetStorage.layout().revealed) {c_22c8c15a(0x205eb1a4a2b58a3d); /* branch */ 

c_22c8c15a(0x67c052ae54d07701); /* line */ 
            revert AlreadyRevealed();
        }else { c_22c8c15a(0xb27916a9a50d9f89); /* branch */ 
}
c_22c8c15a(0xa67a6302e4a2638c); /* line */ 
        c_22c8c15a(0x7e3a70d072edd654); /* statement */ 
if (_totalMinted() != ERC721ContractMetadataStorage.layout()._maxSupply) {c_22c8c15a(0x52e66a53a38d90c0); /* branch */ 

c_22c8c15a(0x5b5a6162c3db336a); /* line */ 
            revert NotFullyMinted();
        }else { c_22c8c15a(0xb2142d23057e1244); /* branch */ 
}
        // block.difficulty returns PREVRANDAO on Ethereum post-merge
        // NOTE: do not use this on other chains
        // randomOffset returns between 1 and MAX_SUPPLY
c_22c8c15a(0xa547130310373957); /* line */ 
        ERC721PartnerSeaDropRandomOffsetStorage.layout().randomOffset =
            (uint256(keccak256(abi.encode(block.difficulty))) %
                (ERC721ContractMetadataStorage.layout()._maxSupply - 1)) +
            1;
c_22c8c15a(0xf1346965a6d79b43); /* line */ 
        ERC721PartnerSeaDropRandomOffsetStorage.layout().revealed = true;
    }

    /**
     * @notice The token URI, offset by randomOffset, to enable fair metadata
     *         reveals.
     *
     * @param tokenId The token id
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {c_22c8c15a(0x28eae6efe2cd991a); /* function */ 

c_22c8c15a(0x775b666a145fcfc0); /* line */ 
        c_22c8c15a(0x9cc048ff133609de); /* statement */ 
if (!_exists(tokenId)) {c_22c8c15a(0x62bf7752d8ef0283); /* branch */ 

c_22c8c15a(0xfb478861cda0f44a); /* line */ 
            revert URIQueryForNonexistentToken();
        }else { c_22c8c15a(0x06c4efabb8bdeea5); /* branch */ 
}

c_22c8c15a(0xdc5a14d1db10c447); /* line */ 
        c_22c8c15a(0xc6e8c91bb14760ed); /* statement */ 
string memory base = _baseURI();
c_22c8c15a(0x8c192e49f22e8fda); /* line */ 
        c_22c8c15a(0x6ac4bd2ed3f864d0); /* statement */ 
if (bytes(base).length == 0) {c_22c8c15a(0xb4fc912ede10b2d2); /* branch */ 

            // If there is no baseURI set, return an empty string.
c_22c8c15a(0x5eced96644ac132d); /* line */ 
            c_22c8c15a(0x6730bec4361b0b5a); /* statement */ 
return "";
        } else {c_22c8c15a(0x22a063809643dbca); /* statement */ 
c_22c8c15a(0x82c838f1dfd720dd); /* branch */ 
if (!ERC721PartnerSeaDropRandomOffsetStorage.layout().revealed) {c_22c8c15a(0x6fde038b4816ec04); /* branch */ 

            // If the baseURI is set but the collection is not revealed yet,
            // return just the baseURI.
c_22c8c15a(0x50c404525402786c); /* line */ 
            c_22c8c15a(0xefb12d14749df6e0); /* statement */ 
return base;
        } else {c_22c8c15a(0xac519de99be4b1de); /* branch */ 

            // If the baseURI is set and the collection is revealed,
            // return the tokenURI offset by the randomOffset.
c_22c8c15a(0xded21542833ec8fc); /* line */ 
            c_22c8c15a(0x8ffd0dcb3ba9a0c5); /* statement */ 
return
                string.concat(
                    base,
                    _toString(
                        ((tokenId + ERC721PartnerSeaDropRandomOffsetStorage.layout().randomOffset) % ERC721ContractMetadataStorage.layout()._maxSupply) +
                            _startTokenId()
                    )
                );
        }}
    }
    // generated getter for ${varDecl.name}
    function randomOffset() public view returns(uint256) {
        return ERC721PartnerSeaDropRandomOffsetStorage.layout().randomOffset;
    }

    // generated getter for ${varDecl.name}
    function revealed() public view returns(bool) {
        return ERC721PartnerSeaDropRandomOffsetStorage.layout().revealed;
    }

}
