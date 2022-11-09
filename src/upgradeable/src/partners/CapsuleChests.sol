// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721PartnerSeaDropUpgradeable
} from "../ERC721PartnerSeaDropUpgradeable.sol";

/*
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMNOl,.....'ckXMMMMMMMMWx'.lXMMMMMMMMKc.......';dXMMMW0l,....'cOWMNo..cXMMMMMMNl..lNMMk,.;0MMMMMMMMNo.........,
MMMMMMMMMMWWWWWMMMMMMMMMMMMMMMMMMMMMMMMWOc'..';:;,..'dNMMMMMMM0;..'xWMMMMMMMK:...,,,'...:0WWk,..';:,.,xNMNl..:XMMMMMMXc..cXMWx..,OMMMMMMMMNl...',,,,,:
MMMMMMWX00000000KNMMMMMMMMMMMMMMMMMMMMNd...ckXNWWX0dxXWMMMMMMK:....'kWMMMMMMK:..lXNNXO;..cXK;..cKNWNKKWMMNl..:XMMMMMMXc..cXMWx..'OMMMMMMMMNl..:0NNNNNN
MMMMNKOkxdooooddkk0XWMMMMMMMMMMMMMMMMWx..'xNMMMMMMMMMMMMMMMMXc..;:..,OWMMMMMK:..lXNNXO;..cXXl..'okKNWMMMMNl..:XMMMMMMXc..cXMWx..'OMMMMMMMMNl..,dkOkOXM
MMMNOkxo::;;;;;;cdxkOXWMMMMMMMMMMMMMMNl..:XMMMMMMMMMMMMMMMMXl..;0Xl..:0MMMMMK:...,,,,...:0WMXx:'...;lkXMMNl..:XMMMMMMXc..cXMMx..,OMMMMMMMMNl.......'kW
MMW0kklcc::;;;;;,;coxxOXMMMMMMMMMMMMMNl..:KMMMMMMMMMMMMMMMNd...lkOo'..cKMMMMK:..,ccclldONMMMMMWKOdc'..:0WNl..:XMMMMMMXc..cXMMx..'OMMMMMMMMNl..,dkkkOXM
MMNOkd:cc:;;;;;;,,,,:odxONMMMMMMMMMMMMO,..cKWMMMMMMWKKWMMWx'...........lXMMMK;..oNMMMMMMMMMMWNWMMMWO,..oNWd..,OWMMMMWO;..oWMMx..'OMMMMMMMMNl..:XMMMMMM
MMWOkkc;;;;;;;;,,,,'',lO0KXNMMMMMMMMMMWO:..'lxO00Odc''dNWk'..lkkkkkkd,..oNMMK:..oNMMMMMMMMWKl;cxO0Oo'..xWMKc..,ok00ko,..:KMMMx...okOOOOOKWNl..,dkkOOOO
MMMNOkxl:;;;;;,,,,,;lxkxdxxkOXWMMMMMMMMMXkc,.......';o0W0;..oNMMMMMMWk,.'xWMK:..oWMMMMMMMMW0o;.......:kNMMMXx:'......':dXMMMMk..........lNNo..........
MMMMNKOkxl;;;,,,,:okkl;,;;:oxkOXWMMMMMMMMMWX0kxxxkOKNMMWXOk0NMMMMMMMMWKkk0WMW0kkKWMMMMMMMMMMWN0kxxxkKNMMMMMMMNKOkxxxOKNMMMMMMXOkkkkkkkkkKWWKkkkkkkkkkO
MMMMMMNKOkdl;,,;oOkl,''''''';oxk0NMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMN0kxdcckOo;'''''''''',:dxk0NMMMMMMMMMMMMMMMMMMMN0kOXMMMMMMMWKkk0WMMMMMMWNKOxxxxOKNWMMMMMW0kkKWMMMMMMN0kOXMMMMNKkxxxk0NWMMW0kkkkkkkkk0WMMMMMMMM
MMMMMMMMMMN0kOK0c'''''''''''',,;lxO0XWMMMMMMMMMMMMMMMMM0;..dWMMMMMMNl..:KMMMMN0o;........;o0WMMMK:..oNMMMMMMK;..dWMNk:.......cKMMK:.........cKMMMMMMMM
MMMMMMMMMMMMNNXkdc,'''''''',,,;;:lk00NMMMMMMMMMMMMMMMMM0,..dWMMMMMMNl..:KMMMXl...:dO00Od:...oXMMK:..oNMMMMMM0;..dWWk'..lO0OxdOWMMK:..;xkOkOk0WMMMMMMMM
MMMMMMMMMMMMMMN0kxo:,'''''',;;;:ccx00NMMMMMMMMMMMMMMMMM0,..oXNNNNNNKc..:KMXOl..;kNMMMMMMNk,..lXMK:..oNMMMMMM0;..dWWx...oKNWMMMMMMK:..cKNNNNWMMMMMMMMMM
MMMMMMMMMMMMMMMMN0kxdc,'''',:c::clO0KWMMMMMMMMMMMMMMMMM0,...,,,,,,,,...:KMk:'..xWMMMMMMMMWx..'OMK:..oNMMMMMM0;..dWMXd,..';lx0NMMMK:...,,,,cKMMMMMMMMMM
MMMMMMMMMMMMMMMMMMN0kxdc,'',,;;:okO0NWMMMMMMMMMMMMMMMMM0,..,cllllllc'..:KMk;..'kMMMMMMMMMMk'..kMK:..lNMMMMMM0;..dWMMWXOdc,...:OWMK:..'cllldXMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMN0kxdolclodxkOKNMMMMMMMMMMMMMMMMMMM0,..dWMMMMMMNl..:KMKd;..cXMMMMMMMMXc..;KMXc..cXMMMMMMO,..xWMMMMMMWNO:..;0MK:..lNMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMNKOOOOOO00KNWMMMMMMMMMMMMMMMMMMMM0,..dWMMMMMMNl..:KMWWO;..;xKNWWNKx;..;OWMWx'..l0NWWXk:..:KMWKdd0XNWKl..,0MK:..cKNNNNNNWMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMWWWWWWMMMMMMMMMMMMMMMMMMMMMMMM0,..dWMMMMMMNl..:KMMMWKo,...,:;,...,dKWMMMNk:...,;;,..'lKWMNd'..,;;,..,kWMK:...,,,,,,c0MMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM0:.'xWMMMMMMNo..cXMMMMMWKd;......:dKWMMMMMMMXd;.....'ckNMMMMNkc'....,o0WMMXc.........;OMMMMMMMM
*/

library CapsuleChestsStorage {
    struct Layout {
        /// @notice The Capsule Cards address that can burn chests to unpack
        ///         into cards.
        address capsuleCards;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("seaDrop.contracts.storage.capsuleChests");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

/*
 * @notice This contract uses ERC721PartnerSeaDrop,
 *         an ERC721A token contract that is compatible with SeaDrop.
 *         The set Capsule Cards contract is the only one that can call
 *         the burn function to unpack a chest into individual cards.
 */
contract CapsuleChests is ERC721PartnerSeaDropUpgradeable {
    using CapsuleChestsStorage for CapsuleChestsStorage.Layout;

    /**
     * @notice A token can only be burned by the set Capsule Cards address.
     */
    error BurnIncorrectSender();

    /**
     * @notice Initialize the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    function initialize(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    ) external initializer initializerERC721A {
        ERC721PartnerSeaDropUpgradeable.__ERC721PartnerSeaDrop_init(name, symbol, administrator, allowedSeaDrop);
    }

    function setCapsuleCardsAddress(address newCapsuleCardsAddress)
        external
        onlyOwner
    {
        CapsuleChestsStorage.layout().capsuleCards = newCapsuleCardsAddress;
    }

    function getCapsuleCardsAddress() public view returns (address) {
        return CapsuleChestsStorage.layout().capsuleCards;
    }

    /**
     * @notice Destroys `tokenId`, only callable by the set Capsule Cards
     *         address.
     *
     * @param tokenId The token id to burn.
     */
    function burn(uint256 tokenId) external {
        if (msg.sender != CapsuleChestsStorage.layout().capsuleCards) {
            revert BurnIncorrectSender();
        }

        _burn(tokenId);
    }
}
