// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;
import { ERC721Storage } from "./ERC721Storage.sol";
import "../../../../src/Initializable.sol";

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721Upgradeable is Initializable {
    using ERC721Storage for ERC721Storage.Layout;
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC

    function tokenURI(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        require((owner = ERC721Storage.layout()._ownerOf[id]) != address(0), "NOT_MINTED");
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");

        return ERC721Storage.layout()._balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function __ERC721_init(string memory _name, string memory _symbol) internal onlyInitializing {
        __ERC721_init_unchained(_name, _symbol);
    }

    function __ERC721_init_unchained(string memory _name, string memory _symbol) internal onlyInitializing {
        ERC721Storage.layout().name = _name;
        ERC721Storage.layout().symbol = _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public virtual {
        address owner = ERC721Storage.layout()._ownerOf[id];

        require(msg.sender == owner || ERC721Storage.layout().isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        ERC721Storage.layout().getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        ERC721Storage.layout().isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        require(from == ERC721Storage.layout()._ownerOf[id], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || ERC721Storage.layout().isApprovedForAll[from][msg.sender] || msg.sender == ERC721Storage.layout().getApproved[id],
            "NOT_AUTHORIZED"
        );

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            ERC721Storage.layout()._balanceOf[from]--;

            ERC721Storage.layout()._balanceOf[to]++;
        }

        ERC721Storage.layout()._ownerOf[id] = to;

        delete ERC721Storage.layout().getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiverUpgradeable(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiverUpgradeable.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiverUpgradeable(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiverUpgradeable.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        require(to != address(0), "INVALID_RECIPIENT");

        require(ERC721Storage.layout()._ownerOf[id] == address(0), "ALREADY_MINTED");

        // Counter overflow is incredibly unrealistic.
        unchecked {
            ERC721Storage.layout()._balanceOf[to]++;
        }

        ERC721Storage.layout()._ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = ERC721Storage.layout()._ownerOf[id];

        require(owner != address(0), "NOT_MINTED");

        // Ownership check above ensures no underflow.
        unchecked {
            ERC721Storage.layout()._balanceOf[owner]--;
        }

        delete ERC721Storage.layout()._ownerOf[id];

        delete ERC721Storage.layout().getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiverUpgradeable(to).onERC721Received(msg.sender, address(0), id, "") ==
                ERC721TokenReceiverUpgradeable.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiverUpgradeable(to).onERC721Received(msg.sender, address(0), id, data) ==
                ERC721TokenReceiverUpgradeable.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
    // generated getter for ${varDecl.name}
    function name() public view returns(string memory) {
        return ERC721Storage.layout().name;
    }

    // generated getter for ${varDecl.name}
    function symbol() public view returns(string memory) {
        return ERC721Storage.layout().symbol;
    }

    // generated getter for ${varDecl.name}
    function getApproved(uint256 arg0) public view returns(address) {
        return ERC721Storage.layout().getApproved[arg0];
    }

    // generated getter for ${varDecl.name}
    function isApprovedForAll(address arg0,address arg1) public view returns(bool) {
        return ERC721Storage.layout().isApprovedForAll[arg0][arg1];
    }

}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiverUpgradeable is Initializable {
    function __ERC721TokenReceiver_init() internal onlyInitializing {
        __ERC721TokenReceiver_init_unchained();
    }

    function __ERC721TokenReceiver_init_unchained() internal onlyInitializing {
    }
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiverUpgradeable.onERC721Received.selector;
    }
}
