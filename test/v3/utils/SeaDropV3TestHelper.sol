// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { Test } from "forge-std/Test.sol";

import { SeaDropMinter } from "seadrop/v3/SeaDropMinter.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { ERC721SeaDropV3 } from "seadrop/v3/ERC721SeaDropV3.sol";

import { ERC1155SeaDropV3 } from "seadrop/v3/ERC1155SeaDropV3.sol";

/**
 * @dev Deploys the minter and both v3 tokens with one public ETH stage,
 *      and signs authorizations and intents independently of the minter's
 *      own hashing.
 */
abstract contract SeaDropV3TestHelper is Test {
    uint256 internal constant PRICE = 0.1 ether;
    uint256 internal constant FEE_BPS = 100;
    uint256 internal constant ID_1155 = 7;
    uint256 internal constant MAX_SUPPLY = 100;
    uint32 internal constant MAX_PER_WALLET = 5;
    /// @dev OpenSea's conduit on most chains, preapproved on the test tokens.
    address internal constant CONDUIT =
        0x1E0049783F008A0085193E00003D00cd54003c71;

    // Independent copies of the minter's EIP-712 types.
    bytes32 internal constant AUTHORIZATION_TYPEHASH = keccak256(
        "MintAuthorization(address token,uint256 id,uint256 stageIndex,"
        "address wallet,address sender,address currency,uint256 maxQuantity,"
        "bool hasPrice,uint256 price,uint256 expiry)"
    );
    bytes32 internal constant PARAMS_TYPEHASH = keccak256(
        "MintParams(address token,uint256 id,uint256 stageIndex,"
        "address wallet,address recipient,uint256 quantity,"
        "address currency,uint256 maxTotalPrice)"
    );
    bytes32 internal constant INTENT_TYPEHASH = keccak256(
        "MintIntent(MintParams params,uint256 nonce,uint256 expiry)"
        "MintParams(address token,uint256 id,uint256 stageIndex,"
        "address wallet,address recipient,uint256 quantity,"
        "address currency,uint256 maxTotalPrice)"
    );

    SeaDropMinter internal minter;
    ERC721SeaDropV3 internal token721;
    ERC1155SeaDropV3 internal token1155;

    address internal creator = makeAddr("creator");
    address internal feeRecipient = makeAddr("feeRecipient");
    address internal alice;
    uint256 internal aliceKey;
    address internal bob;
    uint256 internal bobKey;
    address internal carol = makeAddr("carol");
    address internal signer;
    uint256 internal signerKey;

    function setUp() public virtual {
        (alice, aliceKey) = makeAddrAndKey("alice");
        (bob, bobKey) = makeAddrAndKey("bob");
        (signer, signerKey) = makeAddrAndKey("signer");

        minter = new SeaDropMinter(address(this));
        minter.setCurrency(
            address(0),
            ISeaDropMinter.CurrencyConfig({
                allowed: true,
                minFeeBps: uint16(FEE_BPS),
                feeRecipient: feeRecipient
            })
        );

        token721 = new ERC721SeaDropV3("Test", "TEST", address(minter), CONDUIT);
        token721.setMaxSupply(MAX_SUPPLY);
        token1155 = new ERC1155SeaDropV3(address(minter), CONDUIT);
        token1155.setMaxSupply(ID_1155, uint128(MAX_SUPPLY));

        _setSinglePayout(address(token721), creator);
        _setSinglePayout(address(token1155), creator);
        minter.setStage(address(token721), 0, 0, _publicStage());
        minter.setStage(address(token1155), ID_1155, 0, _publicStage());

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function _publicStage()
        internal
        view
        returns (ISeaDropMinter.Stage memory)
    {
        return ISeaDropMinter.Stage({
            price: uint96(PRICE),
            currency: address(0),
            startTime: uint40(vm.getBlockTimestamp()),
            endTime: uint40(vm.getBlockTimestamp() + 1000),
            feeBps: uint16(FEE_BPS),
            feeRecipient: feeRecipient,
            maxPerWallet: MAX_PER_WALLET,
            signerSetId: 0,
            signer: address(0)
        });
    }

    function _setSinglePayout(address token, address recipient) internal {
        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](1);
        recipients[0] = ISeaDropMinter.PayoutRecipient(recipient, 10_000);
        minter.setPayoutRecipients(token, recipients);
    }

    /// @dev ETH mint params for `wallet`, priced at the public stage price.
    function _params(
        address token,
        uint256 id,
        address wallet,
        address recipient,
        uint256 quantity
    ) internal pure returns (ISeaDropMinter.MintParams memory) {
        return ISeaDropMinter.MintParams({
            token: token,
            id: id,
            stageIndex: 0,
            wallet: wallet,
            recipient: recipient,
            quantity: quantity,
            currency: address(0),
            maxTotalPrice: PRICE * quantity
        });
    }

    function _noAuth()
        internal
        pure
        returns (ISeaDropMinter.Authorization memory none)
    { }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,"
                    "address verifyingContract)"
                ),
                keccak256("SeaDrop"),
                keccak256("3"),
                block.chainid,
                address(minter)
            )
        );
    }

    function _authorizationDigest(
        ISeaDropMinter.MintParams memory params,
        ISeaDropMinter.Authorization memory authorization
    ) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                AUTHORIZATION_TYPEHASH,
                params.token,
                params.id,
                params.stageIndex,
                params.wallet,
                authorization.sender,
                authorization.currency,
                authorization.maxQuantity,
                authorization.hasPrice,
                authorization.price,
                authorization.expiry
            )
        );
        return keccak256(
            abi.encodePacked("\x19\x01", _domainSeparator(), structHash)
        );
    }

    /// @dev An authorization for `params`, signed by `key` on behalf of
    ///      `authSigner` (the key's own address, or an ERC-1271 contract).
    function _authorize(
        ISeaDropMinter.MintParams memory params,
        address authSigner,
        uint256 key,
        uint256 maxQuantity,
        bool hasPrice,
        uint256 price
    ) internal view returns (ISeaDropMinter.Authorization memory auth) {
        auth = ISeaDropMinter.Authorization({
            signer: authSigner,
            sender: address(0),
            currency: params.currency,
            maxQuantity: maxQuantity,
            hasPrice: hasPrice,
            price: price,
            expiry: vm.getBlockTimestamp() + 100,
            signature: ""
        });
        auth.signature = _sign(key, _authorizationDigest(params, auth));
    }

    /// @dev An authorization from `signer` that links `sender` to
    ///      `params.wallet`, with no overrides.
    function _authorizeLinked(
        ISeaDropMinter.MintParams memory params,
        address sender
    ) internal view returns (ISeaDropMinter.Authorization memory auth) {
        auth = ISeaDropMinter.Authorization({
            signer: signer,
            sender: sender,
            currency: params.currency,
            maxQuantity: 0,
            hasPrice: false,
            price: 0,
            expiry: vm.getBlockTimestamp() + 100,
            signature: ""
        });
        auth.signature = _sign(signerKey, _authorizationDigest(params, auth));
    }

    function _intentDigest(ISeaDropMinter.MintIntent memory intent)
        internal
        view
        returns (bytes32)
    {
        ISeaDropMinter.MintParams memory p = intent.params;
        bytes32 paramsHash = keccak256(
            abi.encode(
                PARAMS_TYPEHASH,
                p.token,
                p.id,
                p.stageIndex,
                p.wallet,
                p.recipient,
                p.quantity,
                p.currency,
                p.maxTotalPrice
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(INTENT_TYPEHASH, paramsHash, intent.nonce, intent.expiry)
        );
        return keccak256(
            abi.encodePacked("\x19\x01", _domainSeparator(), structHash)
        );
    }

    function _sign(uint256 key, bytes32 digest)
        internal
        pure
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}
