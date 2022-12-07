// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC2981} from "openzeppelin-contracts/interfaces/IERC2981.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {ERC721PartnerSeaDrop} from "../ERC721PartnerSeaDrop.sol";
import {ERC721SeaDrop} from "../ERC721SeaDrop.sol";

/*
MMMMMMMMMMMMMMMMMMMMMMMMMMMMXd:kWMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMWx. ;KMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMO'   cXMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMK;    .oNMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMW0;  .,. .oNMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMNx'  c0Nk'  :0WMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMNO:. .dNMMW0c. .oKWMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMWXx;. .c0WMMMMMNk,  .lONMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMNOl'  .l0WMMMMMMMMMNk:. .;dKWMMMMMMMMMMMMMMM
MMMMMMMMMMMMMN0o,. .;xXWMMMMMMMMMMMMMW0o'  .:xXWMMMMMMMMMMMM
MMMMMMMMMMWKd;. .,o0WMMMMMMMMMMMMMMMMMMMXkc.  .ckNMMMMMMMMMM
MMMMMMMMNOc.  'lONMMMWNX0OxddddddxkOKXWMMMWXk:.  ,dKWMMMMMMM
MMMMMMWO:. .:kXWMWXOo:,..    ...    ..;lx0NMMWKd,  .oKWMMMMM
MMMMWKc. .c0WMWXkc.  .':ldkO0000Okxol;.. .,o0NMMXx;  'dNMMMM
MMMWk' .:OWMWKo'  .cx0NMMMMMMMMMMMMMMWXOo;. .;xNMMNx'  cKMMM
MMWx. .dNMMXd.  ,xXWMMMMMMMMMMMMMMMMMMMMMW0l.  ;OWMWK:  ,0WM
MWx. .kWMW0;  ,xNMMMMMMMMMMMMMMMXOKMMMMMMMMWKl. .lXMMXl. ;0M
MO' .xWMWk' .lXWMMMMMMMMMMMMMMWXc,kWMMMMMMMMMWO;  :KMMXc  cX
Xc  lNMWO' .dNMMMMMMMMMMMMMMMKx: .kWMMMMMMMMMMMK:  cXMM0' .x
O. .OMMK; .oNMMMMMMMMMMMMMMM0;.  .kWMMMMMMMMMMMMK; .oWMWo  :
o  :NMWd. ;KMMMMMMMMMMMMMMWO,    .kWMMMMMMMMMMMMWx. ,0MMO. .
:  oWMX: .oNMMMMMMMMMMMMMWO'     .kWMMMMMMMMMMMMMK; .xWMX; .
; .xWMK; .kWMMMMMMMMMMMMMNl      .kWMMMMMMMMMMMMMNc .oWMX:  
, .kWMK; .kMMMMMMMMMMMMMMNl      .kWMMMMMMMMMMMMMNc  oWMNl  
' .kWMX: .dWMMMMMMMMMMMMMNl      .kWMMMMMMMMMMMMMX: .dWMNl  
' .kWMWl  cXMMMMMMMMMMMMMNc      .kWMMMMMMMMMMMMM0' .OMMNl  
' .kWMMk. '0MMMMMMMMMMMMMNc      .kWMMMMMMMMMMMMWd. :XMMNl  
' .kWMMX:  lNMMMMMMMMMMMMNc      .kWMMMMMMMMMMMMK, .xWMMNl  
' .kWMMMO. .kWMMMMMMMMMMMNc      .kWMMMMMMMMMMMNl  :XMMMNl  
' .kWMMMWd. 'OWMMMMMMMMMMNc      .kWMMMMMMMMMMNd. ,0WMMMNl  
' .kWMMMMNl. ,0WMMMMMMMMMNc      .OMMMMMMMMMMNd. 'kWMMMMNl  
' .kWMMMMMXl. 'OWMMMMMMMMNl     .oNMMMMMMMMMNo. 'kWMMMMMNl  
' .kWMMMMMMNd. .dNMMMMMMMNl    .oNMMMMMMMMMKc  ,OWMMMMMMNl  
' .kWMMMMMMMWk' .cKWMMMMMNc  .;dNMMMMMMMMWk,  :KMMMMMMMMNl  
' .kWMMMMMMMMWKc. 'xNMMMMNc .kNWMMMMMMMWKl. .dNMMMMMMMMMNl  
' .kWMMMMMMMMMMNx' .:0WMMNl;OWMMMMMMMMNx'  :0WMMMMMMMMMMNl  
' .kWMMMMMMMMMMMMKl. .lKWW0KWMMMMMMMWO;  'xNMMMMMMMMMMMMNl  
' .kWMMMMMMMMMMMMMWO:. .dXWMMMMMMMW0c. .oKWMMMMMMMMMMMMMNl  
' .kWMMMMMMMMMMMMMMMNk,  'dXWMMMW0c. .c0WMMMMMMMMMMMMMMMNl  
' .kWMMMMMMMMMMMMMMMMMNx'  'xXNKl. .:OWMMMMMMMMMMMMMMMMMNl  
' .kWMMMMMMMMMMMMMMMMMMMXd'  .,. .:kNMMMMMMMMMMMMMMMMMMMNl  
' .kWMMMMMMMMMMMMMMMMMMMMWk.     :KMMMMMMMMMMMMMMMMMMMMMNl  
' .kWMMMMMMMMMMMMMMMMMMWKo. .,;.  ,xNMMMMMMMMMMMMMMMMMMMNl  
' .kWMMMMMMMMMMMMMMMMWKo. .:kNWXd'  ,xNMMMMMMMMMMMMMMMMMNl  
' .kWMMMMMMMMMMMMMMMXd. .;kNMMMMMXd'  ;kNMMMMMMMMMMMMMMMNl  
' .kWMMMMMMMMMMMMMNx'  ,xNMMMMMMMMWXo. .c0WMMMMMMMMMMMMMNl  
' .kWMMMMMMMMMMMWO:  'dXMMMMMMMMMMMMW0c. .oKMMMMMMMMMMMMNl  
' .kWMMMMMMMMMMXo. .lKWMMMMMMMMMMMMMMMWO;  ,kNMMMMMMMMMMNl  
' .kWMMMMMMMMWO;  ;OWMMNKXMMMMMMMMMMMMMMXd. .lXMMMMMMMMMNl  
' .kWMMMMMMMNd. .oXMMMNo;OMMMMMMMMMMMMMMMW0:  ,OWMMMMMMMNl  
' .kWMMMMMMXl. 'kWMMMXl..OMMMMMMMMWKkxkkxOXXo. .kWMMMMMMNl  
' .kWMMMMMXc  ;0WMMMKc  .OMMMMMMMMWo.    .xWNx. .xWMMMMMNl  
' .kWMMMMXc  ;KMMMM0;   .OMMMMMMMMWo     .xWMWx. .xWMMMMNl  
' .kWMMMNo. ;KMMMWO,    .OMMMMMMMMWo     .xWMMWx. 'OMMMMNl  
' .kWMMWk. .OMMMMXc     .OMMMMMMMMWo     .xWMMMNo. ;KMMMNl  
' .kWMMX: .oNMMMMX:     .OMMMMMMMMWo     .xWMMMMK; .dWMMNl  
' .kWMMx. ,KMMMMMX:     .OMMMMMMMMWo     .xWMMMMWx. ;KMMNc  
' .kWMWl  lNMMMMMX:     .OMMMMMMMMWo     .xWMMMMM0, .kMMNc  
' .kWMX; .xWMMMMMX:     .OMMMMMMMMWo     .xWMMMMMX: .dWMNl  
, .kWMK; .kMMMMMMX:     .OMMMMMMMMWo     .xWMMMMMNl  oWMNl  
; .dWMK; .xWMMMMMX:     .OMMMMMMMMWd.    .xWMMMMMXc  oWMX:  
c  oWMNc  oNMMMMMNl     .dWMMMMMMMX:     .OMMMMMMK, .xMMK, .
d. :XMWx. ,0MMMMMMO.     .lkKKKK0x;      :XMMMMMWx. ,KMMO. '
O' .kMMX:  cXMMMMMNd.       .....       ,OMMMMMM0, .dWMNl  :
Nl  cXMM0, .lXMMMMMNk,                .c0WMMMMW0,  lNMMO. .k
M0, .oNMW0,  :0WMMMMMNkc,..       .';o0WMMMMMNk' .lXMMK;  lN
MWk. .dNMMKc. .dXMMMMMMMWX0OOOOOO0KXWMMMMMMW0c. .dNMMK:  :KM
MMWk' .lXMMNk,  'l0NMMMMMMMMMMMMMMMMMMMMWXk:. .c0WMWO;  :KMM
MMMW0;  ,kNMMNx;. .;okKNMMMMMMMMMMMMWN0xc'  .l0WMWXo. .lXMMM
MMMMMXo. .;kNMMN0o;.  .,:lodxkkkxdoc;'.  .:xKWMWKo'  ;kWMMMM
MMMMMMWKo.  ,dKWMMWKko:,...      ...';cdOXWMMNOc.  ;xNMMMMMM
MMMMMMMMWKd,  .:xXWMMMWNXK0OkxxkkO0KNWWMMMN0o,. .:kNMMMMMMMM
MMMMMMMMMMMNkc.  .ckXWMMMMMMMMMMMMMMMMMWKd;. .,o0WMMMMMMMMMM
MMMMMMMMMMMMMWXx:.  'l0WMMMMMMMMMMMMMNk:.  'lONMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMWKd;. .:kNMMMMMMMMWXd'  .ckNMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMNOc. .;OWMMMMMXd'  'dKWMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMW0l. .lXMMWO;  'dXMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMWO;  ;kKd. .lKWMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMXc  ... .xNMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMXc    .xWMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMK;   lNMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMWk'.:KMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMNkoOMMMMMMMMMMMMMMMMMMMMMMMMMMMM
*/

/**
 * @notice This contract uses ERC721PartnerSeaDrop,
 *         an ERC721A token contract that is compatible with SeaDrop.
 */
contract TheImmortalPass is ERC721PartnerSeaDrop, IERC2981 {
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
