// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Test} from "forge-std/Test.sol";

import {Withdrawable} from "../../src/withdrawable/Withdrawable.sol";
import {TwoStepOwnable} from "../../src/TwoStepOwnable.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";

contract WithdrawableImpl is Withdrawable {
    receive() external payable {}
}

contract Token20 is ERC20 {
    constructor() ERC20("Token", "TOKEN", 18) {
        _mint(msg.sender, 100 * 10**18);
    }

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }
}

contract Token721 is ERC721 {
    constructor() ERC721("Token", "TOKEN") {
        _mint(msg.sender, 0);
    }

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }
}

contract WithdrawableTest is Test {
    WithdrawableImpl withdraw;
    Token20 erc20;
    Token721 erc721;

    function setUp() public {
        withdraw = new WithdrawableImpl();
        erc20 = new Token20();
        erc721 = new Token721();
    }

    function testCanWithdraw() public {
        payable(address(withdraw)).transfer(1 ether);
        uint256 startingBalance = address(this).balance;
        withdraw.withdraw();
        assertGt(address(this).balance, startingBalance);
        assertEq(0, address(withdraw).balance);
    }

    function testCanWithdrawERC20() public {
        uint256 amount = 50;
        erc20.transfer(address(withdraw), amount);
        assertEq(amount, erc20.balanceOf(address(withdraw)));
        withdraw.withdrawERC20(address(erc20));
        assertEq(0, erc20.balanceOf(address(withdraw)));
    }

    function testCanWithdrawERC721() public {
        erc721.transferFrom(address(this), address(withdraw), 0);
        assertEq(1, erc721.balanceOf(address(withdraw)));
        withdraw.withdrawERC721(address(erc721), 0);
        assertEq(0, erc721.balanceOf(address(withdraw)));
    }

    function testWithdraw_onlyOwner(address _user) public {
        vm.assume(_user != withdraw.owner());
        vm.startPrank(_user);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        withdraw.withdraw();
    }

    function testOnlyOwnerCanWithdrawERC20() public {
        withdraw.transferOwnership(address(1));
        vm.prank(address(1));
        withdraw.acceptOwnership();

        uint256 amount = 50 * 10**18;
        erc20.mint(amount);
        erc20.transfer(address(withdraw), amount);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        withdraw.withdrawERC20(address(erc20));
    }

    function testOnlyOwnerCanWithdrawERC721() public {
        withdraw.transferOwnership(address(1));
        vm.prank(address(1));
        withdraw.acceptOwnership();

        erc721.transferFrom(address(this), address(withdraw), 0);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        withdraw.withdrawERC721(address(erc721), 0);
    }

    receive() external payable {}
}
