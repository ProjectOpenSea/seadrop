// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropV3TestHelper } from "./utils/SeaDropV3TestHelper.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { SeaDropTokenV3Base } from "seadrop/v3/SeaDropTokenV3Base.sol";

import { ERC721SeaDropV3 } from "seadrop/v3/ERC721SeaDropV3.sol";

import {
    ERC721SeaDropV3Standalone
} from "seadrop/v3/ERC721SeaDropV3Standalone.sol";

import { ERC1155SeaDropV3 } from "seadrop/v3/ERC1155SeaDropV3.sol";

import {
    ERC1155SeaDropV3Standalone
} from "seadrop/v3/ERC1155SeaDropV3Standalone.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

/// @dev Observes `token.owner()` from a third-party address during a callback.
contract OwnerObserver {
    function readOwner(address token) external view returns (address) {
        return TwoStepOwnable(token).owner();
    }
}

/// @dev Allowed minter that probes `owner()` visibility and reentrancy during
///      `multiConfigure`.
contract ReentrantMinterProbe {
    OwnerObserver public immutable observer = new OwnerObserver();
    address public observedByMinter;
    address public observedByThirdParty;
    bool public tokenSetterReverted;
    bool public realMinterOwnerMintReverted;
    address public immutable realMinter;

    constructor(address realMinter_) {
        realMinter = realMinter_;
    }

    function setPayoutRecipients(
        address token,
        ISeaDropMinter.PayoutRecipient[] calldata
    ) external {
        observedByMinter = TwoStepOwnable(token).owner();
        observedByThirdParty = observer.readOwner(token);

        try ERC721SeaDropV3(token).setBaseURI("ipfs://hijack/") {
            tokenSetterReverted = false;
        } catch {
            tokenSetterReverted = true;
        }

        try ISeaDropMinter(realMinter).ownerMint(token, 0, address(this), 1) {
            realMinterOwnerMintReverted = false;
        } catch {
            realMinterOwnerMintReverted = true;
        }
    }
}

contract SeaDropV3MultiConfigureTest is SeaDropV3TestHelper {
    event MaxSupplyUpdated(uint256 maxSupply);
    event MaxSupplyUpdated(uint256 indexed id, uint256 maxSupply);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event ContractURIUpdated();

    function test_ERC721_multiConfigure_allFieldsAndMint() public {
        ERC721SeaDropV3 fresh = ERC721SeaDropV3(
            factory.createERC721("Fresh", "FRSH", bytes32(uint256(1)))
        );

        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](2);
        recipients[0] = ISeaDropMinter.PayoutRecipient(creator, 7_500);
        recipients[1] = ISeaDropMinter.PayoutRecipient(carol, 2_500);

        ISeaDropMinter.Stage memory stage0 = _publicStage();
        ISeaDropMinter.Stage memory stage1 = _publicStage();
        stage1.price = 0.2 ether;
        stage1.signer = signer;
        stage1.maxPerWallet = 2;

        ERC721SeaDropV3.StageConfig[] memory stages =
            new ERC721SeaDropV3.StageConfig[](2);
        stages[0] =
            ERC721SeaDropV3.StageConfig({ stageIndex: 0, stage: stage0 });
        stages[1] =
            ERC721SeaDropV3.StageConfig({ stageIndex: 1, stage: stage1 });

        vm.expectEmit(address(fresh));
        emit MaxSupplyUpdated(250);
        vm.expectEmit(address(fresh));
        emit BatchMetadataUpdate(0, type(uint256).max);
        vm.expectEmit(address(fresh));
        emit ContractURIUpdated();
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.PayoutRecipientsUpdated(
            minter.CONFIG_EVENT_VERSION(),
            address(fresh),
            recipients
        );
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.StageUpdated(
            minter.CONFIG_EVENT_VERSION(),
            address(fresh),
            0,
            0,
            stage0
        );
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.StageUpdated(
            minter.CONFIG_EVENT_VERSION(),
            address(fresh),
            0,
            1,
            stage1
        );

        fresh.multiConfigure(
            ERC721SeaDropV3.MultiConfigureStruct({
                maxSupply: 250,
                baseURI: "ipfs://fresh/",
                contractURI: "ipfs://fresh-contract",
                minter: address(minter),
                payoutRecipients: recipients,
                stages: stages
            })
        );

        assertEq(fresh.owner(), address(this));
        assertEq(fresh.maxSupply(), 250);
        assertEq(fresh.contractURI(), "ipfs://fresh-contract");

        ISeaDropMinter.PayoutRecipient[] memory storedRecipients =
            minter.getPayoutRecipients(address(fresh));
        assertEq(storedRecipients.length, 2);
        assertEq(storedRecipients[0].recipient, creator);
        assertEq(storedRecipients[0].bps, 7_500);
        assertEq(storedRecipients[1].recipient, carol);
        assertEq(storedRecipients[1].bps, 2_500);

        ISeaDropMinter.Stage memory storedStage0 =
            minter.getStage(address(fresh), 0, 0);
        assertEq(storedStage0.price, stage0.price);
        assertEq(storedStage0.maxPerWallet, stage0.maxPerWallet);

        ISeaDropMinter.Stage memory storedStage1 =
            minter.getStage(address(fresh), 0, 1);
        assertEq(storedStage1.price, 0.2 ether);
        assertEq(storedStage1.signer, signer);

        // Mint end-to-end against the configured drop.
        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(fresh), 0, alice, alice, 1), _noAuth()
        );
        assertEq(fresh.ownerOf(1), alice);
        assertEq(fresh.tokenURI(1), "ipfs://fresh/1");
    }

    function test_ERC721_multiConfigure_skipsZeroAndEmptyFields() public {
        token721.setBaseURI("ipfs://keep/");
        token721.setContractURI("ipfs://keep-contract");

        ERC721SeaDropV3.MultiConfigureStruct memory empty;
        token721.multiConfigure(empty);

        assertEq(token721.maxSupply(), MAX_SUPPLY);
        assertEq(token721.contractURI(), "ipfs://keep-contract");
        minter.ownerMint(address(token721), 0, alice, 1);
        assertEq(token721.tokenURI(1), "ipfs://keep/1");
    }

    function test_ERC721_multiConfigure_tokenOnlyWithZeroMinter() public {
        ERC721SeaDropV3.MultiConfigureStruct memory config;
        config.maxSupply = 500;
        config.baseURI = "ipfs://only-token/";
        config.contractURI = "ipfs://only-contract";

        token721.multiConfigure(config);

        assertEq(token721.maxSupply(), 500);
        assertEq(token721.contractURI(), "ipfs://only-contract");
        minter.ownerMint(address(token721), 0, alice, 1);
        assertEq(token721.tokenURI(1), "ipfs://only-token/1");
    }

    function test_ERC721_multiConfigure_clearStage() public {
        ERC721SeaDropV3.StageConfig[] memory stages =
            new ERC721SeaDropV3.StageConfig[](1);
        ISeaDropMinter.Stage memory cleared;
        stages[0] =
            ERC721SeaDropV3.StageConfig({ stageIndex: 0, stage: cleared });

        ERC721SeaDropV3.MultiConfigureStruct memory config;
        config.minter = address(minter);
        config.stages = stages;
        token721.multiConfigure(config);

        assertEq(minter.getStage(address(token721), 0, 0).endTime, 0);
    }

    function test_ERC721_multiConfigure_revert_notOwner() public {
        ERC721SeaDropV3.MultiConfigureStruct memory config;
        config.maxSupply = 10;

        vm.prank(alice);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token721.multiConfigure(config);
    }

    function test_ERC721_multiConfigure_revert_disallowedMinter() public {
        ERC721SeaDropV3.StageConfig[] memory stages =
            new ERC721SeaDropV3.StageConfig[](1);
        stages[0] = ERC721SeaDropV3.StageConfig({
            stageIndex: 0,
            stage: _publicStage()
        });

        ERC721SeaDropV3.MultiConfigureStruct memory config;
        config.minter = alice;
        config.stages = stages;

        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.OnlyAllowedMinter.selector, alice
            )
        );
        token721.multiConfigure(config);
    }

    function test_ERC721_multiConfigure_revert_maxSupplyBelowMinted() public {
        minter.ownerMint(address(token721), 0, alice, 5);

        ERC721SeaDropV3.MultiConfigureStruct memory config;
        config.maxSupply = 4;

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3.MaxSupplyBelowTotalMinted.selector, 4, 5
            )
        );
        token721.multiConfigure(config);
    }

    function test_ERC721_multiConfigure_revert_invalidPayoutBps() public {
        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](1);
        recipients[0] = ISeaDropMinter.PayoutRecipient(creator, 9_999);

        ERC721SeaDropV3.MultiConfigureStruct memory config;
        config.minter = address(minter);
        config.payoutRecipients = recipients;

        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.PayoutBpsTotalNot10000.selector, 9_999
            )
        );
        token721.multiConfigure(config);
    }

    function test_ERC721_multiConfigure_ownerVisibilityScopedToActiveMinter()
        public
    {
        ReentrantMinterProbe probe = new ReentrantMinterProbe(address(minter));
        token721.setAllowedMinter(address(probe), true);

        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](1);
        recipients[0] = ISeaDropMinter.PayoutRecipient(creator, 10_000);

        ERC721SeaDropV3.MultiConfigureStruct memory config;
        config.minter = address(probe);
        config.payoutRecipients = recipients;
        token721.multiConfigure(config);

        assertEq(probe.observedByMinter(), address(token721));
        assertEq(probe.observedByThirdParty(), address(this));
        assertTrue(probe.tokenSetterReverted());
        assertTrue(probe.realMinterOwnerMintReverted());
        assertEq(token721.owner(), address(this));
    }

    function test_ERC721Standalone_multiConfigure() public {
        ERC721SeaDropV3Standalone standalone = new ERC721SeaDropV3Standalone(
            address(this), address(minter), "Standalone", "STND", CONDUIT
        );

        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](1);
        recipients[0] = ISeaDropMinter.PayoutRecipient(creator, 10_000);

        ERC721SeaDropV3.StageConfig[] memory stages =
            new ERC721SeaDropV3.StageConfig[](1);
        stages[0] = ERC721SeaDropV3.StageConfig({
            stageIndex: 0,
            stage: _publicStage()
        });

        standalone.multiConfigure(
            ERC721SeaDropV3.MultiConfigureStruct({
                maxSupply: 50,
                baseURI: "ipfs://stnd/",
                contractURI: "ipfs://stnd-contract",
                minter: address(minter),
                payoutRecipients: recipients,
                stages: stages
            })
        );

        assertEq(standalone.maxSupply(), 50);
        assertEq(standalone.contractURI(), "ipfs://stnd-contract");
        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(standalone), 0, alice, alice, 1), _noAuth()
        );
        assertEq(standalone.ownerOf(1), alice);
    }

    function test_ERC1155_multiConfigure_allFieldsAndMint() public {
        ERC1155SeaDropV3 fresh =
            ERC1155SeaDropV3(factory.createERC1155(bytes32(uint256(1))));

        ERC1155SeaDropV3.MaxSupplyConfig[] memory maxSupplies =
            new ERC1155SeaDropV3.MaxSupplyConfig[](2);
        maxSupplies[0] =
            ERC1155SeaDropV3.MaxSupplyConfig({ id: 1, maxSupply: 100 });
        maxSupplies[1] =
            ERC1155SeaDropV3.MaxSupplyConfig({ id: 2, maxSupply: 200 });

        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](2);
        recipients[0] = ISeaDropMinter.PayoutRecipient(creator, 6_000);
        recipients[1] = ISeaDropMinter.PayoutRecipient(carol, 4_000);

        ISeaDropMinter.Stage memory stage1 = _publicStage();
        ISeaDropMinter.Stage memory stage2 = _publicStage();
        stage2.price = 0.25 ether;

        ERC1155SeaDropV3.StageConfig[] memory stages =
            new ERC1155SeaDropV3.StageConfig[](2);
        stages[0] = ERC1155SeaDropV3.StageConfig({
            id: 1,
            stageIndex: 0,
            stage: stage1
        });
        stages[1] = ERC1155SeaDropV3.StageConfig({
            id: 2,
            stageIndex: 1,
            stage: stage2
        });

        vm.expectEmit(address(fresh));
        emit MaxSupplyUpdated(1, 100);
        vm.expectEmit(address(fresh));
        emit MaxSupplyUpdated(2, 200);
        vm.expectEmit(address(fresh));
        emit BatchMetadataUpdate(0, type(uint256).max);
        vm.expectEmit(address(fresh));
        emit ContractURIUpdated();
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.PayoutRecipientsUpdated(
            minter.CONFIG_EVENT_VERSION(),
            address(fresh),
            recipients
        );
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.StageUpdated(
            minter.CONFIG_EVENT_VERSION(),
            address(fresh),
            1,
            0,
            stage1
        );
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.StageUpdated(
            minter.CONFIG_EVENT_VERSION(),
            address(fresh),
            2,
            1,
            stage2
        );

        fresh.multiConfigure(
            ERC1155SeaDropV3.MultiConfigureStruct({
                maxSupplies: maxSupplies,
                uri: "ipfs://editions/{id}",
                contractURI: "ipfs://editions-contract",
                minter: address(minter),
                payoutRecipients: recipients,
                stages: stages
            })
        );

        assertEq(fresh.owner(), address(this));
        (, uint256 max1) = fresh.mintStats(1);
        (, uint256 max2) = fresh.mintStats(2);
        assertEq(max1, 100);
        assertEq(max2, 200);
        assertEq(fresh.uri(1), "ipfs://editions/{id}");
        assertEq(fresh.contractURI(), "ipfs://editions-contract");
        assertEq(minter.getStage(address(fresh), 1, 0).price, PRICE);
        assertEq(minter.getStage(address(fresh), 2, 1).price, 0.25 ether);

        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(fresh), 1, alice, alice, 1), _noAuth()
        );
        assertEq(fresh.balanceOf(alice, 1), 1);
    }

    function test_ERC1155_multiConfigure_skipsEmptyFields() public {
        token1155.setURI("ipfs://keep/{id}");
        token1155.setContractURI("ipfs://keep-1155");

        ERC1155SeaDropV3.MultiConfigureStruct memory empty;
        token1155.multiConfigure(empty);

        (, uint256 max) = token1155.mintStats(ID_1155);
        assertEq(max, MAX_SUPPLY);
        assertEq(token1155.uri(ID_1155), "ipfs://keep/{id}");
        assertEq(token1155.contractURI(), "ipfs://keep-1155");
    }

    function test_ERC1155_multiConfigure_revert_notOwner() public {
        ERC1155SeaDropV3.MultiConfigureStruct memory config;
        config.uri = "ipfs://nope/{id}";

        vm.prank(alice);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token1155.multiConfigure(config);
    }

    function test_ERC1155_multiConfigure_revert_disallowedMinter() public {
        ERC1155SeaDropV3.StageConfig[] memory stages =
            new ERC1155SeaDropV3.StageConfig[](1);
        stages[0] = ERC1155SeaDropV3.StageConfig({
            id: ID_1155,
            stageIndex: 0,
            stage: _publicStage()
        });

        ERC1155SeaDropV3.MultiConfigureStruct memory config;
        config.minter = alice;
        config.stages = stages;

        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.OnlyAllowedMinter.selector, alice
            )
        );
        token1155.multiConfigure(config);
    }

    function test_ERC1155_multiConfigure_revert_maxSupplyIdZero() public {
        ERC1155SeaDropV3.MaxSupplyConfig[] memory maxSupplies =
            new ERC1155SeaDropV3.MaxSupplyConfig[](1);
        maxSupplies[0] =
            ERC1155SeaDropV3.MaxSupplyConfig({ id: 0, maxSupply: 10 });

        ERC1155SeaDropV3.MultiConfigureStruct memory config;
        config.maxSupplies = maxSupplies;

        vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
        token1155.multiConfigure(config);
    }

    function test_ERC1155_multiConfigure_revert_stageIdZero() public {
        ERC1155SeaDropV3.StageConfig[] memory stages =
            new ERC1155SeaDropV3.StageConfig[](1);
        stages[0] = ERC1155SeaDropV3.StageConfig({
            id: 0,
            stageIndex: 0,
            stage: _publicStage()
        });

        ERC1155SeaDropV3.MultiConfigureStruct memory config;
        config.minter = address(minter);
        config.stages = stages;

        vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
        token1155.multiConfigure(config);
    }

    function test_ERC1155Standalone_multiConfigure() public {
        ERC1155SeaDropV3Standalone standalone = new ERC1155SeaDropV3Standalone(
            address(this), address(minter), "ipfs://init/{id}", CONDUIT
        );

        ERC1155SeaDropV3.MaxSupplyConfig[] memory maxSupplies =
            new ERC1155SeaDropV3.MaxSupplyConfig[](1);
        maxSupplies[0] =
            ERC1155SeaDropV3.MaxSupplyConfig({ id: 3, maxSupply: 40 });

        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](1);
        recipients[0] = ISeaDropMinter.PayoutRecipient(creator, 10_000);

        ERC1155SeaDropV3.StageConfig[] memory stages =
            new ERC1155SeaDropV3.StageConfig[](1);
        stages[0] = ERC1155SeaDropV3.StageConfig({
            id: 3,
            stageIndex: 0,
            stage: _publicStage()
        });

        standalone.multiConfigure(
            ERC1155SeaDropV3.MultiConfigureStruct({
                maxSupplies: maxSupplies,
                uri: "ipfs://updated/{id}",
                contractURI: "ipfs://stnd-1155",
                minter: address(minter),
                payoutRecipients: recipients,
                stages: stages
            })
        );

        (, uint256 max) = standalone.mintStats(3);
        assertEq(max, 40);
        assertEq(standalone.uri(3), "ipfs://updated/{id}");
        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(standalone), 3, alice, alice, 1), _noAuth()
        );
        assertEq(standalone.balanceOf(alice, 3), 1);
    }

    struct FuzzERC721Input {
        uint64 maxSupply;
        uint256 stageIndex;
        uint96 price;
        uint40 startTime;
        uint40 duration;
        uint32 maxPerWallet;
        uint16 firstBps;
        string baseURI;
        string contractURI;
    }

    struct FuzzERC1155Input {
        uint256 id1;
        uint256 id2;
        uint128 max1;
        uint128 max2;
        uint256 stageIndex1;
        uint256 stageIndex2;
        uint96 price;
        uint40 startTime;
        uint40 duration;
        uint16 firstBps;
        string uri;
        string contractURI;
    }

    function testFuzz_ERC721_multiConfigure(FuzzERC721Input calldata f) public {
        vm.assume(f.stageIndex != minter.OWNER_MINT_STAGE());
        uint16 firstBps = uint16(bound(f.firstBps, 1, 9_999));
        uint40 endTime = f.startTime > type(uint40).max - f.duration
            ? type(uint40).max
            : f.startTime + f.duration;
        if (endTime == 0) endTime = 1;

        uint256 prevMax = token721.maxSupply();
        string memory prevContractURI = token721.contractURI();

        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](2);
        recipients[0] = ISeaDropMinter.PayoutRecipient(creator, firstBps);
        recipients[1] =
            ISeaDropMinter.PayoutRecipient(carol, uint16(10_000 - firstBps));

        ERC721SeaDropV3.StageConfig[] memory stages =
            new ERC721SeaDropV3.StageConfig[](1);
        stages[0] = ERC721SeaDropV3.StageConfig({
            stageIndex: f.stageIndex,
            stage: ISeaDropMinter.Stage({
                price: f.price,
                currency: address(0),
                startTime: f.startTime,
                endTime: endTime,
                feeBps: uint16(FEE_BPS),
                feeRecipient: feeRecipient,
                maxPerWallet: f.maxPerWallet,
                maxTokenSupplyForStage: 0,
                signerSetId: 0,
                signer: address(0)
            })
        });

        token721.multiConfigure(
            ERC721SeaDropV3.MultiConfigureStruct({
                maxSupply: f.maxSupply,
                baseURI: f.baseURI,
                contractURI: f.contractURI,
                minter: address(minter),
                payoutRecipients: recipients,
                stages: stages
            })
        );

        assertEq(token721.owner(), address(this));
        assertEq(token721.maxSupply(), f.maxSupply > 0 ? f.maxSupply : prevMax);
        assertEq(
            token721.contractURI(),
            bytes(f.contractURI).length != 0 ? f.contractURI : prevContractURI
        );

        ISeaDropMinter.PayoutRecipient[] memory storedRecipients =
            minter.getPayoutRecipients(address(token721));
        assertEq(storedRecipients.length, 2);
        assertEq(storedRecipients[0].bps, firstBps);
        assertEq(storedRecipients[1].bps, 10_000 - firstBps);

        ISeaDropMinter.Stage memory storedStage =
            minter.getStage(address(token721), 0, f.stageIndex);
        assertEq(storedStage.price, f.price);
        assertEq(storedStage.startTime, f.startTime);
        assertEq(storedStage.endTime, endTime);
        assertEq(storedStage.maxPerWallet, f.maxPerWallet);
    }

    function testFuzz_ERC1155_multiConfigure(FuzzERC1155Input calldata f)
        public
    {
        uint256 id1 = bound(f.id1, 1, type(uint128).max);
        uint256 id2 = bound(f.id2, 1, type(uint128).max);
        vm.assume(id1 != id2);
        vm.assume(f.stageIndex1 != minter.OWNER_MINT_STAGE());
        vm.assume(f.stageIndex2 != minter.OWNER_MINT_STAGE());

        uint16 firstBps = uint16(bound(f.firstBps, 1, 9_999));
        uint40 endTime = f.startTime > type(uint40).max - f.duration
            ? type(uint40).max
            : f.startTime + f.duration;
        if (endTime == 0) endTime = 1;

        string memory prevURI = token1155.uri(id1);
        string memory prevContractURI = token1155.contractURI();

        {
            ERC1155SeaDropV3.MaxSupplyConfig[] memory maxSupplies =
                new ERC1155SeaDropV3.MaxSupplyConfig[](2);
            maxSupplies[0] = ERC1155SeaDropV3.MaxSupplyConfig({
                id: id1,
                maxSupply: f.max1
            });
            maxSupplies[1] = ERC1155SeaDropV3.MaxSupplyConfig({
                id: id2,
                maxSupply: f.max2
            });

            ISeaDropMinter.PayoutRecipient[] memory recipients =
                new ISeaDropMinter.PayoutRecipient[](2);
            recipients[0] = ISeaDropMinter.PayoutRecipient(creator, firstBps);
            recipients[1] = ISeaDropMinter.PayoutRecipient(
                carol, uint16(10_000 - firstBps)
            );

            ISeaDropMinter.Stage memory stage = ISeaDropMinter.Stage({
                price: f.price,
                currency: address(0),
                startTime: f.startTime,
                endTime: endTime,
                feeBps: uint16(FEE_BPS),
                feeRecipient: feeRecipient,
                maxPerWallet: MAX_PER_WALLET,
                maxTokenSupplyForStage: 0,
                signerSetId: 0,
                signer: address(0)
            });

            ERC1155SeaDropV3.StageConfig[] memory stages =
                new ERC1155SeaDropV3.StageConfig[](2);
            stages[0] = ERC1155SeaDropV3.StageConfig({
                id: id1,
                stageIndex: f.stageIndex1,
                stage: stage
            });
            stages[1] = ERC1155SeaDropV3.StageConfig({
                id: id2,
                stageIndex: f.stageIndex2,
                stage: stage
            });

            token1155.multiConfigure(
                ERC1155SeaDropV3.MultiConfigureStruct({
                    maxSupplies: maxSupplies,
                    uri: f.uri,
                    contractURI: f.contractURI,
                    minter: address(minter),
                    payoutRecipients: recipients,
                    stages: stages
                })
            );
        }

        assertEq(token1155.owner(), address(this));
        (, uint256 storedMax1) = token1155.mintStats(id1);
        (, uint256 storedMax2) = token1155.mintStats(id2);
        assertEq(storedMax1, f.max1);
        assertEq(storedMax2, f.max2);
        assertEq(token1155.uri(id1), bytes(f.uri).length != 0 ? f.uri : prevURI);
        assertEq(
            token1155.contractURI(),
            bytes(f.contractURI).length != 0 ? f.contractURI : prevContractURI
        );
        assertEq(
            minter.getStage(address(token1155), id1, f.stageIndex1).price,
            f.price
        );
        assertEq(
            minter.getStage(address(token1155), id2, f.stageIndex2).price,
            f.price
        );
    }
}
