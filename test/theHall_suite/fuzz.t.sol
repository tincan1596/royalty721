// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseTheHallTest} from "./base.t.sol";
import {TheHall} from "../../src/theHall/theHall.sol";
import "forge-std/console.sol";

contract hallFuzzTest is BaseTheHallTest {
    function testFuzz_createListing_InvalidPrice(uint256 price) public {
        price = boundPrice(price);
        approveMarketplaceAsSeller(TOKEN_ID);
        vm.expectRevert(TheHall.ZeroPrice.selector);
        hall.createListing(TOKEN_ID, 0);
    }

    function testFuzz_createListing_NotOwner(uint256 price) public {
        price = boundPrice(price);
        vm.prank(buyer);
        vm.expectRevert(TheHall.NotOwner.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_createListing_AlreadyListed(uint256 price) public {
        price = boundPrice(price);
        approveMarketplaceAsSeller(TOKEN_ID);
        hall.createListing(TOKEN_ID, price);
        vm.expectRevert(TheHall.AlreadyListed.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_createListing_NotApproved(uint256 price) public {
        price = boundPrice(price);
        vm.prank(seller);
        vm.expectRevert(TheHall.NotApproved.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_cancelListing_NotSeller(uint256 price) public {
        price = boundPrice(price);
        createAndListToken(TOKEN_ID, price);
        vm.prank(buyer);
        vm.expectRevert(TheHall.NotSeller.selector);
        hall.cancelListing(TOKEN_ID);
    }

    function testFuzz_buyToken_NotListed(uint256 expectedPrice) public {
        expectedPrice = boundPrice(expectedPrice);
        vm.prank(buyer);
        vm.expectRevert(TheHall.NotListed.selector);
        hall.buyToken(TOKEN_ID, expectedPrice);
    }

    function testFuzz_buyToken_NotTokenOwner(uint256 price, uint256 expectedPrice) public {
        price = boundPrice(price);
        expectedPrice = boundPrice(expectedPrice);

        createAndListToken(TOKEN_ID, price);
        mintToken(owner, TOKEN_ID + 1);

        vm.prank(buyer);
        vm.expectRevert(TheHall.NotTokenOwner.selector);
        hall.buyToken(TOKEN_ID + 1, expectedPrice);
    }

    function testFuzz_buyToken_InvalidPrice(uint256 price, uint256 expectedPrice) public {
        price = boundPrice(price);
        expectedPrice = boundPrice(expectedPrice);
        vm.assume(expectedPrice != price);

        createAndListToken(TOKEN_ID, price);

        vm.startPrank(buyer);
        usdc.approve(address(hall), expectedPrice);
        vm.expectRevert(TheHall.InvalidPrice.selector);
        hall.buyToken(TOKEN_ID, expectedPrice);
        vm.stopPrank();
    }

    function testFuzz_withdrawStuckTokens_InvalidWithdrawal(address to, uint256 amount) public {
        amount = bound(amount, 1, 1e18);
        vm.assume(to == address(0) || amount == 0);
        vm.expectRevert(TheHall.InvalidWithdrawal.selector);
        hall.withdrawStuckTokens(address(usdc), amount, to);
    }

    function testFuzz_withdrawStuckTokens_AmountExceedsBalance(address to, uint256 amount) public {
        amount = bound(amount, usdc.balanceOf(address(hall)), type(uint128).max);
        vm.assume(to != address(0) && amount > 0);
        vm.expectRevert(TheHall.InvalidWithdrawal.selector);
        hall.withdrawStuckTokens(address(usdc), amount, to);
    }
}
