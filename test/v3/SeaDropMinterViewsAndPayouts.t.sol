// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropV3TestHelper } from "./utils/SeaDropV3TestHelper.sol";

import { NotASeaDropToken } from "./utils/Mocks.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { ERC1155SeaDropV3 } from "seadrop/v3/ERC1155SeaDropV3.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @dev Minimal EIP-1967 transparent-style proxy reading the implementation
///      from the canonical EIP-1967 slot on every call (matching USDC's
///      FiatTokenProxy delegatecall overhead).
contract MinimalERC1967Proxy {
    // keccak256("eip1967.proxy.implementation") - 1
    bytes32 internal constant _IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address impl) {
        assembly {
            sstore(_IMPL_SLOT, impl)
        }
    }

    fallback() external payable {
        assembly {
            let impl := sload(_IMPL_SLOT)
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/// @dev USDC-like FiatTokenV2 implementation: checks `paused`, `blacklisted`
///      for both sender and recipient, updates balances and emits `Transfer`.
contract MockFiatTokenV2 {
    bool public paused;
    mapping(address => bool) public blacklisted;
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function setBlacklisted(address account, bool flag) external {
        blacklisted[account] = flag;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        require(!paused, "paused");
        require(!blacklisted[msg.sender], "blacklisted");
        require(!blacklisted[spender], "blacklisted");
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(!paused, "paused");
        require(!blacklisted[msg.sender], "blacklisted");
        require(!blacklisted[to], "blacklisted");
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        returns (bool)
    {
        require(!paused, "paused");
        require(!blacklisted[msg.sender], "blacklisted");
        require(!blacklisted[from], "blacklisted");
        require(!blacklisted[to], "blacklisted");
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= amount, "allowance");
        unchecked {
            _allowances[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "zero");
        uint256 fromBal = _balances[from];
        require(fromBal >= amount, "balance");
        unchecked {
            _balances[from] = fromBal - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}

contract SeaDropMinterViewsAndPayoutsTest is SeaDropV3TestHelper {
    // -------------------------------------------------------------------------
    // getCheckoutSnapshot
    // -------------------------------------------------------------------------

    function test_getCheckoutSnapshot_ERC721_tracksMintsAndPolicy() public {
        (
            ISeaDropMinter.Stage memory stage,
            ISeaDropMinter.CurrencyConfig memory currencyConfig,
            uint256 walletMinted,
            uint256 totalMinted,
            uint256 maxSupply,
            uint256 payoutRecipientCount
        ) = minter.getCheckoutSnapshot(address(token721), 0, 0, alice);

        assertEq(stage.price, PRICE);
        assertEq(stage.currency, address(0));
        assertEq(stage.maxPerWallet, MAX_PER_WALLET);
        assertTrue(currencyConfig.allowed);
        assertEq(currencyConfig.minFeeBps, FEE_BPS);
        assertEq(currencyConfig.feeRecipient, feeRecipient);
        assertEq(walletMinted, 0);
        assertEq(totalMinted, 0);
        assertEq(maxSupply, MAX_SUPPLY);
        assertEq(payoutRecipientCount, 1);

        // Owner mint raises totalMinted without counting toward alice's wallet.
        minter.ownerMint(address(token721), 0, alice, 2);
        // Paid mint raises both totalMinted and alice's walletMinted.
        vm.prank(alice);
        minter.mint{ value: PRICE * 3 }(
            _params(address(token721), 0, alice, alice, 3), _noAuth()
        );

        (,, walletMinted, totalMinted, maxSupply, payoutRecipientCount) =
            minter.getCheckoutSnapshot(address(token721), 0, 0, alice);

        assertEq(walletMinted, 3);
        assertEq(totalMinted, 5);
        assertEq(maxSupply, MAX_SUPPLY);
        assertEq(payoutRecipientCount, 1);

        // Policy update reflects immediately in currencyConfig.
        minter.setCurrency(
            address(0),
            ISeaDropMinter.CurrencyConfig({
                allowed: false,
                minFeeBps: 500,
                feeRecipient: carol
            })
        );
        (, currencyConfig,,,,) =
            minter.getCheckoutSnapshot(address(token721), 0, 0, alice);
        assertFalse(currencyConfig.allowed);
        assertEq(currencyConfig.minFeeBps, 500);
        assertEq(currencyConfig.feeRecipient, carol);
    }

    function test_getCheckoutSnapshot_ERC1155_perIdAndUnsetStage() public {
        token1155.setMaxSupply(ID_1155 + 1, 42);
        vm.prank(alice);
        minter.mint{ value: PRICE * 2 }(
            _params(address(token1155), ID_1155, alice, alice, 2), _noAuth()
        );

        (
            ISeaDropMinter.Stage memory stage,,
            uint256 walletMinted,
            uint256 totalMinted,
            uint256 maxSupply,
            uint256 payoutRecipientCount
        ) = minter.getCheckoutSnapshot(address(token1155), ID_1155, 0, alice);

        assertEq(stage.price, PRICE);
        assertEq(walletMinted, 2);
        assertEq(totalMinted, 2);
        assertEq(maxSupply, MAX_SUPPLY);
        assertEq(payoutRecipientCount, 1);

        // Unset stage on another id returns zeroed stage with that id's supply.
        (stage,, walletMinted, totalMinted, maxSupply,) =
            minter.getCheckoutSnapshot(
                address(token1155), ID_1155 + 1, 99, alice
            );
        assertEq(stage.endTime, 0);
        assertEq(walletMinted, 0);
        assertEq(totalMinted, 0);
        assertEq(maxSupply, 42);
    }

    function test_getCheckoutSnapshot_v1Token() public {
        address[] memory allowed = new address[](1);
        allowed[0] = address(minter);
        ERC721SeaDrop v1 = new ERC721SeaDrop("V1", "V1", allowed);
        v1.setMaxSupply(77);
        _setSinglePayout(address(v1), creator);
        minter.setStage(address(v1), 0, 0, _publicStage());

        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(v1), 0, alice, alice, 1), _noAuth()
        );

        (
            ISeaDropMinter.Stage memory stage,
            ISeaDropMinter.CurrencyConfig memory currencyConfig,
            uint256 walletMinted,
            uint256 totalMinted,
            uint256 maxSupply,
            uint256 payoutRecipientCount
        ) = minter.getCheckoutSnapshot(address(v1), 0, 0, alice);

        assertEq(stage.price, PRICE);
        assertTrue(currencyConfig.allowed);
        assertEq(walletMinted, 1);
        assertEq(totalMinted, 1);
        assertEq(maxSupply, 77);
        assertEq(payoutRecipientCount, 1);
    }

    function test_getCheckoutSnapshot_revert_unsupportedToken() public {
        NotASeaDropToken unsupported = new NotASeaDropToken();
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.UnsupportedToken.selector, address(unsupported)
            )
        );
        minter.getCheckoutSnapshot(address(unsupported), 0, 0, alice);
    }

    function testFuzz_getCheckoutSnapshot(
        uint8 ownerQty,
        uint8 walletQty,
        uint256 stageIndex
    ) public {
        vm.assume(stageIndex != minter.OWNER_MINT_STAGE());
        ownerQty = uint8(bound(ownerQty, 0, 20));
        walletQty = uint8(bound(walletQty, 1, MAX_PER_WALLET));

        ISeaDropMinter.Stage memory s = _publicStage();
        minter.setStage(address(token721), 0, stageIndex, s);

        if (ownerQty > 0) {
            minter.ownerMint(address(token721), 0, bob, ownerQty);
        }
        ISeaDropMinter.MintParams memory p =
            _params(address(token721), 0, alice, alice, walletQty);
        p.stageIndex = stageIndex;
        vm.prank(alice);
        minter.mint{ value: PRICE * walletQty }(p, _noAuth());

        (
            ISeaDropMinter.Stage memory snapStage,
            ISeaDropMinter.CurrencyConfig memory snapCurrency,
            uint256 walletMinted,
            uint256 totalMinted,
            uint256 maxSupply,
            uint256 payoutRecipientCount
        ) = minter.getCheckoutSnapshot(address(token721), 0, stageIndex, alice);

        assertEq(snapStage.price, s.price);
        assertEq(snapStage.endTime, s.endTime);
        assertTrue(snapCurrency.allowed);
        assertEq(walletMinted, walletQty);
        assertEq(totalMinted, uint256(ownerQty) + uint256(walletQty));
        assertEq(maxSupply, MAX_SUPPLY);
        assertEq(payoutRecipientCount, 1);
    }

    // -------------------------------------------------------------------------
    // ERC1155SeaDropV3 id == 0 rejection lockdown
    // -------------------------------------------------------------------------

    function test_ERC1155_rejectsIdZero_allEntryPoints() public {
        // Direct setMaxSupply
        vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
        token1155.setMaxSupply(0, 100);

        // Direct mintSeaDrop from allowed minter
        vm.prank(address(minter));
        vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
        token1155.mintSeaDrop(alice, 0, 1);

        // ownerMint via SeaDropMinter
        vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
        minter.ownerMint(address(token1155), 0, alice, 1);

        // Paid mint via SeaDropMinter even if a stage was configured at id 0
        minter.setStage(address(token1155), 0, 0, _publicStage());
        vm.prank(alice);
        vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
        minter.mint{ value: PRICE }(
            _params(address(token1155), 0, alice, alice, 1), _noAuth()
        );
    }

    function testFuzz_ERC1155_rejectsIdZero(uint128 maxSupply, uint64 quantity)
        public
    {
        quantity = uint64(bound(quantity, 1, type(uint64).max));

        vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
        token1155.setMaxSupply(0, maxSupply);

        vm.prank(address(minter));
        vm.expectRevert(ERC1155SeaDropV3.TokenIdIsZero.selector);
        token1155.mintSeaDrop(alice, 0, quantity);
    }

    // -------------------------------------------------------------------------
    function test_proxyERC20PaysColdRecipients() public {
        IERC20 proxyUsdc = IERC20(
            address(new MinimalERC1967Proxy(address(new MockFiatTokenV2())))
        );
        address coldFee = makeAddr("coldFee");
        address coldCreator = makeAddr("coldCreator");
        minter.setCurrency(
            address(proxyUsdc),
            ISeaDropMinter.CurrencyConfig({
                allowed: true,
                minFeeBps: uint16(FEE_BPS),
                feeRecipient: coldFee
            })
        );
        _setSinglePayout(address(token721), coldCreator);

        uint96 mintPrice = 100e6;
        ISeaDropMinter.Stage memory s = _publicStage();
        s.currency = address(proxyUsdc);
        s.price = mintPrice;
        s.feeRecipient = coldFee;
        minter.setStage(address(token721), 0, 2, s);

        MockFiatTokenV2(address(proxyUsdc)).mint(alice, mintPrice);
        vm.startPrank(alice);
        proxyUsdc.approve(address(minter), mintPrice);
        ISeaDropMinter.MintParams memory p =
            _params(address(token721), 0, alice, alice, 1);
        p.stageIndex = 2;
        p.currency = address(proxyUsdc);
        p.maxTotalPrice = mintPrice;
        minter.mint(p, _noAuth());
        vm.stopPrank();

        assertEq(proxyUsdc.balanceOf(coldFee), 1e6);
        assertEq(proxyUsdc.balanceOf(coldCreator), 99e6);
        assertEq(proxyUsdc.balanceOf(address(minter)), 0);
    }
}
