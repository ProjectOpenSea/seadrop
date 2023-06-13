// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721Test } from "./utils/SeaDrop721Test.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { MintParams, PublicDrop } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

import { Merkle } from "murky/Merkle.sol";

contract ERC721SeaDropPlusRegularMint is ERC721SeaDrop {
    constructor(
        address allowedConfigurer,
        address allowedConduit,
        address allowedSeaport,
        string memory name,
        string memory symbol
    )
        ERC721SeaDrop(
            allowedConfigurer,
            allowedConduit,
            allowedSeaport,
            name,
            symbol
        )
    {}

    function mint(address recipient, uint256 quantity) public payable {
        _mint(recipient, quantity);
    }
}

contract TestSeaDropSnapshot is SeaDrop721Test {
    address admin = makeAddr("admin");
    address creator = makeAddr("creator");
    address feeRecipient = makeAddr("feeRecipient");
    uint256 feeBps = 500;

    uint256 mintPrice = 1 ether;
    uint256 numMints = 1;

    bytes extraDataPublicDrop;
    bytes extraDataAllowList;
    bytes extraDataSigned;
    bytes extraDataSignedCompact2098;

    function setUp() public override {
        super.setUp();

        token = new ERC721SeaDropPlusRegularMint(
            address(configurer),
            address(0),
            allowedSeaport,
            "",
            ""
        );
        token.setMaxSupply(1000);
        setSingleCreatorPayout(creator);
        IERC721SeaDrop(address(token)).updateAllowedFeeRecipient(
            feeRecipient,
            true
        );

        _configurePublic();
        _configureAllowList();
        _configureSigned();

        addSeaDropOfferItem(numMints);
        addSeaDropConsiderationItems(
            feeRecipient,
            feeBps,
            mintPrice * numMints
        );
        configureSeaDropOrderParameters();

        vm.deal(address(this), 100 ether);

        // Warm the contract offerer nonce storage slot to non-zero
        // by executing a first mint.
        testMintPublic_snapshot();
    }

    function _configurePublic() internal {
        PublicDrop memory publicDrop = PublicDrop({
            startPrice: uint80(mintPrice),
            endPrice: uint80(mintPrice),
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + 500),
            paymentToken: address(0),
            maxTotalMintableByWallet: 5,
            feeBps: uint16(feeBps),
            restrictFeeRecipients: true
        });
        IERC721SeaDrop(address(token)).updatePublicDrop(publicDrop);

        address minter = address(0);
        extraDataPublicDrop = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x00), // substandard version byte: public mint
            bytes20(feeRecipient),
            bytes20(minter)
        );
    }

    function _configureAllowList() internal {
        MintParams memory mintParams = MintParams({
            startPrice: mintPrice,
            endPrice: mintPrice,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp) + 500,
            paymentToken: address(0),
            maxTotalMintableByWallet: 5,
            maxTokenSupplyForStage: 1000,
            dropStageIndex: 2,
            feeBps: feeBps,
            restrictFeeRecipients: true
        });

        address[] memory allowList = new address[](50);
        for (uint256 i = 0; i < allowList.length; ++i) {
            allowList[i] = makeAddr("fred");
        }
        allowList[25] = address(this);
        bytes32[] memory proof = setAllowListMerkleRootAndReturnProof(
            allowList,
            25,
            mintParams
        );

        address minter = address(0);
        extraDataAllowList = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x01), // substandard version byte: allow list mint
            bytes20(feeRecipient),
            bytes20(minter),
            abi.encode(mintParams),
            abi.encodePacked(proof)
        );
    }

    function _configureSigned() internal {
        address signer = makeAddr("signer-doug");
        IERC721SeaDrop(address(token)).updateSigner(signer, true);

        MintParams memory mintParams = MintParams({
            paymentToken: address(0),
            startPrice: mintPrice,
            endPrice: mintPrice,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp) + 500,
            maxTotalMintableByWallet: 4,
            maxTokenSupplyForStage: 1000,
            dropStageIndex: 3,
            feeBps: feeBps,
            restrictFeeRecipients: true
        });

        // Get the signature.
        address minter = address(this);
        uint256 salt = 123;
        bytes memory signature = getSignedMint(
            "signer-doug",
            address(token),
            minter,
            feeRecipient,
            mintParams,
            salt,
            true
        );
        extraDataSigned = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x02), // substandard version byte: signed mint
            bytes20(feeRecipient),
            bytes20(address(0)),
            abi.encode(mintParams),
            bytes32(salt),
            signature
        );
    }

    function testRegularMint_snapshot() public {
        ERC721SeaDropPlusRegularMint(address(token)).mint{ value: 0.1 ether }(
            address(this),
            1
        );
    }

    function testMintPublic_snapshot() public {
        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraDataPublicDrop
        });
        consideration.fulfillAdvancedOrder{ value: mintPrice * numMints }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testMintAllowList_snapshot() public {
        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraDataAllowList
        });
        consideration.fulfillAdvancedOrder{ value: mintPrice * numMints }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testMintSigned_snapshot() public {
        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraDataSigned
        });
        consideration.fulfillAdvancedOrder{ value: mintPrice * numMints }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }
}
