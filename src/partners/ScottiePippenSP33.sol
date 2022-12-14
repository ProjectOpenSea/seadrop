// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC2981} from "openzeppelin-contracts/interfaces/IERC2981.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {ERC721PartnerSeaDrop} from "../ERC721PartnerSeaDrop.sol";
import {ERC721SeaDrop} from "../ERC721SeaDrop.sol";

/*
                                     @@@@@@@@                                   
                                 @@@@@@@@@@@@@@@                                
                               @@@@@ @@ @  @ @@@@@                              
                              @@@@@@ @@ @  @ @@@@@@                             
                             @@@@ @@ @@ @  @ @@ @@@@                            
     @@@@@@@@@@@@@@@@@@@@@@@@@@@@ @@ @@ @ #@ @@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@    
      @@@@@@@@@@@@@@@@@@@@@@@@@@@ @@ @@ @#@@ @@ @@@@@@@@@@@@@@@@@@@@@@@@@@@     
        @@@@@                @@@@ @@ @@ @@@@ @@ @@@@@                @@@@       
         @@@@@               @@@@*@@ @@ @@@@ @@ @@@@               @@@@@        
          #@@@@    /@@@@@     @@@@@@ @@ @@@@,@@ @@@(     @@@@@    @@@@@         
            @@@@     @@@@*    @@@@@@ @@.@@@@@@@ @@@     @@@@     @@@@           
             @@@@&    &@@@     @@@@@ @@@@@@@@@@@@@     @@@@     @@@@            
               @@@@     @@@    #@@@@ @@@@@@@@@@@@@    @@@     @@@@@             
                @@@@     @@@    @@@@(@@@@@@@@@@@@    @@@     @@@@               
                 @@@@      @@    @@@@@@@@@@@@@@@@   @@      @@@@                
                   @@@      @@   @@@@@@@@@@@@@@@    @      @@@(                 
                    @@@@          @@@@@@@@@@@@@           @@@                   
                     @@@@         @@@@@@@@@@@@@         @@@@                    
                       @@@   &@@   @@@@@@@@@@@   @@@   @@@                      
                        @@@@@@@@,   @@@@@@@@@@   @@@@@@@@                       
                          @@@@@@@   @@@@@@@@@   @@@@@@@@                        
                              @@@@   @@@ @@@   @@@@                             
                               @@@@  @@@ @@@   @@@                              
                                @@@   @   @   @@@                               
                                  @@      @  @@@                                
                                   @@       .@                                  
                                    @       @                                   
                                     @     @                                    
                                          @                                     
*/

/**
 * @notice This contract uses ERC721PartnerSeaDrop,
 *         an ERC721A token contract that is compatible with SeaDrop.
 */
contract ScottiePippenSP33 is ERC721PartnerSeaDrop, IERC2981 {
    /// @notice An event emitted when the royalties address is updated.
    event RoyaltiesUpdated(address wallet);

    /// @notice An event emitted when the royalties percent is updated.
    event RoyaltiesPercentUpdated(uint256 value);

    /// @notice An event emitted when the terms URI is updated.
    event TermsURIUpdated(string newTermsURI);

    /// @notice The royalty percentage as a percent (e.g. 10 for 10%)
    uint256 _royaltyPercent;

    /// @notice The royalties wallet.
    address _royalties;

    /// @notice Store the Terms of Service URI.
    string _termsURI;

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    ) ERC721PartnerSeaDrop(name, symbol, administrator, allowedSeaDrop) {}

    /**
     * @notice Returns the royalties wallet.
     */
    function royalties() external view returns (address) {
        return _royalties;
    }

    /**
     * @notice Returns the royalties percentage.
     */
    function royaltyPercent() external view returns (uint256) {
        return _royaltyPercent;
    }

    /**
     * @notice Returns the Terms of Service URI.
     */
    function termsURI() external view returns (string memory) {
        return _termsURI;
    }

    /**
     * @notice Called with the sale price to determine how much royalty
     *         is owed and to whom.
     * @param _tokenId - the NFT asset queried for royalty information
     * @param _salePrice - the sale price of the NFT asset specified by _tokenId
     * @return receiver - address of who should be sent the royalty payment
     * @return royaltyAmount - the royalty payment amount for _salePrice
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address, uint256 royaltyAmount)
    {
        // Silence solc unused parameter warning.
        // All tokens have the same royalty.
        _tokenId;
        royaltyAmount = (_salePrice / 100) * _royaltyPercent;

        return (_royalties, royaltyAmount);
    }

    /**
     * @notice Sets the royalties wallet address.
     *
     * @param wallet The new wallet address.
     */
    function setRoyalties(address wallet) public onlyOwner {
        // Set the new royalties address
        _royalties = wallet;

        // Emit an event with the royalties update.
        emit RoyaltiesUpdated(wallet);
    }

    /**
     * @notice Sets the royalty percentage.
     *
     * @param value The value as an integer (e.g. 10 for 10%).
     */
    function setRoyaltyPercent(uint256 value) external onlyOwner {
        // Set the new royatly percent
        _royaltyPercent = value;

        // Emit an event with the royalty percent update.
        emit RoyaltiesPercentUpdated(value);
    }

    /**
     * @notice Sets the Terms of Service URI.
     *         Only callable by the owner of the contract.
     *
     * @param newTermsURI The new terms URI.
     */
    function setTermsURI(string calldata newTermsURI) external onlyOwner {
        // Set the new terms URI.
        _termsURI = newTermsURI;

        // Emit an event with the update.
        emit TermsURIUpdated(newTermsURI);
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721SeaDrop, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
