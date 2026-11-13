// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC721A } from "ERC721A/ERC721A.sol";

import { ERC721 } from "solmate/tokens/ERC721.sol";

import { IERC721 } from "openzeppelin-contracts/token/ERC721/IERC721.sol";

import { ISeaDropTokenV3 } from "seadrop/v3/interfaces/ISeaDropTokenV3.sol";

/**
 * @dev A stand-in for an ERC-721 deployed without SeaDrop support. Its
 *      owner can mint to any address and grant other addresses the right
 *      to mint.
 */
contract TestExistingERC721 is ERC721A {
    error NotMinter();

    address public immutable owner;

    mapping(address minter => bool allowed) public isMinter;

    constructor() ERC721A("Existing", "EXIST") {
        owner = msg.sender;
    }

    function setMinter(address minter, bool allowed) external {
        if (msg.sender != owner) revert NotMinter();
        // forge-lint: disable-next-line(missing-events-access-control)
        isMinter[minter] = allowed;
    }

    /// @dev Mint `quantity` tokens. Owner or minters only.
    function mintTo(address to, uint256 quantity) external {
        if (msg.sender != owner && !isMinter[msg.sender]) revert NotMinter();
        _safeMint(to, quantity);
    }

    /// @dev Mint one token whatever the second argument, like
    ///      OpenZeppelin's `safeMint(address,uint256)` with a token id.
    function mintTokenId(address to, uint256) external {
        if (msg.sender != owner && !isMinter[msg.sender]) revert NotMinter();
        _safeMint(to, 1);
    }

    /// @dev Mint without the receiver callback.
    function mintUnsafe(address to, uint256 quantity) external {
        if (msg.sender != owner) revert NotMinter();
        _mint(to, quantity);
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }
}

/// @dev An existing ERC-721 without `totalSupply()`. Anyone can mint.
contract TestMinimalERC721 is ERC721("Minimal", "MIN") {
    uint256 internal _nextId = 1;

    function mintTo(address to, uint256 quantity) external {
        for (uint256 i; i < quantity; ++i) {
            _safeMint(to, _nextId++);
        }
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }
}

/// @dev An existing ERC-721 whose fallback accepts any call, like a proxy
///      without EIP-2981.
contract TestFallbackERC721 is TestMinimalERC721 {
    fallback() external { }
}

/// @dev An existing ERC-721 with a 5% EIP-2981 royalty.
contract TestRoyaltyERC721 is TestMinimalERC721 {
    address public immutable royaltyReceiver;

    constructor(address receiver) {
        royaltyReceiver = receiver;
    }

    function royaltyInfo(uint256, uint256 salePrice)
        external
        view
        returns (address, uint256)
    {
        return (royaltyReceiver, salePrice * 500 / 10_000);
    }
}

/// @dev A wallet that forwards each ERC-721 it receives to a vault, as some
///      smart wallets and staking contracts do.
contract TestForwardingReceiver {
    address public immutable vault;

    constructor(address vault_) {
        vault = vault_;
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata)
        external
        returns (bytes4)
    {
        IERC721(msg.sender).transferFrom(address(this), vault, tokenId);
        return this.onERC721Received.selector;
    }
}

/// @dev An allowed minter that, when it receives a token, calls the
///      adapter's `mintSeaDrop` again.
contract TestReentrantAdapterMinter {
    ISeaDropTokenV3 public adapter;

    function mint(ISeaDropTokenV3 adapter_, uint256 quantity) external {
        adapter = adapter_;
        adapter_.mintSeaDrop(address(this), 0, quantity);
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        returns (bytes4)
    {
        adapter.mintSeaDrop(address(this), 0, 1);
        return this.onERC721Received.selector;
    }
}

interface IOwnerMint {
    function ownerMint(
        address token,
        uint256 id,
        address recipient,
        uint256 quantity
    ) external;
}

/// @dev An adapter owner that buys from its own drop and, while the token
///      is being delivered, sends it straight back to the adapter.
contract TestRedepositingOwner {
    address public adapter;
    bool internal _armed;

    function setAdapter(address adapter_) external {
        adapter = adapter_;
    }

    function deposit(IERC721 target, uint256 tokenId) external {
        target.safeTransferFrom(address(this), adapter, tokenId);
    }

    function ownerMintAndRedeposit(IOwnerMint minter) external {
        _armed = true;
        minter.ownerMint(adapter, 0, address(this), 1);
        _armed = false;
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata)
        external
        returns (bytes4)
    {
        if (_armed) {
            IERC721(msg.sender)
                .safeTransferFrom(address(this), adapter, tokenId);
        }
        return this.onERC721Received.selector;
    }
}
