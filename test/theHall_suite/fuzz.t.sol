// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseTheHallTest} from "./base.t.sol";
import {TheHall} from "../../src/theHall/theHall.sol";

contract hallFuzzTest is BaseTheHallTest {
    uint256 internal constant TOKEN_ID = 0;

    function testFuzz_createListing_InvalidPrice(uint256 price) public {
        vm.assume(price == 0);
        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        vm.expectRevert(TheHall.ZeroPrice.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_createListing_NotOwner(uint256 price) public {
        vm.assume(price > 0);
        vm.prank(buyer);
        vm.expectRevert(TheHall.NotOwner.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_createListing_AlreadyListed(uint256 price) public {
        vm.assume(price > 0);
        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        hall.createListing(TOKEN_ID, price);
        vm.expectRevert(TheHall.AlreadyListed.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_createListing_NotApproved(uint256 price) public {
        vm.assume(price > 0);
        vm.prank(seller);
        vm.expectRevert(TheHall.NotApproved.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_cancelListing_NotSeller(uint256 price) public {
        vm.assume(price > 0);
        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        hall.createListing(TOKEN_ID, price);
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert(TheHall.NotSeller.selector);
        hall.cancelListing(TOKEN_ID);
    }

    function testFuzz_buyToken_NotListed(uint256 expectedPrice) public {
        vm.prank(buyer);
        vm.expectRevert(TheHall.NotListed.selector);
        hall.buyToken(TOKEN_ID, expectedPrice);
    }

    function testFuzz_buyToken_NotTokenOwner(uint256 price, uint256 expectedPrice) public {
        vm.assume(price > 0 && expectedPrice > 0);
        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        hall.createListing(TOKEN_ID, price);
        vm.stopPrank();

        vm.startPrank(owner);
        stoken.mint(owner, TOKEN_ID + 1);
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert(TheHall.NotTokenOwner.selector);
        hall.buyToken(TOKEN_ID + 1, expectedPrice);
    }

    function testFuzz_buyToken_InvalidPrice(uint256 price, uint256 expectedPrice) public {
        vm.assume(price > 0 && expectedPrice != price);
        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        hall.createListing(TOKEN_ID, price);
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert(TheHall.InvalidPrice.selector);
        hall.buyToken(TOKEN_ID, expectedPrice);
    }

    function testFuzz_buyToken_InvalidRoyalty(uint256 price) public {
        vm.assume(price > 0);
        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        hall.createListing(TOKEN_ID, price);
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert(TheHall.InvalidRoyalty.selector);
        hall.buyToken(TOKEN_ID, price);
    }

    function testFuzz_withdrawStuckTokens_InvalidWithdrawal(address to, uint256 amount) public {
        vm.assume(to == address(0) || amount == 0);
        vm.expectRevert(TheHall.InvalidWithdrawal.selector);
        hall.withdrawStuckTokens(address(usdc), amount, to);
    }

    function testFuzz_withdrawStuckTokens_AmountExceedsBalance(address to, uint256 amount) public {
        vm.assume(to != address(0) && amount > 0);
        vm.assume(amount > usdc.balanceOf(address(hall)));
        vm.expectRevert(TheHall.InvalidWithdrawal.selector);
        hall.withdrawStuckTokens(address(usdc), amount, to);
    }
}
