// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {mUSDC} from "../../src/mUSDC/mUSDC.sol";

contract mUSDCTest is Test {
    mUSDC public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this); // test contract is the owner
        user1 = address(0xBEEF);
        user2 = address(0xCAFE);

        token = new mUSDC(owner);
    }

    // --- Metadata ---

    function test_Metadata() public view {
        assertEq(token.name(), "Mock USDC");
        assertEq(token.symbol(), "mUSDC");
        assertEq(token.decimals(), 6);
    }

    // --- Minting ---

    function test_MintIncreasesBalanceAndSupply() public {
        uint256 amt = 1000e6;
        token.mint(user1, amt);

        assertEq(token.balanceOf(user1), amt);
        assertEq(token.totalSupply(), amt);
    }

    function test_NonOwnerCannotMint() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        token.mint(user2, 1000e6);
        vm.stopPrank();
    }

    // --- Transfers ---

    function test_TransferSuccess() public {
        uint256 amt = 500e6;
        token.mint(owner, amt);

        token.transfer(user1, amt);

        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(user1), amt);
    }

    function test_TransferInsufficientBalanceReverts() public {
        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, 1); // user1 has 0
    }

    // --- transferFrom ---

    function test_TransferFromWithApproval() public {
        token.mint(user1, 1000e6);

        vm.prank(user1);
        token.approve(owner, 600e6);

        vm.prank(owner);
        token.transferFrom(user1, user2, 600e6);

        assertEq(token.balanceOf(user1), 400e6);
        assertEq(token.balanceOf(user2), 600e6);
        assertEq(token.allowance(user1, owner), 0);
    }

    function test_TransferFromWithoutApprovalReverts() public {
        token.mint(user1, 1000e6);
        vm.expectRevert();
        token.transferFrom(user1, user2, 1); // no allowance set
    }

    function test_TransferFromInsufficientBalanceReverts() public {
        vm.prank(user1);
        token.approve(owner, 100e6);

        vm.expectRevert();
        token.transferFrom(user1, user2, 100e6); // user1 has 0
    }
}
