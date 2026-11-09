// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import "forge-std/Test.sol";

import { MintParams } from "seadrop/lib/SeaDropStructs.sol";

import { SeaDrop } from "seadrop/SeaDrop.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { SeaDropErrorsAndEvents } from "seadrop/lib/SeaDropErrorsAndEvents.sol";

import {
    ProxyAdmin
} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";

import {
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TestHelper is Test, SeaDropErrorsAndEvents {
    SeaDrop seadrop = new SeaDrop();
    ERC721SeaDrop token;

    address creator = makeAddr("creator");

    /// @notice Internal constants for EIP-712: Typed structured
    ///         data hashing and signing
    bytes32 internal constant _SIGNED_MINT_TYPEHASH =
    // prettier-ignore
    keccak256(
        "SignedMint(" "address nftContract," "address minter,"
        "address feeRecipient," "MintParams mintParams," "uint256 salt" ")"
        "MintParams(" "uint256 mintPrice," "uint256 maxTotalMintableByWallet,"
        "uint256 startTime," "uint256 endTime," "uint256 dropStageIndex,"
        "uint256 maxTokenSupplyForStage," "uint256 feeBps,"
        "bool restrictFeeRecipients" ")"
    );
    bytes32 internal constant _MINT_PARAMS_TYPEHASH =
    // prettier-ignore
    keccak256(
        "MintParams(" "uint256 mintPrice," "uint256 maxTotalMintableByWallet,"
        "uint256 startTime," "uint256 endTime," "uint256 dropStageIndex,"
        "uint256 maxTokenSupplyForStage," "uint256 feeBps,"
        "bool restrictFeeRecipients" ")"
    );
    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH =
    // prettier-ignore
    keccak256(
        "EIP712Domain(" "string name," "string version," "uint256 chainId,"
        "address verifyingContract" ")"
    );
    bytes32 internal constant _NAME_HASH = keccak256("SeaDrop");
    bytes32 internal constant _VERSION_HASH = keccak256("1.0");
    uint256 internal immutable _CHAIN_ID = block.chainid;
    bytes32 internal immutable _DOMAIN_SEPARATOR = _deriveDomainSeparator();

    struct FuzzInputs {
        uint40 numMints;
        address minter;
        address feeRecipient;
        address[10] allowList;
    }

    modifier validateArgs(FuzzInputs memory args) {
        vm.assume(args.numMints > 0 && args.numMints <= 10);
        vm.assume(args.minter != address(0) && args.feeRecipient != address(0));
        vm.assume(args.feeRecipient.code.length == 0);
        vm.assume(args.minter.code.length == 0);
        // Precompiles reject plain ETH transfers. Under Cancun that includes
        // the point-evaluation precompile at 0x0A, so skip all of 0x01-0xff.
        assumeNotPrecompile(args.feeRecipient);
        assumeNotPrecompile(args.minter);
        vm.assume(
            args.minter != args.feeRecipient && args.minter != creator
                && args.feeRecipient != creator
        );
        _;
    }

    /**
     * @dev Whether this test contract runs against the upgradeable token,
     *      ERC721SeaDropUpgradeable behind a transparent proxy, instead of
     *      ERC721SeaDrop. The test contracts in test/foundry/upgradeable
     *      override this to rerun the shared tests against it.
     */
    function _upgradeable() internal pure virtual returns (bool) {
        return false;
    }

    /**
     * @dev Deploy the token under test, owned by this contract. The
     *      upgradeable token has the same ABI as ERC721SeaDrop, so the tests
     *      drive both through the ERC721SeaDrop type.
     */
    function _newToken(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) internal returns (ERC721SeaDrop) {
        if (_upgradeable()) {
            return ERC721SeaDrop(
                _deployUpgradeable(
                    "ERC721SeaDropUpgradeable", name, symbol, allowedSeaDrop
                )
            );
        }
        return new ERC721SeaDrop(name, symbol, allowedSeaDrop);
    }

    /**
     * @dev Deploy an upgradeable token the way
     *      script/upgradeable/DeployERC721SeaDropUpgradeable.s.sol does: the
     *      implementation, a ProxyAdmin, and a TransparentUpgradeableProxy
     *      whose constructor calls initialize(name, symbol, allowedSeaDrop),
     *      which makes this contract the token owner.
     *
     *      The implementation deploys from its build artifact, so it keeps
     *      its deployable settings (via-IR, 1000 runs) and the shared tests
     *      that call this compile with the default settings.
     */
    function _deployUpgradeable(
        string memory contractName,
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) internal returns (address) {
        address implementation = vm.deployCode(
            string.concat(contractName, ".sol:", contractName)
        );
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        return address(
            new TransparentUpgradeableProxy(
                implementation,
                address(proxyAdmin),
                abi.encodeWithSignature(
                    "initialize(string,string,address[])",
                    name,
                    symbol,
                    allowedSeaDrop
                )
            )
        );
    }

    function _getSignatureComponents(
        string memory name,
        address nftContract,
        address minter,
        address feeRecipient,
        MintParams memory mintParams,
        uint256 salt
    ) internal returns (bytes32 r, bytes32 s, uint8 v) {
        bytes32 digest = _getDigest(
            nftContract, minter, feeRecipient, mintParams, salt
        );
        (, uint256 pk) = makeAddrAndKey(name);
        (v, r, s) = vm.sign(pk, digest);
    }

    function _getDigest(
        address nftContract,
        address minter,
        address feeRecipient,
        MintParams memory mintParams,
        uint256 salt
    ) internal view returns (bytes32 digest) {
        bytes32 mintParamsHashStruct = keccak256(
            abi.encode(
                _MINT_PARAMS_TYPEHASH,
                mintParams.mintPrice,
                mintParams.maxTotalMintableByWallet,
                mintParams.startTime,
                mintParams.endTime,
                mintParams.dropStageIndex,
                mintParams.maxTokenSupplyForStage,
                mintParams.feeBps,
                mintParams.restrictFeeRecipients
            )
        );
        digest = keccak256(
            bytes.concat(
                bytes2(0x1901),
                _DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        _SIGNED_MINT_TYPEHASH,
                        nftContract,
                        minter,
                        feeRecipient,
                        mintParamsHashStruct,
                        salt
                    )
                )
            )
        );
    }

    function _encodeSignature2098(bytes32 r, bytes32 s, uint8 v)
        internal
        pure
        returns (bytes memory)
    {
        uint256 yParity;
        if (v == 27) {
            yParity = 0;
        } else {
            yParity = 1;
        }
        uint256 yParityAndS = (yParity << 255) | uint256(s);
        return abi.encodePacked(r, yParityAndS);
    }

    function _deriveDomainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(seadrop)
            )
        );
    }
}
