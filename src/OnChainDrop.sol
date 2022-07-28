// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface ContractMetadata {
    event ContractURIUpdated(string newContractURI);

    function contractURI() external returns (string memory);

    function setContractURI(string calldata newContractURI) external;
}

interface OnChainDropBase is ContractMetadata {
    // designed to take up 1 storage slot - 248 bits total
    struct DropStage {
        // whether mint should be restricted to allowList - TBD?
        bool allowList; // 8/256 bits
        // up to 1.2m of native token, eg: ETH, MATIC
        uint80 mintPrice; // 88/256 bits
        // when drop stage starts being active
        uint64 startTime; // 152/256 bits
        // when drop stage stops being active
        uint64 endTime; // 216/256 bits
        // maximum number of mints for this drop stage
        uint16 maxNumberMinted; // 232/256 bits
        // fee out of 10,000 basis points that we will collect - TBD?
        uint16 feeBps; // 248/256 bits
    }

    event MerkleRootUpdated(bytes32 indexed newMerkleRoot, string leavesURI);

    function updateMerkleRoot(bytes32 newMerkleRoot, string calldata leavesURI)
        external;

    function mint(uint256 numToMint) external;
}

interface OnChainDrop__SingleDropStage is OnChainDropBase {
    event DropStageUpdated(DropStage newDropStage);

    function dropStage() external returns (DropStage memory);

    function updateDropStage(DropStage calldata newDropStage) external;

    function mintAllowList(
        uint256 numToMint,
        uint256 mintPrice,
        uint256 maxNumberMinted,
        uint256 startTime,
        uint256 endTime,
        uint256 feeBps,
        bytes32[] calldata proof
    ) external;
}

interface OnChainDrop__MultiDropStage is OnChainDropBase {
    event DropStageUpdated(
        uint256 indexed dropStageIndex,
        DropStage newDropStage
    );

    function getDropStageByIndex(uint256 dropStageIndex)
        external
        returns (DropStage memory);

    function setDropStages(DropStage[] calldata newDropStage) external;

    function updateDropStage(
        uint256 dropStageIndex,
        DropStage calldata newDropStage
    ) external;

    function mintAllowList(
        uint256 numtoMint,
        uint256 dropStageIndex,
        bytes32[] calldata proof
    ) external;
}

interface ServerSideSignatureDrop is ContractMetadata {
    event SignerUpdated(
        address indexed previousSigner,
        address indexed newSigner
    );

    // not bytepacked, since it won't be stored in storage
    struct MintData {
        uint256 mintPrice;
        uint256 maxNumberMinted;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 feeBps;
    }

    function mint(
        uint256 numToMint,
        MintData calldata mintData,
        bytes calldata signature
    ) external;

    function setSigner(address newSigner) external;
}
