// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./base.t.sol";

contract TheHallInvariantTest is BaseTheHallTest {
    address seller1 = makeAddr("seller1");
    address buyer1 = makeAddr("buyer1");
    address seller2 = makeAddr("seller2");
    address buyer2 = makeAddr("buyer2");

    function setUp() public override {
        specialSeller(seller1, 2);
        specialSeller(seller2, 4);

        vm.startPrank(owner);
        usdc.burn(seller, usdc.balanceOf(seller));
        usdc.burn(owner, usdc.balanceOf(owner));
        usdc.burn(buyer, usdc.balanceOf(buyer));
        vm.stopPrank();
    }

    function makeList(address by, uint256 cost, uint256 id) internal {
        vm.startPrank(by);
        stoken.approve(address(hall), id);
        hall.createListing(id, cost);
        vm.stopPrank;
    }

    function listCancel(address by, uint256 id) internal {
        vm.prank(by);
        hall.cancelListing(id);
    }

    function buy(address by, uint256 id, uint256 cost) internal {
        vm.startPrank(by);
        hall.buyToken(id, cost);
        vm.stopPrank();
    }

    // Listing Consistency: If listing exists, seller owns token
    function invariant_listingConsistency() public view {
        for (uint256 id = 0; id < 10; id++) {
            (address seller, uint256 price) = hall.listings(id);
            if (seller != address(0)) {
                assertEq(stoken.ownerOf(id), seller, "seller must own the Token");
                assertEq(price, TOKEN_PRICE, "Price must match listing price");
            }
        }
    }

    // No dangling listings: If seller not owner, listing must be empty
    function invariant_noDanglingListings() public view {
        for (uint256 id = 0; id < 10; id++) {
            (address seller,) = hall.listings(id);
            if (seller != address(0) && stoken.ownerOf(id) != seller) {
                assertEq(seller, address(0), "Dangling listing exists");
            }
        }
    }

    // Approval requirement: active listings must be approved for hall
    function invariant_approvalRequirement() public view {
        for (uint256 id = 0; id < 10; id++) {
            (address seller,) = hall.listings(id);
            if (seller != address(0)) {
                bool approved =
                    (stoken.getApproved(id) == address(hall) || stoken.isApprovedForAll(seller, address(hall)));
                assertTrue(approved, "Listed token not approved");
            }
        }
    }

    // currency circulation
    function invariant_currencyCirculation(uint256 cost, uint256 cost1, uint256 cost2) public {
        cost = boundPrice(cost);
        listCancel(seller, 0);
        listCancel(seller1, 2);
        listCancel(seller2, 4);

        specialBuyer(buyer, cost);
        specialBuyer(buyer1, cost1);
        specialBuyer(buyer2, cost2);
        uint256 sumInit = usdc.balanceOf(buyer) + usdc.balanceOf(buyer1) + usdc.balanceOf(buyer2);

        makeList(seller, cost, 0);
        makeList(seller1, cost1, 2);
        makeList(seller2, cost2, 4);
        uint256 royalty = 5 * sumInit / 100;

        buy(buyer, 0, cost);
        buy(buyer1, 2, cost1);
        buy(buyer2, 4, cost2);

        uint256 sumFinal =
            usdc.balanceOf(seller) + usdc.balanceOf(seller1) + usdc.balanceOf(seller2) + usdc.balanceOf(owner);
        assertEq(sumInit, sumFinal, "Currency circulation invariant violated");
        assertEq(usdc.balanceOf(buyer), royalty, "Buyer should have no USDC left");
    }
}
