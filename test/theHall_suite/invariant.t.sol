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
    function invariant_currencyCirculation() public {
        specialBuyer(buyer1);
        specialBuyer(buyer2);
        usdc.balanceOf(buyer) + usdc.balanceOf(buyer1) + usdc.balanceOf(buyer2);
    }
}
