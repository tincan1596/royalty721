// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {mUSDC} from "../../src/mUSDC/mUSDC.sol";
import {sToken} from "../../src/sToken/sToken.sol";
import {TheHall, ISToken} from "../../src/theHall/theHall.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseTheHallTest is Test {
    mUSDC internal usdc;
    sToken internal stoken;
    TheHall internal hall;

    address internal owner = makeAddr("owner");
    address internal seller = makeAddr("seller");
    address internal buyer = makeAddr("buyer");
    uint256 internal constant INITIAL_USDC_SUPPLY = 1_000_000e6;
    uint256 internal constant TOKEN_PRICE = 100e6;

    function setUp() public virtual {
        vm.startPrank(owner);
        usdc = new mUSDC();
        stoken = new sToken();
        hall = new TheHall(IERC20(address(usdc)), ISToken(address(stoken)));
        vm.stopPrank();

        vm.prank(owner);
        stoken.setTheHall(address(hall));

        // Mint USDC to buyer and seller for testing
        vm.startPrank(owner);
        usdc.mint(buyer, INITIAL_USDC_SUPPLY);
        usdc.mint(seller, INITIAL_USDC_SUPPLY);
        vm.stopPrank();

        // Transfer a token from owner to seller
        vm.startPrank(owner);
        stoken.mint(owner,0);
        stoken.setApprovalForAll(address(hall), true);
        hall.createListing(0, TOKEN_PRICE);
        vm.stopPrank();
        vm.startPrank(seller);
        usdc.approve(address(hall), TOKEN_PRICE);
        hall.buyToken(0, TOKEN_PRICE);
        vm.stopPrank();
    }

    function approveMarketplaceAsSeller(uint256 tokenId) internal {
        vm.startPrank(seller);
        stoken.approve(address(hall), tokenId);
        vm.stopPrank();
    }

    function createAndListToken(uint256 tokenId, uint256 price) internal {
        approveMarketplaceAsSeller(tokenId);
        vm.startPrank(seller);
        hall.createListing(tokenId, price);
        vm.stopPrank();
    }

    function fundBuyer(uint256 amount) internal {
        vm.startPrank(owner);
        usdc.mint(buyer, amount);
        vm.stopPrank();
    }
}
