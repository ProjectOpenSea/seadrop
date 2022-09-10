// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { ERC721SeaDrop } from "../src/ERC721SeaDrop.sol";

import "openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @notice Example token with on-chain metadata that is compatible
 *         with SeaDrop.
 */
contract ExampleToken is ERC721SeaDrop {
    /// @notice Store the int representation of this address as a
    ///         seed for its tokens' randomized output.
    uint160 private immutable thisUintAddress = uint160(address(this));

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) {}

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

        string memory rect = _randomRect(tokenId);
        string memory poly = _randomPolygon(tokenId);
        string memory circle = _randomCircle(tokenId);

        svg = string.concat(
            svg,
            "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 350 350'>"
            "<rect width='100%' height='100%' style='fill:"
        );
        svg = string.concat(svg, _randomColor(tokenId, true));
        svg = string.concat(
            svg,
            "' /><text x='50%' y='50%' dominant-baseline='middle' text-anchor='middle' style='fill:"
        );
        svg = string.concat(svg, _randomColor(tokenId + 1, false));
        svg = string.concat(svg, ";font-family:");
        svg = string.concat(svg, _font(tokenId));
        svg = string.concat(svg, ";font-size:");
        svg = string.concat(svg, _fontSize(tokenId));
        svg = string.concat(svg, "px;");
        svg = string.concat(svg, _randomStyle(tokenId, 1));
        svg = string.concat(svg, "'>");
        svg = string.concat(svg, Strings.toString(tokenId));
        svg = string.concat(svg, "</text>");
        svg = string.concat(svg, rect);
        svg = string.concat(svg, poly);
        svg = string.concat(svg, circle);
        svg = string.concat(svg, "</svg>");

        string memory json = '{"name": "Token #';

        json = string.concat(json, Strings.toString(tokenId));
        json = string.concat(
            json,
            '", "description": "This is an example test token, for trying out cool things related to NFTs :)'
            ' Please note that this token has no value or warranty of any kind.\\n\\n\\"The future'
            ' belongs to those who believe in the beauty of their dreams.\\"\\n-Eleanor Roosevelt", "image_data": "'
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
        json = string.concat(
            json,
            '"}, {"trait_type": "Rectangle", "value": "'
        );
        json = string.concat(json, _returnYesOrNo(rect));
        json = string.concat(json, '"}, {"trait_type": "Triangle", "value": "');
        json = string.concat(json, _returnYesOrNo(poly));
        json = string.concat(json, '"}, {"trait_type": "Circle", "value": "');
        json = string.concat(json, _returnYesOrNo(circle));
        json = string.concat(json, '"}, {"trait_type": "Chain ID", "value": "');
        json = string.concat(json, Strings.toString(block.chainid));
        json = string.concat(json, '"}]}');

        return string.concat("data:application/json;utf8,", json);
    }

    /**
     * @notice Returns "No" if the input string is empty, otherwise "Yes",
     *         for formatting metadata traits.
     */
    function _returnYesOrNo(string memory input)
        internal
        pure
        returns (string memory)
    {
        return bytes(input).length == 0 ? "No" : "Yes";
    }

    /**
     * @notice Returns a random web safe font based on the token id.
     */
    function _font(uint256 tokenId) internal view returns (string memory) {
        uint256 roll = (thisUintAddress / tokenId) << 1;
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
        uint256 roll = (thisUintAddress / tokenId) << 2;
        return Strings.toString((roll % 180) + 12);
    }

    /**
     * @notice Returns a random color based on the token id.
     */
    function _randomColor(uint256 tokenId, bool onlyPastel)
        internal
        view
        returns (string memory)
    {
        uint256 roll = (thisUintAddress / tokenId) << 3;
        string memory color = "rgb(";
        uint256 pastelBase = onlyPastel == true ? 127 : 0;
        uint256 r = ((roll << 1) % (255 - pastelBase)) + pastelBase;
        uint256 g = ((roll << 2) % (255 - pastelBase)) + pastelBase;
        uint256 b = ((roll << 3) % (255 - pastelBase)) + pastelBase;
        color = string.concat(color, Strings.toString(r));
        color = string.concat(color, ", ");
        color = string.concat(color, Strings.toString(g));
        color = string.concat(color, ", ");
        color = string.concat(color, Strings.toString(b));
        color = string.concat(color, ")");
        return color;
    }

    /**
     * @notice Returns a random rectangle...sometimes.
     */
    function _randomRect(uint256 tokenId)
        internal
        view
        returns (string memory)
    {
        uint256 roll = (thisUintAddress / tokenId) << 4;
        if (roll % 3 != 0) return "";
        string memory rect = "<rect x='";
        uint256 x = (roll << 1) % 301;
        uint256 y = (roll << 2) % 302;
        uint256 width = (roll << 3) % 303;
        uint256 height = (roll << 4) % 303;
        rect = string.concat(rect, Strings.toString(x));
        rect = string.concat(rect, "' y='");
        rect = string.concat(rect, Strings.toString(y));
        rect = string.concat(rect, "' width='");
        rect = string.concat(rect, Strings.toString(width));
        rect = string.concat(rect, "' height='");
        rect = string.concat(rect, Strings.toString(height));
        rect = string.concat(rect, "' style='");
        rect = string.concat(rect, _randomStyle(tokenId, 3));
        rect = string.concat(rect, "' />");
        return rect;
    }

    /**
     * @notice Returns a random polygon...sometimes.
     */
    function _randomPolygon(uint256 tokenId)
        internal
        view
        returns (string memory)
    {
        uint256 roll = (thisUintAddress / tokenId) << 5;
        if (roll % 5 != 0) return "";
        string memory poly = "<polygon points='";
        uint256 x1 = (roll << 1) % 301;
        uint256 y1 = (roll << 2) % 302;
        uint256 x2 = (roll << 3) % 303;
        uint256 y2 = (roll << 4) % 304;
        uint256 x3 = (roll << 5) % 305;
        uint256 y3 = (roll << 6) % 306;
        poly = string.concat(poly, Strings.toString(x1));
        poly = string.concat(poly, ",");
        poly = string.concat(poly, Strings.toString(y1));
        poly = string.concat(poly, " ");
        poly = string.concat(poly, Strings.toString(x2));
        poly = string.concat(poly, ",");
        poly = string.concat(poly, Strings.toString(y2));
        poly = string.concat(poly, " ");
        poly = string.concat(poly, Strings.toString(x3));
        poly = string.concat(poly, ",");
        poly = string.concat(poly, Strings.toString(y3));
        poly = string.concat(poly, "' style='");
        poly = string.concat(poly, _randomStyle(tokenId, 5));
        poly = string.concat(poly, "' />");
        return poly;
    }

    /**
     * @notice Returns a random circle...sometimes.
     */
    function _randomCircle(uint256 tokenId)
        internal
        view
        returns (string memory)
    {
        uint256 roll = (thisUintAddress / tokenId) << 6;
        if (roll % 7 != 0) return "";
        string memory circle = "<circle cx='";
        uint256 cx = (roll << 1) % 300;
        uint256 cy = (roll << 2) % 300;
        uint256 r = (roll << 3) % 150;
        circle = string.concat(circle, Strings.toString(cx));
        circle = string.concat(circle, "' cy='");
        circle = string.concat(circle, Strings.toString(cy));
        circle = string.concat(circle, "' r='");
        circle = string.concat(circle, Strings.toString(r));
        circle = string.concat(circle, "' style='");
        circle = string.concat(circle, _randomStyle(tokenId, 7));
        circle = string.concat(circle, "' />");
        return circle;
    }

    /**
     * @notice Returns a random style of fill color, fill opacity,
     *         stroke width, stroke opacity, and dasharray.
     */
    function _randomStyle(uint256 tokenId, uint256 seed)
        internal
        view
        returns (string memory)
    {
        string memory style = "fill:";
        style = string.concat(style, _randomColor(tokenId + seed + 1, true));
        style = string.concat(style, ";fill-opacity:.");
        style = string.concat(
            style,
            Strings.toString(_randomOpacity(tokenId + seed + 3))
        );
        if (((tokenId + seed) * 3) % 4 == 0) {
            style = string.concat(style, ";stroke:");
            style = string.concat(
                style,
                _randomColor(tokenId + seed + 5, false)
            );
            style = string.concat(style, ";stroke-width:");
            style = string.concat(
                style,
                Strings.toString(_randomStrokeWidth(tokenId + seed + 7))
            );
            style = string.concat(style, ";stroke-opacity:.");
            style = string.concat(
                style,
                Strings.toString(_randomOpacity(tokenId + seed + 9))
            );
            if ((tokenId + seed) % 5 == 0) {
                style = string.concat(style, ";stroke-dasharray:");
                style = string.concat(
                    style,
                    Strings.toString(_randomStrokeWidth(tokenId + seed + 13))
                );
            }
        }
        return style;
    }

    /**
     * @notice Returns a random fill opacity from 1 to 9,
     *         to be prepended with a decimal in the css.
     */
    function _randomOpacity(uint256 tokenId) internal view returns (uint256) {
        uint256 roll = (thisUintAddress / tokenId) << 3;
        return (roll % 9) + 1;
    }

    /**
     * @notice Returns a random stroke width from 0 to 9.
     */
    function _randomStrokeWidth(uint256 tokenId)
        internal
        view
        returns (uint256)
    {
        uint256 roll = (thisUintAddress / tokenId) << 4;
        return roll % 10;
    }
}
