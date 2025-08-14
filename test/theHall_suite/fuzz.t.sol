// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseTheHallTest} from "./base.t.sol";
import {TheHall} from "../../src/theHall/theHall.sol";

contract hallFuzzTest is BaseTheHallTest {
    uint256 internal constant TOKEN_ID = 0;
    uint256 internal constant MIN_PRICE = 1e6;
    uint256 internal constant MAX_PRICE = 10e6;

    function testFuzz_createListing_InvalidPrice(uint256 price) public {
        price = bound(price, MIN_PRICE, MAX_PRICE);
        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        vm.expectRevert(TheHall.ZeroPrice.selector);
        hall.createListing(TOKEN_ID, 0); // force zero price to trigger revert
    }

    function testFuzz_createListing_NotOwner(uint256 price) public {
        price = bound(price, MIN_PRICE, MAX_PRICE);
        vm.prank(buyer);
        vm.expectRevert(TheHall.NotOwner.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_createListing_AlreadyListed(uint256 price) public {
        price = bound(price, MIN_PRICE, MAX_PRICE);
        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        hall.createListing(TOKEN_ID, price);
        vm.expectRevert(TheHall.AlreadyListed.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_createListing_NotApproved(uint256 price) public {
        price = bound(price, MIN_PRICE, MAX_PRICE);
        vm.prank(seller);
        vm.expectRevert(TheHall.NotApproved.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_cancelListing_NotSeller(uint256 price) public {
        price = bound(price, MIN_PRICE, MAX_PRICE);
        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        hall.createListing(TOKEN_ID, price);
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert(TheHall.NotSeller.selector);
        hall.cancelListing(TOKEN_ID);
    }

    function testFuzz_buyToken_NotListed(uint256 expectedPrice) public {
        expectedPrice = bound(expectedPrice, MIN_PRICE, MAX_PRICE);
        vm.prank(buyer);
        vm.expectRevert(TheHall.NotListed.selector);
        hall.buyToken(TOKEN_ID, expectedPrice);
    }

    function testFuzz_buyToken_NotTokenOwner(uint256 price, uint256 expectedPrice) public {
        price = bound(price, MIN_PRICE, MAX_PRICE);
        expectedPrice = bound(expectedPrice, MIN_PRICE, MAX_PRICE);

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
        price = bound(price, MIN_PRICE, MAX_PRICE);
        expectedPrice = bound(expectedPrice, MIN_PRICE, MAX_PRICE);
        vm.assume(expectedPrice != price);

        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        hall.createListing(TOKEN_ID, price);
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert(TheHall.InvalidPrice.selector);
        hall.buyToken(TOKEN_ID, expectedPrice);
    }

    function testFuzz_buyToken_InvalidRoyalty(uint256 price) public {
        price = bound(price, MIN_PRICE, MAX_PRICE);

        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        hall.createListing(TOKEN_ID, price);
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert(TheHall.InvalidRoyalty.selector);
        hall.buyToken(TOKEN_ID, price);
    }

    function testFuzz_withdrawStuckTokens_InvalidWithdrawal(address to, uint256 amount) public {
        amount = bound(amount, 1, 1e18); // arbitrary positive bound
        vm.assume(to == address(0) || amount == 0);
        vm.expectRevert(TheHall.InvalidWithdrawal.selector);
        hall.withdrawStuckTokens(address(usdc), amount, to);
    }

    function testFuzz_withdrawStuckTokens_AmountExceedsBalance(address to, uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max); // keep it large for test
        vm.assume(to != address(0) && amount > usdc.balanceOf(address(hall)));
        vm.expectRevert(TheHall.InvalidWithdrawal.selector);
        hall.withdrawStuckTokens(address(usdc), amount, to);
    }
}
