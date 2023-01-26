// SPDX-License-Identifier: MIT
pragma solidity >=0.7 <0.9;
pragma experimental ABIEncoderV2;

import '../ERC721AUpgradeable.sol';

contract ERC721AUpgradeableWithInit is ERC721AUpgradeable {
    constructor(string memory name_, string memory symbol_) payable initializerERC721A {
        __ERC721A_init(name_, symbol_);
    }
}
import './ERC721ReceiverMockUpgradeable.sol';

contract ERC721ReceiverMockUpgradeableWithInit is ERC721ReceiverMockUpgradeable {
    constructor(bytes4 retval, address erc721aMock) payable initializerERC721A {
        __ERC721ReceiverMock_init(retval, erc721aMock);
    }
}
import './ERC721AWithERC2309MockUpgradeable.sol';

contract ERC721AWithERC2309MockUpgradeableWithInit is ERC721AWithERC2309MockUpgradeable {
    constructor(
        string memory name_,
        string memory symbol_,
        address to,
        uint256 quantity,
        bool mintInConstructor
    ) payable initializerERC721A {
        __ERC721AWithERC2309Mock_init(name_, symbol_, to, quantity, mintInConstructor);
    }
}
import './ERC721AMockUpgradeable.sol';

contract ERC721AMockUpgradeableWithInit is ERC721AMockUpgradeable {
    constructor(string memory name_, string memory symbol_) payable initializerERC721A {
        __ERC721AMock_init(name_, symbol_);
    }
}
import './ERC721ATransferCounterMockUpgradeable.sol';

contract ERC721ATransferCounterMockUpgradeableWithInit is ERC721ATransferCounterMockUpgradeable {
    constructor(string memory name_, string memory symbol_) payable initializerERC721A {
        __ERC721ATransferCounterMock_init(name_, symbol_);
    }
}
import './ERC721AStartTokenIdMockUpgradeable.sol';

contract ERC721AStartTokenIdMockUpgradeableWithInit is ERC721AStartTokenIdMockUpgradeable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 startTokenId_
    ) payable initializerERC721A {
        __ERC721AStartTokenIdMock_init(name_, symbol_, startTokenId_);
    }
}
import './StartTokenIdHelperUpgradeable.sol';

contract StartTokenIdHelperUpgradeableWithInit is StartTokenIdHelperUpgradeable {
    constructor(uint256 startTokenId_) payable initializerERC721A {
        __StartTokenIdHelper_init(startTokenId_);
    }
}
import './ERC721AQueryableStartTokenIdMockUpgradeable.sol';

contract ERC721AQueryableStartTokenIdMockUpgradeableWithInit is ERC721AQueryableStartTokenIdMockUpgradeable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 startTokenId_
    ) payable initializerERC721A {
        __ERC721AQueryableStartTokenIdMock_init(name_, symbol_, startTokenId_);
    }
}
import './ERC721AQueryableMockUpgradeable.sol';

contract ERC721AQueryableMockUpgradeableWithInit is ERC721AQueryableMockUpgradeable {
    constructor(string memory name_, string memory symbol_) payable initializerERC721A {
        __ERC721AQueryableMock_init(name_, symbol_);
    }
}
import './ERC721ABurnableMockUpgradeable.sol';

contract ERC721ABurnableMockUpgradeableWithInit is ERC721ABurnableMockUpgradeable {
    constructor(string memory name_, string memory symbol_) payable initializerERC721A {
        __ERC721ABurnableMock_init(name_, symbol_);
    }
}
import './ERC721ABurnableStartTokenIdMockUpgradeable.sol';

contract ERC721ABurnableStartTokenIdMockUpgradeableWithInit is ERC721ABurnableStartTokenIdMockUpgradeable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 startTokenId_
    ) payable initializerERC721A {
        __ERC721ABurnableStartTokenIdMock_init(name_, symbol_, startTokenId_);
    }
}
import './ERC4907AMockUpgradeable.sol';

contract ERC4907AMockUpgradeableWithInit is ERC4907AMockUpgradeable {
    constructor(string memory name_, string memory symbol_) payable initializerERC721A {
        __ERC4907AMock_init(name_, symbol_);
    }
}
import './ERC721AGasReporterMockUpgradeable.sol';

contract ERC721AGasReporterMockUpgradeableWithInit is ERC721AGasReporterMockUpgradeable {
    constructor(string memory name_, string memory symbol_) payable initializerERC721A {
        __ERC721AGasReporterMock_init(name_, symbol_);
    }
}
