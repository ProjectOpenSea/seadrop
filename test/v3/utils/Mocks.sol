// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { ECDSA } from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import { SeaDropMinter } from "seadrop/v3/SeaDropMinter.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

/**
 * @dev delegate.xyz v2's delegation calls, reduced to what the minter reads.
 *      Tests etch it at the canonical registry address.
 */
contract MockDelegateRegistry {
    mapping(
        address to
            => mapping(address from => mapping(address contract_ => bool))
    ) internal _delegations;

    function delegateAll(address to, bytes32, bool enable)
        external
        returns (bytes32)
    {
        _delegations[to][msg.sender][address(0)] = enable;
        return bytes32(0);
    }

    function delegateContract(
        address to,
        address contract_,
        bytes32,
        bool enable
    ) external returns (bytes32) {
        _delegations[to][msg.sender][contract_] = enable;
        return bytes32(0);
    }

    function checkDelegateForContract(
        address to,
        address from,
        address contract_,
        bytes32
    ) external view returns (bool) {
        return _delegations[to][from][address(0)]
            || _delegations[to][from][contract_];
    }
}

/**
 * @dev A smart account: ERC-1271 signatures from its owner key, token
 *      receipt, and arbitrary calls from its owner.
 */
contract MockERC1271Wallet {
    address public immutable signerKey;

    constructor(address signerKey_) {
        signerKey = signerKey_;
    }

    function isValidSignature(bytes32 hash, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        (address recovered, ECDSA.RecoverError err) =
            ECDSA.tryRecover(hash, signature);
        if (err == ECDSA.RecoverError.NoError && recovered == signerKey) {
            return this.isValidSignature.selector;
        }
        return 0xffffffff;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}

/// @dev A payout recipient that rejects ETH but can withdraw elsewhere.
contract RevertingRecipient {
    receive() external payable {
        revert("no ETH");
    }

    function withdrawFrom(SeaDropMinter minter, address currency, address to)
        external
    {
        minter.withdraw(currency, to);
    }
}

/// @dev A payout recipient that burns all the gas it gets.
contract GasBurningRecipient {
    uint256 public counter;

    receive() external payable {
        while (true) {
            ++counter;
        }
    }
}

/**
 * @dev A token owner that, when it's paid or receives a token, replaces
 *      the token's payout list with `newRecipient` alone.
 */
contract PayoutListChanger {
    SeaDropMinter internal immutable _minter;
    address internal _token;
    address internal _newRecipient;

    constructor(SeaDropMinter minter) {
        _minter = minter;
    }

    function arm(address token, address newRecipient) external {
        _token = token;
        _newRecipient = newRecipient;
    }

    function acceptOwnershipOf(TwoStepOwnable token) external {
        token.acceptOwnership();
    }

    /// @dev Mint to itself, paying `msg.value`.
    function mintToSelf(ISeaDropMinter.MintParams calldata params)
        external
        payable
    {
        ISeaDropMinter.Authorization memory none;
        _minter.mint{ value: msg.value }(params, none);
    }

    receive() external payable {
        _changeList();
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        returns (bytes4)
    {
        _changeList();
        return this.onERC721Received.selector;
    }

    function _changeList() internal {
        address token = _token;
        if (token == address(0)) return;
        _token = address(0);
        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](1);
        recipients[0] = ISeaDropMinter.PayoutRecipient(_newRecipient, 10_000);
        _minter.setPayoutRecipients(token, recipients);
    }
}

/// @dev Re-enters the minter from its ERC-721 receipt hook.
contract ReentrantReceiver {
    SeaDropMinter internal immutable _minter;
    ISeaDropMinter.MintParams internal _params;

    constructor(SeaDropMinter minter) {
        _minter = minter;
    }

    function setParams(ISeaDropMinter.MintParams memory params) external {
        _params = params;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        returns (bytes4)
    {
        ISeaDropMinter.Authorization memory none;
        _minter.mint(_params, none);
        return this.onERC721Received.selector;
    }
}

/// @dev A contract with an owner but no SeaDrop token interface.
contract NotASeaDropToken {
    address public owner = msg.sender;
}

/**
 * @dev An ERC-20 that can block recipients, as USDC's blocklist does, and
 *      charge a transfer fee. A recipient's transfer mode makes `transfer`
 *      move the tokens and then answer badly: with one byte of return
 *      data, with the boolean word 2, or by burning all its gas.
 */
contract TestERC20 is ERC20("Test", "TST", 6) {
    uint8 public constant SHORT_RETURN = 1;
    uint8 public constant RETURNS_TWO = 2;
    uint8 public constant BURNS_GAS = 3;
    uint8 public constant SHORT_PAYOUT = 4;
    uint8 public constant EXTRA_DEBIT = 5;

    mapping(address account => bool) public blocked;
    mapping(address account => uint8 mode) public transferMode;
    uint256 public transferFeeBps;

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setBlocked(address account, bool isBlocked) external {
        blocked[account] = isBlocked;
    }

    function setTransferFeeBps(uint256 feeBps) external {
        transferFeeBps = feeBps;
    }

    function setTransferMode(address account, uint8 mode) external {
        transferMode[account] = mode;
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        require(!blocked[to], "blocked");
        bool moved = super.transfer(to, amount);
        uint8 mode = transferMode[to];
        if (mode == SHORT_PAYOUT) _burn(to, 1);
        if (mode == EXTRA_DEBIT) _burn(msg.sender, 1);
        if (mode == SHORT_RETURN) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(31, 1)
            }
        }
        if (mode == RETURNS_TWO) {
            assembly ("memory-safe") {
                mstore(0, 2)
                return(0, 32)
            }
        }
        if (mode == BURNS_GAS) {
            uint256 spins;
            while (true) {
                ++spins;
            }
        }
        return moved;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        returns (bool)
    {
        require(!blocked[to], "blocked");
        uint256 fee = amount * transferFeeBps / 10_000;
        if (fee != 0) _burn(from, fee);
        return super.transferFrom(from, to, amount - fee);
    }
}
