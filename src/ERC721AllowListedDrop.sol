// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {
    IERC721AllowlistedDrop
} from "./interfaces/IERC721AllowlistedDrop.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { ERC721Drop } from "./ERC721Drop.sol";
import { ERC721A } from "./token/ERC721A.sol";
import { IERC721ContractMetadata } from "./interfaces/IContractMetadata.sol";

contract ERC721AllowlistedDrop is ERC721Drop, IERC721AllowlistedDrop {
    bytes32 merkleRoot;

    error InvalidProof();

    modifier allowListNotRedeemed(bool allowList) {
        {
            if (allowList) {
                if (isAllowListRedeemed(msg.sender)) {
                    revert AllowListRedeemed();
                }
            }
        }
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 maxNumMintable,
        address administrator,
        bytes32 _merkleRoot,
        address leavesEncryptionPublicKey,
        string memory leavesURI
    ) ERC721Drop(name, symbol, administrator, maxNumMintable) {
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
        uint256 numToMint,
        uint256 mintPrice,
        uint256 maxNumberMinted,
        uint256 startTime,
        uint256 endTime,
        uint256 feeBps,
        bytes32[] calldata proof
    ) public payable {
        require(block.timestamp >= startTime, "Drop not started");
        require(block.timestamp <= endTime, "Drop has ended");
        require(numToMint * mintPrice == msg.value, "Incorrect Payment");
        require(numToMint <= maxNumberMinted, "Exceeds max number mintable");
        bytes32 computedHash = keccak256(
            abi.encode(
                msg.sender,
                mintPrice,
                maxNumberMinted,
                startTime,
                endTime,
                feeBps
            )
        );
        if (!MerkleProofLib.verify(proof, merkleRoot, computedHash)) {
            revert InvalidProof();
        }

        _mint(msg.sender, numToMint);
    }

    function setAllowListRedeemed(address minter) internal {
        _setAux(minter, 1);
    }

    function isAllowListRedeemed(address minter) internal view returns (bool) {
        return _getAux(minter) & 1 == 1;
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
