// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721Test } from "./utils/SeaDrop721Test.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { MintParams, PublicDrop } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

contract ERC721SeaDropPlusRegularMint is ERC721SeaDrop {
    constructor(
        address allowedConfigurer,
        address allowedSeaport,
        string memory name,
        string memory symbol
    ) ERC721SeaDrop(allowedConfigurer, allowedSeaport, name, symbol) { }

    function mint(address recipient, uint256 quantity) public payable {
        _mint(recipient, quantity);
    }
}

/**
 * @dev Gas snapshots of a mint through Seaport for each SIP-12 substandard,
 *      next to a plain ERC721A mint. The orders leave the minter as the zero
 *      address, so the fulfiller (the test contract) is the minter.
 */
contract TestSeaDropSnapshot is SeaDrop721Test {
    address creator = makeAddr("creator");
    address feeRecipient = makeAddr("feeRecipient");
    uint256 feeBps = 500;

    uint256 mintPrice = 1 ether;
    uint256 numMints = 1;

    uint256 constant SIGNED_MINT_SALT = 123;

    MintParams allowListMintParams;
    bytes32[] allowListProof;
    MintParams signedMintParams;
    bytes signedMintSignature;

    function setUp() public override {
        super.setUp();

        token = new ERC721SeaDropPlusRegularMint(
            address(configurer), allowedSeaport, "", ""
        );
        token.setMaxSupply(1000);
        _setSingleCreatorPayout(address(token), creator);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);

        _configurePublic();
        _configureAllowList();
        _configureSigned();

        vm.deal(address(this), 100 ether);

        // Warm the contract offerer nonce storage slot to non-zero
        // by executing a first mint.
        testMintPublic_snapshot();
    }

    function _configurePublic() internal {
        _seaDrop()
            .updatePublicDrop(
                PublicDrop({
                    startPrice: uint80(mintPrice),
                    endPrice: uint80(mintPrice),
                    startTime: uint40(block.timestamp),
                    endTime: uint40(block.timestamp + 500),
                    paymentToken: address(0),
                    maxTotalMintableByWallet: 5,
                    feeBps: uint16(feeBps),
                    restrictFeeRecipients: true
                })
            );
    }

    function _configureAllowList() internal {
        allowListMintParams = MintParams({
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
        (bytes32 root, bytes32[] memory proof) =
            _allowListRootAndProof(allowList, allowListMintParams, 25);
        _updateAllowList(address(token), root);
        allowListProof = proof;
    }

    function _configureSigned() internal {
        _seaDrop().updateSigner(makeAddr("signer-doug"), true);

        signedMintParams = MintParams({
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

        (signedMintSignature,) = _signMint(
            "signer-doug",
            address(token),
            address(this),
            feeRecipient,
            signedMintParams,
            SIGNED_MINT_SALT
        );
    }

    function testRegularMint_snapshot() public {
        ERC721SeaDropPlusRegularMint(address(token)).mint{ value: 0.1 ether }(
            address(this), 1
        );
    }

    function testMintPublic_snapshot() public {
        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            address(token),
            numMints,
            feeRecipient,
            feeBps,
            mintPrice,
            address(0)
        );
        _fulfill(order, address(this), value);
    }

    function testMintAllowList_snapshot() public {
        (AdvancedOrder memory order, uint256 value) = _allowListMintOrder(
            address(token),
            numMints,
            feeRecipient,
            feeBps,
            mintPrice,
            address(0),
            allowListMintParams,
            allowListProof
        );
        _fulfill(order, address(this), value);
    }

    function testMintSigned_snapshot() public {
        (AdvancedOrder memory order, uint256 value) = _signedMintOrder(
            address(token),
            numMints,
            feeRecipient,
            feeBps,
            mintPrice,
            address(0),
            signedMintParams,
            SIGNED_MINT_SALT,
            signedMintSignature
        );
        _fulfill(order, address(this), value);
    }
}
