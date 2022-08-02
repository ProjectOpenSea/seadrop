// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {
    IERC721AllowListedDrop
} from "./interfaces/IERC721AllowListedDrop.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { ERC721Drop } from "./ERC721Drop.sol";
import { ERC721A } from "./token/ERC721A.sol";
import { IERC721ContractMetadata } from "./interfaces/IContractMetadata.sol";

contract ERC721AllowListedDrop is ERC721Drop, IERC721AllowListedDrop {
    bytes32 merkleRoot;

    error InvalidProof();

    modifier allowListNotRedeemed(uint256 allowListIndex) {
        {
            if (isAllowListRedeemed(msg.sender, allowListIndex)) {
                revert AllowListRedeemed();
            }
        }
        _;
    }

    modifier isAllowListed(bytes32 leaf, bytes32[] calldata proof) {
        {
            if (!MerkleProofLib.verify(proof, merkleRoot, leaf)) {
                revert InvalidProof();
            }
        }
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        PublicDrop memory publicDrop,
        address saleToken,
        address administrator,
        bytes32 _merkleRoot,
        address leavesEncryptionPublicKey,
        string memory leavesURI
    ) ERC721Drop(name, symbol, administrator, publicDrop, saleToken) {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(
            _merkleRoot,
            leavesEncryptionPublicKey,
            leavesURI
        );
    }

    function setMerkleRoot(
        bytes32 newMerkleRoot,
        address leavesEncryptionPublicKey,
        string calldata leavesURI
    ) external override onlyOwnerOrAdministrator {
        merkleRoot = newMerkleRoot;
        emit MerkleRootUpdated(
            newMerkleRoot,
            leavesEncryptionPublicKey,
            leavesURI
        );
    }

    function mintAllowList(
        AllowListMint calldata mintParams,
        bytes32[] calldata proof
    )
        public
        payable
        isAllowListed(keccak256(abi.encode(msg.sender, mintParams)), proof)
        isActive(mintParams.startTime, mintParams.endTime)
        includesCorrectPayment(mintParams.numToMint, mintParams.mintPrice)
        checkNumberToMint(mintParams.numToMint)
        allowListNotRedeemed(mintParams.allowListIndex)
    {
        _mint(mintParams.numToMint, mintParams.feeBps);
    }

    function setAllowListRedeemed(address minter, uint256 allowListIndex)
        internal
    {
        _setAux(minter, uint64(_getAux(minter) | (1 << allowListIndex)));
    }

    function isAllowListRedeemed(address minter, uint256 allowListIndex)
        internal
        view
        returns (bool)
    {
        return (_getAux(minter) >> allowListIndex) & 1 == 1;
    }

    function totalSupply()
        public
        view
        virtual
        override(ERC721Drop, IERC721ContractMetadata)
        returns (uint256)
    {
        return ERC721A.totalSupply();
    }
}
