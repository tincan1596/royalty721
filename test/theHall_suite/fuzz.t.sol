// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseTheHallTest} from "./base.t.sol";
import "forge-std/console.sol";

contract hallFuzzTest is BaseTheHallTest {
    function testFuzz_createListing_NotOwner(uint256 price) public {
        price = boundPrice(price);
        vm.prank(buyer);
        vm.expectRevert(NotTokenOwner.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_createListing_AlreadyListed(uint256 price) public {
        price = boundPrice(price);
        approveMarketplaceAsSeller(TOKEN_ID);
        vm.startPrank(seller);
        hall.createListing(TOKEN_ID, price);
        vm.expectRevert(AlreadyListed.selector);
        hall.createListing(TOKEN_ID, price);
        vm.stopPrank();
    }

    function testFuzz_createListing_NotApproved(uint256 price) public {
        price = boundPrice(price);
        vm.prank(seller);
        vm.expectRevert(NotApproved.selector);
        hall.createListing(TOKEN_ID, price);
    }

    function testFuzz_cancelListing_NotSeller(uint256 price) public {
        price = boundPrice(price);
        createAndListToken(TOKEN_ID, price);
        vm.prank(buyer);
        vm.expectRevert(NotSeller.selector);
        hall.cancelListing(TOKEN_ID);
    }

    function testFuzz_buyToken_NotListed(uint256 expectedPrice) public {
        expectedPrice = boundPrice(expectedPrice);
        vm.prank(buyer);
        vm.expectRevert(NotListed.selector);
        hall.buyToken(TOKEN_ID, expectedPrice);
    }

    function testFuzz_buyToken_NotTokenOwner(uint256 price, uint256 expectedPrice) public {
        price = boundPrice(price);
        expectedPrice = boundPrice(expectedPrice);

        vm.prank(owner);
        stoken.mint(owner, TOKEN_ID + 1);

        vm.startPrank(seller);
        stoken.approve(address(hall), TOKEN_ID);
        vm.expectRevert(NotTokenOwner.selector);
        hall.createListing(TOKEN_ID + 1, price);
        vm.stopPrank();
    }

    function testFuzz_buyToken_InvalidPrice(uint256 price, uint256 expectedPrice) public {
        price = boundPrice(price);
        expectedPrice = boundPrice(expectedPrice);
        vm.assume(expectedPrice != price);

        createAndListToken(TOKEN_ID, price);

        vm.startPrank(buyer);
        usdc.approve(address(hall), expectedPrice);
        vm.expectRevert(InvalidPrice.selector);
        hall.buyToken(TOKEN_ID, expectedPrice);
        vm.stopPrank();
    }

    function testFuzz_withdrawStuckTokens_InvalidWithdrawal(uint256 amount) public {
        amount = bound(amount, 0, 1);
        address to = address(0);
        vm.startPrank(owner);
        vm.expectRevert(InvalidWithdrawal.selector);
        hall.withdrawStuckTokens(address(usdc), amount, to);
        vm.stopPrank();
    }

    function testFuzz_withdrawStuckTokens_AmountExceedsBalance(address to, uint256 amount) public {
        vm.startPrank(seller);
        usdc.transfer(address(hall), 500e6);
        vm.stopPrank();

        amount = bound(amount, usdc.balanceOf(address(hall)) + 1e6, type(uint128).max);
        vm.assume(to != address(0) && amount > 0);
        vm.startPrank(owner);
        vm.expectRevert(InvalidWithdrawal.selector);
        hall.withdrawStuckTokens(address(usdc), amount, to);
        vm.stopPrank();
    }

    function testFuzz_transactionFlow_Success(uint256 price) public {
        price = boundPrice(price);
        createAndListToken(TOKEN_ID, price);
        uint256 royalty_check = price * 5 / 100;

        (address recv, uint256 royalty) = stoken.royaltyInfo(TOKEN_ID, price);
        assertEq(royalty, royalty_check);
        assertEq(recv, owner);
        uint256 difference = price - royalty;

        vm.startPrank(buyer);
        usdc.approve(address(hall), price);
        hall.buyToken(TOKEN_ID, price);
        vm.stopPrank();

        assertEq(usdc.balanceOf(seller), INITIAL_USDC_SUPPLY + difference);
        assertEq(usdc.balanceOf(buyer), INITIAL_USDC_SUPPLY - price);
        assertEq(usdc.balanceOf(owner), royalty);
        assertEq(stoken.ownerOf(TOKEN_ID), buyer);
    }
}
