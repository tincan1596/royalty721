// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {TheHall, ISToken} from "../../src/theHall/theHall.sol";
import {sToken} from "../../src/sToken/sToken.sol";
import {mUSDC} from "../../src/mUSDC/mUSDC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseHallTest is Test {
    TheHall internal hall;
    sToken internal nft;
    mUSDC internal usdc;

    // Roles
    address internal deployer;
    address internal seller; // will be the deployer (initial sToken owner)
    address internal buyer;
    address internal other;

    // simple helper to mint mUSDC (mUSDC.mint is onlyOwner)
    function _mintUSDC(address to, uint256 amount) internal {
        vm.prank(deployer);
        usdc.mint(to, amount);
    }

    // Base setUp used by all test children
    function setUp() public virtual {
        deployer = makeAddr("deployer");
        // seller must be the deployer here because sToken restricts transfers to theHall only.
        seller = deployer;
        buyer = makeAddr("buyer");
        other = makeAddr("other");

        // Deploy contracts as deployer
        vm.startPrank(deployer);
        usdc = new mUSDC(); // deployer becomes owner of mUSDC (onlyOwner mint)
        nft = new sToken("ipfs://base/"); // sToken constructor mints 0..9 to deployer
        // Instantiate TheHall, casting nft to ISToken explicitly
        hall = new TheHall(IERC20(address(usdc)), ISToken(address(nft)));
        vm.stopPrank();

        // Link the sToken to theHall (deployer is nft owner so allowed)
        vm.prank(deployer);
        nft.setTheHall(address(hall));

        // Mint currency to seller (deployer) and buyer
        _mintUSDC(seller, 1_000_000e6); // 1,000,000 mUSDC
        _mintUSDC(buyer, 1_000_000e6);

        // Sanity: ensure token 0 owned by seller/deployer
        assertEq(nft.ownerOf(0), seller);
    }

    /// @notice helper: approve & create listing from seller
    function _approveAndList(uint256 tokenId, uint256 price) internal {
        vm.startPrank(seller);
        // sToken.approve only allows theHall as operator; that's exactly what we do
        nft.approve(address(hall), tokenId);
        hall.createListing(tokenId, price);
        vm.stopPrank();
    }
}
