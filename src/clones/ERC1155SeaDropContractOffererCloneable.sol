// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC1155SeaDrop } from "../interfaces/IERC1155SeaDrop.sol";

import { ISeaDropToken } from "../interfaces/ISeaDropToken.sol";

import {
    ERC1155ContractMetadataCloneable
} from "./ERC1155ContractMetadataCloneable.sol";

import {
    ERC1155SeaDropContractOffererStorage
} from "../lib/ERC1155SeaDropContractOffererStorage.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "../lib/ERC1155SeaDropErrorsAndEvents.sol";

import { PublicDrop } from "../lib//ERC1155SeaDropStructs.sol";

import { AllowListData } from "../lib/SeaDropStructs.sol";

import {
    ERC1155ConduitPreapproved
} from "../lib/ERC1155ConduitPreapproved.sol";

import { ERC1155 } from "solady/src/tokens/ERC1155.sol";

import { SpentItem } from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ContractOffererInterface
} from "seaport-types/src/interfaces/ContractOffererInterface.sol";

import {
    IERC165
} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title  ERC1155SeaDropContractOffererCloneable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice A cloneable ERC1155 token contract that can mint as a
 *         Seaport contract offerer.
 */
contract ERC1155SeaDropContractOffererCloneable is
    ERC1155ContractMetadataCloneable,
    ERC1155SeaDropErrorsAndEvents
{
    using ERC1155SeaDropContractOffererStorage for ERC1155SeaDropContractOffererStorage.Layout;

    /**
     * @notice Initialize the token contract.
     *
     * @param allowedConfigurer The address of the contract allowed to
     *                          configure parameters. Also contains SeaDrop
     *                          implementation code.
     * @param allowedSeaport    The address of the Seaport contract allowed to
     *                          interact.
     * @param name_             The name of the token.
     * @param symbol_           The symbol of the token.
     */
    function __ERC1155SeaDropContractOffererCloneable_init(
        address allowedConfigurer,
        address allowedSeaport,
        string memory name_,
        string memory symbol_
    ) internal onlyInitializing {
        // Set the allowed Seaport to interact with this contract.
        if (allowedSeaport == address(0)) {
            revert AllowedSeaportCannotBeZeroAddress();
        }
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
        emit SeaDropTokenDeployed(SEADROP_TOKEN_TYPE.ERC1155_CLONE);

        // Initialize ERC1155ContractMetadataCloneable.
        __ERC1155ContractMetadataCloneable_init(
            allowedConfigurer,
            name_,
            symbol_
        );
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

        // Determine if we should forward the call to the implementation
        // contract with SeaDrop logic.
        bool callSeaDropImplementation = selector ==
            ISeaDropToken.updateAllowedSeaport.selector ||
            selector == ISeaDropToken.updateDropURI.selector ||
            selector == ISeaDropToken.updateAllowList.selector ||
            selector == ISeaDropToken.updateCreatorPayouts.selector ||
            selector == ISeaDropToken.updatePayer.selector ||
            selector == ISeaDropToken.updateAllowedFeeRecipient.selector ||
            selector == ISeaDropToken.updateSigner.selector ||
            selector == IERC1155SeaDrop.updatePublicDrop.selector ||
            selector == ContractOffererInterface.previewOrder.selector ||
            selector == ContractOffererInterface.generateOrder.selector ||
            selector == ContractOffererInterface.getSeaportMetadata.selector ||
            selector == IERC1155SeaDrop.getPublicDrop.selector ||
            selector == IERC1155SeaDrop.getPublicDropIndexes.selector ||
            selector == ISeaDropToken.getAllowedSeaport.selector ||
            selector == ISeaDropToken.getCreatorPayouts.selector ||
            selector == ISeaDropToken.getAllowListMerkleRoot.selector ||
            selector == ISeaDropToken.getAllowedFeeRecipients.selector ||
            selector == ISeaDropToken.getSigners.selector ||
            selector == ISeaDropToken.getDigestIsUsed.selector ||
            selector == ISeaDropToken.getPayers.selector;

        // Determine if we should require only the owner or configurer calling.
        bool requireOnlyOwnerOrConfigurer = selector ==
            ISeaDropToken.updateAllowedSeaport.selector ||
            selector == ISeaDropToken.updateDropURI.selector ||
            selector == ISeaDropToken.updateAllowList.selector ||
            selector == ISeaDropToken.updateCreatorPayouts.selector ||
            selector == ISeaDropToken.updatePayer.selector ||
            selector == ISeaDropToken.updateAllowedFeeRecipient.selector ||
            selector == IERC1155SeaDrop.updatePublicDrop.selector;

        if (callSeaDropImplementation) {
            // For update calls, ensure the sender is only the owner
            // or configurer contract.
            if (requireOnlyOwnerOrConfigurer) {
                _onlyOwnerOrConfigurer();
            } else if (selector == ISeaDropToken.updateSigner.selector) {
                // For updateSigner, a signer can disallow themselves.
                // Get the signer parameter.
                address signer = address(bytes20(data[12:32]));
                // If the signer is not allowed, ensure sender is only owner
                // or configurer.
                if (
                    msg.sender != signer ||
                    (msg.sender == signer &&
                        !ERC1155SeaDropContractOffererStorage
                            .layout()
                            ._allowedSigners[signer])
                ) {
                    _onlyOwnerOrConfigurer();
                }
            }

            // Forward the call to the implementation contract.
            (bool success, bytes memory returnedData) = _CONFIGURER
                .delegatecall(msg.data);

            // Require that the call was successful.
            if (!success) {
                // Bubble up the revert reason.
                assembly {
                    revert(add(32, returnedData), mload(returnedData))
                }
            }

            // If the call was to generateOrder, mint the tokens.
            if (selector == ContractOffererInterface.generateOrder.selector) {
                _mintOrder(data);
            }

            // Return the data from the delegate call.
            return returnedData;
        } else if (selector == IERC1155SeaDrop.getMintStats.selector) {
            // Get the minter and token id.
            (address minter, uint256 tokenId) = abi.decode(
                data,
                (address, uint256)
            );

            // Get the mint stats.
            (
                uint256 minterNumMinted,
                uint256 minterNumMintedForTokenId,
                uint256 totalMintedForTokenId,
                uint256 maxSupply
            ) = _getMintStats(minter, tokenId);

            // Encode the return data.
            return
                abi.encode(
                    minterNumMinted,
                    minterNumMintedForTokenId,
                    totalMintedForTokenId,
                    maxSupply
                );
        } else if (selector == ContractOffererInterface.ratifyOrder.selector) {
            // This function is a no-op, nothing additional needs to happen here.
            // Utilize assembly to efficiently return the ratifyOrder magic value.
            assembly {
                mstore(0, 0xf4dd92ce)
                return(0x1c, 32)
            }
        } else if (selector == ISeaDropToken.configurer.selector) {
            // Return the configurer contract.
            return abi.encode(_CONFIGURER);
        } else if (selector == IERC1155SeaDrop.multiConfigureMint.selector) {
            // Ensure only the owner or configurer can call this function.
            _onlyOwnerOrConfigurer();

            // Mint the tokens.
            _multiConfigureMint(data);
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
            uint256 totalMintedForTokenId,
            uint256 maxSupply
        )
    {
        // Put the token supply on the stack.
        TokenSupply storage tokenSupply = _tokenSupply[tokenId];

        // Assign the return values.
        totalMintedForTokenId = tokenSupply.totalMinted;
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
                msg.sender != _CONDUIT &&
                !ERC1155SeaDropContractOffererStorage.layout()._allowedSeaport[
                    msg.sender
                ]
            ) {
                revert InvalidCallerOnlyAllowedSeaport(msg.sender);
            }
            return;
        }

        ERC1155._safeTransfer(_by(), from, to, id, amount, data);
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC1155ContractMetadataCloneable)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155SeaDrop).interfaceId ||
            interfaceId == type(ContractOffererInterface).interfaceId ||
            interfaceId == 0x2e778efc || // SIP-5 (getSeaportMetadata)
            // ERC1155ContractMetadata returns supportsInterface true for
            //     IERC1155ContractMetadata, ERC-4906, ERC-2981
            // ERC1155A returns supportsInterface true for
            //     ERC165, ERC1155, ERC1155MetadataURI
            ERC1155ContractMetadataCloneable.supportsInterface(interfaceId);
    }

    /**
     * @dev Internal function to mint tokens during a generateOrder call
     *      from Seaport.
     *
     * @param data The original transaction calldata, without the selector.
     */
    function _mintOrder(bytes calldata data) internal {
        // Decode fulfiller, minimumReceived, and context from calldata.
        (
            address fulfiller,
            SpentItem[] memory minimumReceived,
            ,
            bytes memory context
        ) = abi.decode(data, (address, SpentItem[], SpentItem[], bytes));

        // Assign the minter from context[22:42]. We validate context has the
        // correct minimum length in the implementation's `_decodeOrder`.
        address minter;
        assembly {
            minter := shr(96, mload(add(add(context, 0x20), 22)))
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

    /**
     * @dev Internal function to mint tokens during a multiConfigureMint call
     *      from the configurer contract.
     *
     * @param data The original transaction calldata, without the selector.
     */
    function _multiConfigureMint(bytes calldata data) internal {
        // Decode the calldata.
        (
            address recipient,
            uint256[] memory tokenIds,
            uint256[] memory amounts
        ) = abi.decode(data, (address, uint256[], uint256[]));

        _batchMint(recipient, tokenIds, amounts, "");
    }
}
