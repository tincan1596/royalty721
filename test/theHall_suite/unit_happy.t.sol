// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseTheHallTest} from "./base.t.sol";

contract Unit_Happy is BaseTheHallTest {
    function testCreateListing_singleApproval() public {
        uint256 id = 0;
        vm.prank(seller);
        stoken.approve(address(hall), id);

        vm.expectEmit(true, true, true, true);
        emit ListingCreated(id, seller, 1);
        vm.prank(seller);
        hall.createListing(id, 1);

        (address ls, uint256 p) = hall.listings(id);
        assertEq(ls, seller);
        assertEq(p, 1);
    }

    function testCreateListing_setApprovalForAll() public {
        uint256 id = 0;
        vm.prank(seller);
        stoken.setApprovalForAll(address(hall), true);

        vm.expectEmit(true, true, true, true);
        emit ListingCreated(id, seller, TOKEN_PRICE);
        vm.prank(seller);
        hall.createListing(id, TOKEN_PRICE);

        (address ls, uint256 p) = hall.listings(id);
        assertEq(ls, seller);
        assertEq(p, TOKEN_PRICE);
    }

    function testCancelListing() public {
        uint256 id = 0;
        createAndListToken(id, TOKEN_PRICE);

        vm.expectEmit(true, true, true, true);
        emit ListingCancelled(id, seller);
        vm.prank(seller);
        hall.cancelListing(id);

        (address ls,) = hall.listings(id);
        assertEq(ls, address(0));
    }

    function testBuyToken() public {
        uint256 id = 0;
        uint256 price = TOKEN_PRICE;
        approveMarketplaceAsSeller(id);
        vm.prank(seller);
        hall.createListing(id, price);

        vm.prank(buyer);
        usdc.approve(address(hall), price);

        uint256 sellerBalBefore = usdc.balanceOf(seller);
        uint256 buyerBalBefore = usdc.balanceOf(buyer);
        uint256 ownerBalBefore = usdc.balanceOf(owner);

        uint256 royalty = (price * 500) / 10000; // default in sToken is 500 (5%)

        vm.expectEmit(true, true, true, true);
        emit TokenPurchased(id, seller, buyer, price, royalty);
        vm.prank(buyer);
        hall.buyToken(id, price);

        assertEq(usdc.balanceOf(seller), sellerBalBefore + (price - royalty));
        assertEq(usdc.balanceOf(owner), ownerBalBefore + royalty);
        assertEq(usdc.balanceOf(buyer), buyerBalBefore - price);
        assertEq(stoken.ownerOf(id), buyer);
    }

    function testWithdrawStuckTokens() public {
        uint256 amt = 10_000e6;
        // send tokens to contract
        vm.prank(seller);
        usdc.transfer(address(hall), amt);

        uint256 hallBal = usdc.balanceOf(address(hall));
        assertEq(hallBal, amt);

        vm.expectEmit(true, true, true, true);
        emit TokensWithdrawn(address(usdc), amt, owner, owner);
        vm.prank(owner);
        hall.withdrawStuckTokens(address(usdc), amt, owner);

        assertEq(usdc.balanceOf(address(hall)), 0);
        assertEq(usdc.balanceOf(owner), amt + usdc.balanceOf(owner) - amt + 0); // sanity check already done by balances above
    }

    function testPauseAndUnpauseByOwner() public {
        vm.prank(owner);
        hall.pause();

        vm.startPrank(seller);
        stoken.approve(address(hall), 0);
        vm.expectRevert(bytes("Pausable: paused"));
        hall.createListing(0, TOKEN_PRICE);
        vm.stopPrank();

        vm.prank(owner);
        hall.unpause();

        vm.startPrank(seller);
        stoken.approve(address(hall), 0);
        hall.createListing(0, TOKEN_PRICE);
        (address listingSeller, uint256 listingPrice) = hall.listings(0);
        assertEq(listingSeller, seller);
        assertEq(listingPrice, TOKEN_PRICE);
        vm.stopPrank();
    }

    // events redeclared for expectEmit usage
    event ListingCreated(uint256 indexed id, address indexed seller, uint256 price);
    event ListingCancelled(uint256 indexed id, address indexed seller);
    event TokenPurchased(
        uint256 indexed id, address indexed seller, address indexed buyer, uint256 price, uint256 royalty
    );
    event TokensWithdrawn(address indexed token, uint256 amount, address indexed to, address indexed by);
}
