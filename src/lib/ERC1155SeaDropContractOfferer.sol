// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC1155SeaDrop } from "../interfaces/IERC1155SeaDrop.sol";

import { ERC1155ContractMetadata } from "./ERC1155ContractMetadata.sol";

import {
    ERC1155SeaDropContractOffererStorage
} from "./ERC1155SeaDropContractOffererStorage.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "./ERC1155SeaDropErrorsAndEvents.sol";

import { PublicDrop } from "./ERC1155SeaDropStructs.sol";

import { AllowListData, SpentItem } from "./SeaDropStructs.sol";

import "./ERC1155SeaDropConstants.sol";

import {
    IERC165
} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title  ERC1155SeaDropContractOfferer
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice An ERC1155 token contract that can mint as a
 *         Seaport contract offerer.
 */
contract ERC1155SeaDropContractOfferer is
    ERC1155ContractMetadata,
    ERC1155SeaDropErrorsAndEvents
{
    using ERC1155SeaDropContractOffererStorage for ERC1155SeaDropContractOffererStorage.Layout;

    /// @notice The allowed conduit address that can mint.
    address immutable _CONDUIT;

    /**
     * @notice Deploy the token contract.
     *
     * @param allowedConfigurer The address of the contract allowed to
     *                          configure parameters. Also contains SeaDrop
     *                          implementation code.
     * @param allowedConduit    The address of the conduit contract allowed to
     *                          interact.
     * @param allowedSeaport    The address of the Seaport contract allowed to
     *                          interact.
     * @param name_             The name of the token.
     * @param symbol_           The symbol of the token.
     */
    constructor(
        address allowedConfigurer,
        address allowedConduit,
        address allowedSeaport,
        string memory name_,
        string memory symbol_
    ) ERC1155ContractMetadata(allowedConfigurer, name_, symbol_) {
        // Set the allowed conduit to interact with this contract.
        _CONDUIT = allowedConduit;

        // Set the allowed Seaport to interact with this contract.
        ERC1155SeaDropContractOffererStorage.layout()._allowedSeaport[
            allowedSeaport
        ] = true;

        // Set the allowed Seaport enumeration.
        address[] memory enumeratedAllowedSeaport = new address[](1);
        enumeratedAllowedSeaport[0] = allowedSeaport;
        ERC1155SeaDropContractOffererStorage
            .layout()
            ._enumeratedAllowedSeaport = enumeratedAllowedSeaport;

        // Emit an event noting the contract deployment.
        emit SeaDropTokenDeployed(SEADROP_TOKEN_TYPE.ERC1155_STANDARD);
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
                    selector == GET_PUBLIC_DROP_INDEXES_SELECTOR ||
                    selector == GET_CREATOR_PAYOUTS_SELECTOR ||
                    selector == GET_ALLOW_LIST_MERKLE_ROOT_SELECTOR ||
                    selector == GET_ALLOWED_FEE_RECIPIENTS_SELECTOR ||
                    selector == GET_SIGNERS_SELECTOR ||
                    selector == GET_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR ||
                    selector ==
                    GET_SIGNED_MINT_VALIDATION_PARAMS_INDEXES_SELECTOR ||
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
            if (selector == GENERATE_ORDER_SELECTOR) {
                _mintOrder(data);
            }

            // Return the data from the delegate call.
            return returnedData;
        } else if (selector == GET_MINT_STATS_SELECTOR) {
            // Get the minter and token id.
            (address minter, uint256 tokenId) = abi.decode(
                data,
                (address, uint256)
            );

            // Get the mint stats.
            (
                uint256 minterNumMinted,
                uint256 minterNumMintedForTokenId,
                uint256 currentTotalSupply,
                uint256 maxSupply
            ) = _getMintStats(minter, tokenId);

            // Encode the return data.
            return
                abi.encode(
                    minterNumMinted,
                    minterNumMintedForTokenId,
                    currentTotalSupply,
                    maxSupply
                );
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
     *         consequences of malicious onERC1155Received() hooks.
     *
     * @param minter  The minter address.
     * @param tokenId The token id to return the stats for.
     */
    function _getMintStats(
        address minter,
        uint256 tokenId
    )
        internal
        view
        returns (
            uint256 minterNumMinted,
            uint256 minterNumMintedForTokenId,
            uint256 currentTotalSupply,
            uint256 maxSupply
        )
    {
        // Put the token supply on the stack.
        TokenSupply storage tokenSupply = _tokenSupply[tokenId];

        // Assign the return values.
        currentTotalSupply = tokenSupply.totalSupply;
        maxSupply = tokenSupply.maxSupply;
        minterNumMinted = _totalMintedByUser[minter];
        minterNumMintedForTokenId = _totalMintedByUserPerToken[minter][tokenId];
    }

    /**
     * @dev Handle ERC-1155 safeTransferFrom. If "from" is this contract,
     *      the sender can only be Seaport or the conduit.
     *
     * @param from   The address to transfer from.
     * @param to     The address to transfer to.
     * @param id     The token id to transfer.
     * @param amount The amount of tokens to transfer.
     * @param data   The data to pass to the onERC1155Received hook.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual override {
        if (from == address(this)) {
            // Only Seaport or the conduit can use this function
            // when "from" is this contract.
            if (
                _cast(
                    msg.sender != _CONDUIT &&
                        !ERC1155SeaDropContractOffererStorage
                            .layout()
                            ._allowedSeaport[msg.sender]
                ) == 1
            ) {
                revert InvalidCallerOnlyAllowedSeaport(msg.sender);
            }
            return;
        }

        super.safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155ContractMetadata) returns (bool) {
        return
            interfaceId == type(IERC1155SeaDrop).interfaceId ||
            interfaceId == 0x2e778efc || // SIP-5 (getSeaportMetadata)
            // ERC1155ContractMetadata returns supportsInterface true for
            //     IERC1155ContractMetadata, ERC-4906, ERC-2981
            // ERC1155A returns supportsInterface true for
            //     ERC165, ERC1155, ERC1155MetadataURI
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Internal function to mint tokens during a generateOrder call
     *      from Seaport.
     *
     * @param data The original transaction calldata, without the selector.
     */
    function _mintOrder(bytes calldata data) internal {
        // Decode fulfiller and context from calldata.
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

        // Set the token ids and quantities.
        uint256 minimumReceivedLength = minimumReceived.length;
        uint256[] memory tokenIds = new uint256[](minimumReceivedLength);
        uint256[] memory quantities = new uint256[](minimumReceivedLength);
        for (uint256 i = 0; i < minimumReceivedLength; ) {
            tokenIds[i] = minimumReceived[i].identifier;
            quantities[i] = minimumReceived[i].amount;
            unchecked {
                ++i;
            }
        }

        // Mint the tokens.
        _batchMint(minter, tokenIds, quantities, "");
    }
}
