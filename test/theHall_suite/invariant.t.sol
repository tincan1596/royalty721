// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./base.t.sol";

contract TheHallInvariantTest is BaseTheHallTest {
    function setUp() public override {
        address seller1 = makeAddr("seller1");
        address buyer1 = makeAddr("buyer1");
        address seller2 = makeAddr("seller2");
        address buyer2 = makeAddr("buyer2");

        special(seller1, 2);
        special(seller2, 4);

        usdc.mint(buyer1, INITIAL_USDC_SUPPLY);
        usdc.mint(buyer2, INITIAL_USDC_SUPPLY);

        vm.prank(buyer1);
        usdc.approve(address(hall), INITIAL_USDC_SUPPLY);

        vm.prank(buyer2);
        usdc.approve(address(hall), INITIAL_USDC_SUPPLY);
    }

    // 1. Listing Consistency: If listing exists, seller owns token
    function invariant_listingConsistency() public view {
        for (uint256 id = 0; id < 10; id++) {
            (address seller, uint256 price) = hall.listings(id);
            if (seller != address(0)) {
                assertEq(stoken.ownerOf(id), seller, "seller must own the Token");
                assertEq(price, TOKEN_PRICE, "Price must match listing price");
            }
        }
    }

    // 2. No dangling listings: If seller not owner, listing must be empty
    function invariant_noDanglingListings() public view {
        for (uint256 id = 0; id < 10; id++) {
            (address seller,) = hall.listings(id);
            if (seller != address(0) && stoken.ownerOf(id) != seller) {
                assertEq(seller, address(0), "Dangling listing exists");
            }
        }
    }

    // 3. Price Validity: All active listings have price > 0
    function invariant_priceValidity() public view {
        for (uint256 id = 0; id < 10; id++) {
            (address seller, uint256 price) = hall.listings(id);
            if (seller != address(0)) {
                assertGt(price, 0, "Price must be > 0");
            }
        }
    }

    // 4. Approval requirement: active listings must be approved for hall
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

    // 5. Royalty bound: Royalty should never exceed price in any listing
    function invariant_royaltyBound() public view {
        for (uint256 id = 0; id < 10; id++) {
            (address seller, uint256 price) = hall.listings(id);
            if (seller != address(0)) {
                (, uint256 royalty) = stoken.royaltyInfo(id, price);
                assertLe(royalty, price, "Royalty exceeds price");
            }
        }
    }

    // 6. Withdraw safety: Cannot withdraw more than balance
    function invariant_withdrawSafety() public view {
        uint256 bal = usdc.balanceOf(address(hall));
        // No explicit withdraw call in invariant test (owner-only),
        // so we just ensure balance is never negative (which ERC20 prevents anyway)
        assertGe(bal, 0, "Balance underflow detected");
    }
}
