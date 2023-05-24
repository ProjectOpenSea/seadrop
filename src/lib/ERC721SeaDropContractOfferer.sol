// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC721SeaDrop } from "../interfaces/IERC721SeaDrop.sol";

import { ERC721ContractMetadata } from "./ERC721ContractMetadata.sol";

import {
    ERC721SeaDropContractOffererStorage
} from "./ERC721SeaDropContractOffererStorage.sol";

import {
    ERC721SeaDropErrorsAndEvents
} from "./ERC721SeaDropErrorsAndEvents.sol";

import { PublicDrop } from "./ERC721SeaDropStructs.sol";

import { AllowListData, SpentItem } from "./SeaDropStructs.sol";

import "./ERC721SeaDropConstants.sol";

import {
    IERC165
} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title  ERC721SeaDropContractOfferer
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice An ERC721 token contract based on ERC721A that can mint as a
 *         Seaport contract offerer.
 */
contract ERC721SeaDropContractOfferer is
    ERC721ContractMetadata,
    ERC721SeaDropErrorsAndEvents
{
    using ERC721SeaDropContractOffererStorage for ERC721SeaDropContractOffererStorage.Layout;

    /// @notice The allowed conduit address that can mint.
    address immutable _CONDUIT;

    /**
     * @notice Deploy the token contract.
     *
     * @param name              The name of the token.
     * @param symbol            The symbol of the token.
     * @param allowedConfigurer The address of the contract allowed to
     *                          configure parameters.
     * @param allowedConduit    The address of the conduit contract allowed to
     *                          interact.
     * @param allowedSeaport    The address of the Seaport contract allowed to
     *                          interact.
     */
    constructor(
        string memory name,
        string memory symbol,
        address allowedConfigurer,
        address allowedConduit,
        address allowedSeaport
    ) ERC721ContractMetadata(name, symbol, allowedConfigurer) {
        // Set the allowed conduit to interact with this contract.
        _CONDUIT = allowedConduit;

        // Set the allowed Seaport to interact with this contract.
        ERC721SeaDropContractOffererStorage.layout()._allowedSeaport[
            allowedSeaport
        ] = true;

        // Set the allowed Seaport enumeration.
        address[] memory enumeratedAllowedSeaport = new address[](1);
        enumeratedAllowedSeaport[0] = allowedSeaport;
        ERC721SeaDropContractOffererStorage
            .layout()
            ._enumeratedAllowedSeaport = enumeratedAllowedSeaport;

        // Emit an event noting the contract deployment.
        emit SeaDropTokenDeployed(SEADROP_TOKEN_TYPE.ERC721_STANDARD);
    }

    /**
     * @notice The fallback function is used as a dispatcher for SeaDrop
     *         methods.
     */
    fallback(bytes calldata) external returns (bytes memory output) {
        // Get the function selector.
        bytes4 selector = msg.sig;

        // Get the rest of the msg data after the selector.
        bytes calldata data = msg.data[4:];

        if (
            _cast(
                selector == UPDATE_ALLOWED_SEAPORT_SELECTOR ||
                    selector == UPDATE_DROP_URI_SELECTOR ||
                    selector == UPDATE_PUBLIC_DROP_SELECTOR ||
                    selector == UPDATE_ALLOW_LIST_SELECTOR ||
                    selector == UPDATE_CREATOR_PAYOUTS_SELECTOR ||
                    selector == UPDATE_ALLOWED_FEE_RECIPIENT_SELECTOR ||
                    selector == UPDATE_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR ||
                    selector == UPDATE_PAYER_SELECTOR ||
                    selector == PREVIEW_ORDER_SELECTOR ||
                    selector == GENERATE_ORDER_SELECTOR ||
                    selector == GET_SEAPORT_METADATA_SELECTOR ||
                    selector == GET_PUBLIC_DROP_SELECTOR ||
                    selector == GET_CREATOR_PAYOUTS_SELECTOR ||
                    selector == GET_ALLOW_LIST_MERKLE_ROOT_SELECTOR ||
                    selector == GET_ALLOWED_FEE_RECIPIENTS_SELECTOR ||
                    selector == GET_SIGNERS_SELECTOR ||
                    selector == GET_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR ||
                    selector == GET_PAYERS_SELECTOR
            ) == 1
        ) {
            // For update calls, ensure the sender is only the owner
            // or configurer contract.
            if (
                _cast(
                    selector == UPDATE_ALLOWED_SEAPORT_SELECTOR ||
                        selector == UPDATE_DROP_URI_SELECTOR ||
                        selector == UPDATE_PUBLIC_DROP_SELECTOR ||
                        selector == UPDATE_ALLOW_LIST_SELECTOR ||
                        selector == UPDATE_CREATOR_PAYOUTS_SELECTOR ||
                        selector == UPDATE_ALLOWED_FEE_RECIPIENT_SELECTOR ||
                        selector ==
                        UPDATE_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR ||
                        selector == UPDATE_PAYER_SELECTOR
                ) == 1
            ) {
                _onlyOwnerOrConfigurer();
            }

            // Forward the call to the implementation contract.
            (bool success, bytes memory returnedData) = _CONFIGURER
                .delegatecall(msg.data);

            // Require that the call was successful.
            if (!success) {
                // Revert if no revert reason.
                if (returnedData.length == 0) revert();

                // Bubble up the revert reason.
                assembly {
                    revert(add(32, returnedData), mload(returnedData))
                }
            }

            // If the call was to generateOrder, mint the tokens.
            _mintIfGenerateOrder(selector, data);

            // Return the data from the delegate call.
            return returnedData;
        } else if (selector == SAFE_TRANSFER_FROM_1155_SELECTOR) {
            // Get the parameters.
            (
                address from,
                address to,
                uint256 id,
                uint256 amount,
                bytes memory transferData
            ) = abi.decode(data, (address, address, uint256, uint256, bytes));

            // Call safeTransferFrom.
            _safeTransferFrom(from, to, id, amount, transferData);
        } else if (selector == GET_MINT_STATS_SELECTOR) {
            // Get the minter.
            address minter = abi.decode(data, (address));

            // Get the mint stats.
            (
                uint256 minterNumMinted,
                uint256 currentTotalSupply,
                uint256 maxSupply
            ) = _getMintStats(minter);

            // Encode the return data.
            return abi.encode(minterNumMinted, currentTotalSupply, maxSupply);
        } else if (selector == RATIFY_ORDER_SELECTOR) {
            // This function is a no-op, nothing additional needs to happen here.
            // Utilize assembly to efficiently return the ratifyOrder magic value.
            assembly {
                mstore(0, 0xf4dd92ce)
                return(0x1c, 0x04)
            }
        } else {
            // Revert if the function selector is not supported.
            revert UnsupportedFunctionSelector(selector);
        }
    }

    /**
     * @notice Returns a set of mint stats for the address.
     *         This assists in enforcing maxSupply, maxTotalMintableByWallet,
     *         and maxTokenSupplyForStage checks.
     *
     * @dev    NOTE: Implementing contracts should always update these numbers
     *         before transferring any tokens with _safeMint() to mitigate
     *         consequences of malicious onERC721Received() hooks.
     *
     * @param minter The minter address.
     */
    function _getMintStats(
        address minter
    )
        internal
        view
        returns (
            uint256 minterNumMinted,
            uint256 currentTotalSupply,
            uint256 maxSupply
        )
    {
        minterNumMinted = _numberMinted(minter);
        currentTotalSupply = _totalMinted();
        maxSupply = _maxSupply;
    }

    /**
     * @dev Handle ERC-1155 safeTransferFrom. Nothing additional needs to happen here.
     *
     *      Only allowed Seaport or conduit can use this function.
     *
     * @param from          The address to transfer from. Must be this contract.
     * @custom:param to     Unused parameter
     * @custom:param id     Unused parameter
     * @custom:param amount Unused parameter
     * @custom:param data   Unused parameter
     */
    function _safeTransferFrom(
        address from,
        address /* to */,
        uint256 /* id */,
        uint256 /* amount */,
        bytes memory /* data */
    ) internal view {
        // Only Seaport or the conduit can use this function.
        if (
            _cast(
                (msg.sender != _CONDUIT &&
                    !ERC721SeaDropContractOffererStorage
                        .layout()
                        ._allowedSeaport[msg.sender]) || from != address(this)
            ) == 1
        ) {
            revert InvalidCallerOnlyAllowedSeaport(msg.sender);
        }

        // This function is a no-op, nothing additional needs to happen here.
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721ContractMetadata) returns (bool) {
        return
            interfaceId == type(IERC721SeaDrop).interfaceId ||
            interfaceId == 0x2e778efc || // SIP-5 (getSeaportMetadata)
            // ERC721ContractMetadata returns supportsInterface true for
            //     IERC721ContractMetadata, ERC-4906, ERC-2981
            // ERC721A returns supportsInterface true for
            //     ERC165, ERC721, ERC721Metadata
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Internal function to mint tokens during a generateOrder call
     *      from Seaport.
     */
    function _mintIfGenerateOrder(
        bytes4 selector,
        bytes calldata data
    ) internal {
        if (selector != GENERATE_ORDER_SELECTOR) return;

        // Decode function parameters from calldata.
        (
            address fulfiller,
            SpentItem[] memory minimumReceived,
            ,
            bytes memory context
        ) = abi.decode(data, (address, SpentItem[], SpentItem[], bytes));

        // Assign the minter in context[22:42]
        address minter;
        assembly {
            minter := div(
                mload(add(add(context, 0x20), 22)),
                0x1000000000000000000000000
            )
        }

        // If the minter is the zero address, set it to the fulfiller.
        if (minter == address(0)) {
            minter = fulfiller;
        }

        // Quantity is the amount of the ERC-1155 min received item.
        uint256 quantity = minimumReceived[0].amount;

        // Mint the tokens.
        _mint(minter, quantity);
    }
}
