// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { ERC721SeaDrop } from "../src/ERC721SeaDrop.sol";

import "openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @notice Example token that is compatible with SeaDrop.
 */
contract ExampleToken is ERC721SeaDrop {
    uint160 private immutable thisUintAddress = uint160(address(this));

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    ) ERC721SeaDrop(name, symbol, administrator, allowedSeaDrop) {}

    /**
     * @notice Returns the token URI for the token id.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return _tokenJson(tokenId);
    }

    /**
     * @notice Returns the json for the token id.
     */
    function _tokenJson(uint256 tokenId) internal view returns (string memory) {
        string memory svg;

        svg = string.concat(
            svg,
            "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 350 350'>"
            "<style>"
            "  .example { fill: white; font-family: serif; font-size: 24px; }"
            "</style>"
            "<rect width='100%' height='100%' fill='black' />"
            "<text x='50%' y='50%' dominant-baseline='middle' text-anchor='middle' style='fill: white; font-family: "
        );
        svg = string.concat(svg, _font(tokenId));
        svg = string.concat(svg, "; font-size: ");
        svg = string.concat(svg, _fontSize(tokenId));
        svg = string.concat(svg, "px;'>");
        svg = string.concat(svg, Strings.toString(tokenId));
        svg = string.concat(svg, "</text></svg>");

        string memory json = '{"name": "Test Token #';

        json = string.concat(json, Strings.toString(tokenId));
        json = string.concat(
            json,
            '", "description": "This is a test token, for trying out cool things related to NFTs!'
            ' Please note that this token has no value or warranty of any kind.\\n\\n\\"The future belongs to those who believe in'
            ' the beauty of their dreams.\\"\\n-Eleanor Roosevelt", "image_data": "'
        );
        json = string.concat(json, svg);
        json = string.concat(
            json,
            '", "attributes": [ {"trait_type": "Token ID", "value": "'
        );
        json = string.concat(json, Strings.toString(tokenId));
        json = string.concat(json, '"}, {"trait_type": "Font", "value": "');
        json = string.concat(json, _font(tokenId));
        json = string.concat(
            json,
            '"}, {"trait_type": "Font size", "value": "'
        );
        json = string.concat(json, _fontSize(tokenId));
        json = string.concat(json, '"}, {"trait_type": "Chain ID", "value": "');
        json = string.concat(json, Strings.toString(block.chainid));
        json = string.concat(json, '"}]}');

        return string.concat("data:application/json;utf8,", json);
    }

    /**
     * @notice Returns a random web safe font based on the token id.
     */
    function _font(uint256 tokenId) internal view returns (string memory) {
        uint256 roll = thisUintAddress + tokenId;

        if (roll % 9 == 0) {
            return "Garamond";
        } else if (roll % 8 == 0) {
            return "Tahoma";
        } else if (roll % 7 == 0) {
            return "Trebuchet MS";
        } else if (roll % 6 == 0) {
            return "Times New Roman";
        } else if (roll % 5 == 0) {
            return "Georgia";
        } else if (roll % 4 == 0) {
            return "Helvetica";
        } else if (roll % 3 == 0) {
            return "Courier New";
        } else {
            return "Brush Script MT";
        }
    }

    /**
     * @notice Returns a random font size based on the token id.
     */
    function _fontSize(uint256 tokenId) internal view returns (string memory) {
        return Strings.toString(((thisUintAddress * tokenId) % 200) + 10);
    }
}
