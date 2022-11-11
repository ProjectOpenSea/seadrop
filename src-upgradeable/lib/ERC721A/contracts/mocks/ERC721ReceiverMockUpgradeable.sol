// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creators: Chiru Labs

pragma solidity ^0.8.4;

import '../ERC721AUpgradeable.sol';
import {ERC721ReceiverMockStorage} from './ERC721ReceiverMockStorage.sol';
import '../ERC721A__Initializable.sol';

interface IERC721AMockUpgradeable {
    function safeMint(address to, uint256 quantity) external;
}

contract ERC721ReceiverMockUpgradeable is ERC721A__Initializable, ERC721A__IERC721ReceiverUpgradeable {
    using ERC721ReceiverMockStorage for ERC721ReceiverMockStorage.Layout;
    enum Error {
        None,
        RevertWithMessage,
        RevertWithoutMessage,
        Panic
    }

    event Received(address operator, address from, uint256 tokenId, bytes data, uint256 gas);

    function __ERC721ReceiverMock_init(bytes4 retval, address erc721aMock) internal onlyInitializingERC721A {
        __ERC721ReceiverMock_init_unchained(retval, erc721aMock);
    }

    function __ERC721ReceiverMock_init_unchained(bytes4 retval, address erc721aMock) internal onlyInitializingERC721A {
        ERC721ReceiverMockStorage.layout()._retval = retval;
        ERC721ReceiverMockStorage.layout()._erc721aMock = erc721aMock;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public override returns (bytes4) {
        uint256 dataValue = data.length == 0 ? 0 : uint256(uint8(data[0]));

        // For testing reverts with a message from the receiver contract.
        if (dataValue == 0x01) {
            revert('reverted in the receiver contract!');
        }

        // For testing with the returned wrong value from the receiver contract.
        if (dataValue == 0x02) {
            return 0x0;
        }

        // For testing the reentrancy protection.
        if (dataValue == 0x03) {
            IERC721AMockUpgradeable(ERC721ReceiverMockStorage.layout()._erc721aMock).safeMint(address(this), 1);
        }

        emit Received(operator, from, tokenId, data, 20000);
        return ERC721ReceiverMockStorage.layout()._retval;
    }
}
