// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
function c_1396a104(bytes8 c__1396a104) pure {}
function c_true1396a104(bytes8 c__1396a104) pure returns (bool){ return true; }
function c_false1396a104(bytes8 c__1396a104) pure returns (bool){ return false; }


import { ISeaDropTokenContractMetadataUpgradeable } from "./interfaces/ISeaDropTokenContractMetadataUpgradeable.sol";

import { ERC721AUpgradeable } from "../ERC721A/contracts/ERC721AUpgradeable.sol";

import { TwoStepOwnableUpgradeable } from "../utility-contracts/src/TwoStepOwnableUpgradeable.sol";
import { ERC721ContractMetadataStorage } from "./ERC721ContractMetadataStorage.sol";

/**
 * @title  ERC721ContractMetadata
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721ContractMetadata is a token contract that extends ERC721A
 *         with additional metadata and ownership capabilities.
 */
contract ERC721ContractMetadataUpgradeable is
    ERC721AUpgradeable,
    TwoStepOwnableUpgradeable,
    ISeaDropTokenContractMetadataUpgradeable
{
    using ERC721ContractMetadataStorage for ERC721ContractMetadataStorage.Layout;
function c_723b74af(bytes8 c__723b74af) internal pure {}
function c_true723b74af(bytes8 c__723b74af) internal pure returns (bool){ return true; }
function c_false723b74af(bytes8 c__723b74af) internal pure returns (bool){ return false; }
modifier c_mod83167949{ c_723b74af(0xe25c5a0972047f35); /* modifier-post */ 
 _; }
modifier c_mod769268c4{ c_723b74af(0xbf20eddb6035ef0b); /* modifier-pre */ 
 _; }
modifier c_mod88b694a0{ c_723b74af(0x20f5f916a051498a); /* modifier-post */ 
 _; }
modifier c_mod7482c530{ c_723b74af(0x9b6a9c882066f1d2); /* modifier-pre */ 
 _; }
modifier c_modc42362c0{ c_723b74af(0x58fa60c41ffbe214); /* modifier-post */ 
 _; }
modifier c_mod9279af40{ c_723b74af(0x4ccb3b51ada937a4); /* modifier-pre */ 
 _; }
modifier c_mod87f2832d{ c_723b74af(0xb123198ad8764f78); /* modifier-post */ 
 _; }
modifier c_mod15ab1e2a{ c_723b74af(0x82f49d4b0188cac4); /* modifier-pre */ 
 _; }
modifier c_mod975375fe{ c_723b74af(0x2c4c4d69ad8668ab); /* modifier-post */ 
 _; }
modifier c_modc27c632b{ c_723b74af(0xf75d27c0ffd73aeb); /* modifier-pre */ 
 _; }

    /// @notice Throw if the max supply exceeds uint64, a limit
    //          due to the storage of bit-packed variables in ERC721A.
    error CannotExceedMaxSupplyOfUint64(uint256 newMaxSupply);

    /**
     * @notice Deploy the token contract with its name and symbol.
     */
    function __ERC721ContractMetadata_init(string memory name, string memory symbol) internal onlyInitializing {
        __ERC721A_init_unchained(name, symbol);
        __ConstructorInitializable_init_unchained();
        __TwoStepOwnable_init_unchained();
        __ERC721ContractMetadata_init_unchained(name, symbol);
    }

    function __ERC721ContractMetadata_init_unchained(string memory, string memory) internal onlyInitializing {c_723b74af(0xe2ba647946a42b4b); /* function */ 
}

    /**
     * @notice Returns the base URI for token metadata.
     */
    function baseURI() external view override returns (string memory) {c_723b74af(0xba2d899bed2a4722); /* function */ 

c_723b74af(0xf41f9a59e1b71ef6); /* line */ 
        c_723b74af(0x1bcb0d71b4121fdd); /* statement */ 
return _baseURI();
    }

    /**
     * @notice Returns the contract URI for contract metadata.
     */
    function contractURI() external view override returns (string memory) {c_723b74af(0x82974db9815fd426); /* function */ 

c_723b74af(0xd11b692d66598d24); /* line */ 
        c_723b74af(0x105a7ac6347a3a94); /* statement */ 
return ERC721ContractMetadataStorage.layout()._contractURI;
    }

    /**
     * @notice Sets the contract URI for contract metadata.
     *
     * @param newContractURI The new contract URI.
     */
    function setContractURI(string calldata newContractURI)
        external
        override
         c_modc27c632b onlyOwner c_mod975375fe 
    {c_723b74af(0x0d2f60cf76713e00); /* function */ 

        // Set the new contract URI.
c_723b74af(0x1d01d8a80236fe1a); /* line */ 
        ERC721ContractMetadataStorage.layout()._contractURI = newContractURI;

        // Emit an event with the update.
c_723b74af(0x9f9b74cf6e97d01e); /* line */ 
        c_723b74af(0x8e6a96a635a1413e); /* statement */ 
emit ContractURIUpdated(newContractURI);
    }

    /**
     * @notice Emit an event notifying metadata updates for
     *         a range of token ids.
     *
     * @param startTokenId The start token id.
     * @param endTokenId   The end token id.
     */
    function emitBatchTokenURIUpdated(uint256 startTokenId, uint256 endTokenId)
        external
         c_mod15ab1e2a onlyOwner c_mod87f2832d 
    {c_723b74af(0x9107aecd38fa6847); /* function */ 

        // Emit an event with the update.
c_723b74af(0xad7450fd30feabe2); /* line */ 
        c_723b74af(0x859bde0660c83dfa); /* statement */ 
emit TokenURIUpdated(startTokenId, endTokenId);
    }

    /**
     * @notice Returns the max token supply.
     */
    function maxSupply() public view returns (uint256) {c_723b74af(0xb9eb2077a44aecf6); /* function */ 

c_723b74af(0xe3955d7da9bc4b29); /* line */ 
        c_723b74af(0xa6034fd23068df14); /* statement */ 
return ERC721ContractMetadataStorage.layout()._maxSupply;
    }

    /**
     * @notice Returns the provenance hash.
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it is unmodified
     *         after mint has started.
     */
    function provenanceHash() external view override returns (bytes32) {c_723b74af(0x7706a4197c05f008); /* function */ 

c_723b74af(0xd4191d2ea771ebcc); /* line */ 
        c_723b74af(0xf600d35f097a0938); /* statement */ 
return ERC721ContractMetadataStorage.layout()._provenanceHash;
    }

    /**
     * @notice Sets the provenance hash and emits an event.
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it is unmodified
     *         after mint has started.
     *         This function will revert after the first item has been minted.
     *
     * @param newProvenanceHash The new provenance hash to set.
     */
    function setProvenanceHash(bytes32 newProvenanceHash) external  c_mod9279af40 onlyOwner c_modc42362c0  {c_723b74af(0x564b3b5aaf3bc08d); /* function */ 

        // Revert if any items have been minted.
c_723b74af(0xd0e57d578b36121b); /* line */ 
        c_723b74af(0x9dc1bf4fdd276f38); /* statement */ 
if (_totalMinted() > 0) {c_723b74af(0x1d4861c29a4fecf9); /* branch */ 

c_723b74af(0xb1b8e5af7d822432); /* line */ 
            revert ProvenanceHashCannotBeSetAfterMintStarted();
        }else { c_723b74af(0x9a61c5b124f13a86); /* branch */ 
}

        // Keep track of the old provenance hash for emitting with the event.
c_723b74af(0xe7cef1d82a669706); /* line */ 
        c_723b74af(0xc797b3afe993b2d7); /* statement */ 
bytes32 oldProvenanceHash = ERC721ContractMetadataStorage.layout()._provenanceHash;

        // Set the new provenance hash.
c_723b74af(0xf63f3e60e2b28949); /* line */ 
        ERC721ContractMetadataStorage.layout()._provenanceHash = newProvenanceHash;

        // Emit an event with the update.
c_723b74af(0xca90b70da73f22ea); /* line */ 
        c_723b74af(0xba3a1b71671cac13); /* statement */ 
emit ProvenanceHashUpdated(oldProvenanceHash, newProvenanceHash);
    }

    /**
     * @notice Sets the max token supply and emits an event.
     *
     * @param newMaxSupply The new max supply to set.
     */
    function setMaxSupply(uint256 newMaxSupply) external  c_mod7482c530 onlyOwner c_mod88b694a0  {c_723b74af(0xd5888fbb01ed36aa); /* function */ 

        // Ensure the max supply does not exceed the maximum value of uint64.
c_723b74af(0xd929252bdfd9a617); /* line */ 
        c_723b74af(0x8f8fe0ef0d58686d); /* statement */ 
if (newMaxSupply > 2**64 - 1) {c_723b74af(0x023b1bfce508b06a); /* branch */ 

c_723b74af(0x812daf2d04f368a9); /* line */ 
            revert CannotExceedMaxSupplyOfUint64(newMaxSupply);
        }else { c_723b74af(0xf2b3c48ef7fb8d38); /* branch */ 
}

        // Set the new max supply.
c_723b74af(0xbfde7994a5f7de3d); /* line */ 
        ERC721ContractMetadataStorage.layout()._maxSupply = newMaxSupply;

        // Emit an event with the update.
c_723b74af(0xcefeeeef4804de93); /* line */ 
        c_723b74af(0xcb3edd769d377774); /* statement */ 
emit MaxSupplyUpdated(newMaxSupply);
    }

    /**
     * @notice Sets the base URI for the token metadata and emits an event.
     *
     * @param newBaseURI The new base URI to set.
     */
    function setBaseURI(string calldata newBaseURI)
        external
        override
         c_mod769268c4 onlyOwner c_mod83167949 
    {c_723b74af(0x0fa32a59e7ed8179); /* function */ 

        // Set the new base URI.
c_723b74af(0x7456307f5093a1e6); /* line */ 
        ERC721ContractMetadataStorage.layout()._tokenBaseURI = newBaseURI;

        // Emit an event with the update.
c_723b74af(0xf81756eb494d8235); /* line */ 
        c_723b74af(0xc3857ee3eb8bb9a2); /* statement */ 
emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @notice Returns the base URI for the contract, which ERC721A uses
     *         to return tokenURI.
     */
    function _baseURI() internal view virtual override returns (string memory) {c_723b74af(0x3b1c2a688d8980a0); /* function */ 

c_723b74af(0xf8bab1e0a0336a36); /* line */ 
        c_723b74af(0x6d61c67f1a57b3a0); /* statement */ 
return ERC721ContractMetadataStorage.layout()._tokenBaseURI;
    }
}
