// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Test} from "forge-std/Test.sol";
import {CommissionWithdrawable} from "../../src/withdrawable/CommissionWithdrawable.sol";
import {TwoStepOwnable} from "../../src/TwoStepOwnable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract CommissionWithdrawableImpl is CommissionWithdrawable {
    constructor(address _payout, uint256 _bps)
        CommissionWithdrawable(_payout, _bps)
    {}

    function getCommissionBps() public view returns (uint256) {
        return commissionBps;
    }

    function getCommissionPayoutAddress() public view returns (address) {
        return commissionPayoutAddress;
    }

    receive() external payable {}
}

contract Token is ERC20 {
    constructor() ERC20("Token", "TOKEN", 18) {
        _mint(msg.sender, 1000 * 10**18);
    }

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }
}

contract CommissionWithdrawableTest is Test {
    CommissionWithdrawableImpl withdraw;
    Token token;
    address payable user = payable(address(42));

    function setUp() public {
        withdraw = new CommissionWithdrawableImpl(address(user), 50);
        token = new Token();
    }

    function testConstructorSetsParams() public {
        withdraw = new CommissionWithdrawableImpl(address(1234), 123);
        assertEq(withdraw.getCommissionBps(), 123);
        assertEq(withdraw.getCommissionPayoutAddress(), address(1234));
    }

    function testConstructorEnforcesLimit() public {
        // fine
        withdraw = new CommissionWithdrawableImpl(address(user), 10000);
        // bad
        vm.expectRevert(abi.encodeWithSignature("CommissionBpsTooLarge()"));
        withdraw = new CommissionWithdrawableImpl(address(user), 10001);
        // bad
        vm.expectRevert(
            abi.encodeWithSignature("CommissionPayoutAddressIsZeroAddress()")
        );
        withdraw = new CommissionWithdrawableImpl(address(0), 10000);
    }

    function testWithdrawSendsCommission() public {
        payable(address(withdraw)).transfer(1 ether);
        uint256 startingBalance = address(this).balance;
        withdraw.withdraw();
        assertGt(address(this).balance, startingBalance);
        assertEq(0, address(withdraw).balance);
        assertEq(0.005 ether, address(user).balance);
    }

    function testCanWithdrawERC20() public {
        uint256 initialBalance = token.balanceOf(address(this));
        uint256 amount = 1000;
        token.transfer(address(withdraw), amount);
        assertEq(amount, token.balanceOf(address(withdraw)));
        withdraw.withdrawERC20(address(token));
        assertEq(0, token.balanceOf(address(withdraw)));
        assertEq(
            (initialBalance - 1000) + uint256(1000 * 9950) / uint256(10000),
            token.balanceOf(address(this))
        );
        assertEq((1000 * 50) / 10000, token.balanceOf(address(user)));
    }

    function testWithdraw_onlyOwner(address _user) public {
        vm.assume(_user != withdraw.owner());
        vm.startPrank(_user);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);

        withdraw.withdraw();
    }

    function testOnlyOwnerCanWithdrawERC20() public {
        withdraw.transferOwnership(address(user));
        vm.prank(address(user));
        withdraw.acceptOwnership();

        uint256 amount = 50 * 10**18;
        token.mint(amount);
        token.transfer(address(withdraw), amount);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);

        withdraw.withdrawERC20(address(token));
    }

    function testBigWithdraw() public {
        uint256 balance = token.balanceOf(address(this));
        uint256 bigBalance = 2**247;
        token.mint(bigBalance - balance);
        token.transfer(address(withdraw), token.balanceOf(address(this)));
        withdraw.withdrawERC20(address(token));
        uint256 userBalance = (bigBalance / 10000) * 50;
        assertEq(userBalance, token.balanceOf(address(user)));
        assertEq(bigBalance - userBalance, token.balanceOf(address(this)));
    }

    function testFuzzyWithdraw(uint256 bps, uint256 balance)
        public
        inRange(bps, balance)
    {
        withdraw = new CommissionWithdrawableImpl(address(user), bps);
        payable(address(withdraw)).transfer(balance);
        uint256 preWithdrawBalance = address(this).balance;
        withdraw.withdraw();
        uint256 withdrawnBalance = (address(this).balance -
            preWithdrawBalance) + address(user).balance;
        assertEq(balance, withdrawnBalance);
        assertEq(address(user).balance, (balance * bps) / 10000);
    }

    modifier inRange(uint256 bps, uint256 balance) {
        if (bps > 10000) {
            return;
        }
        if (balance > address(this).balance) {
            return;
        }
        _;
    }

    receive() external payable {}
}
