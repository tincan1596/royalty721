// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {BaseTheHallTest} from "./base.t.sol";
import {TheHall, ISToken} from "../../src/theHall/theHall.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Unit_Revert is BaseTheHallTest {
    function testCreateListing_zeroPrice_reverts() public {
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(TheHall.ZeroPrice.selector));
        hall.createListing(0, 0);
    }

    function testCreateListing_notOwner_reverts() public {
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(TheHall.NotOwner.selector));
        hall.createListing(0, 1);
    }

    function testCreateListing_alreadyListed_reverts() public {
        uint256 id = 0;
        approveMarketplaceAsSeller(id);
        vm.prank(seller);
        hall.createListing(id, 10);

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(TheHall.AlreadyListed.selector));
        hall.createListing(id, 20);
    }

    function testCreateListing_notApproved_reverts() public {
        uint256 id = 0;

        // ensure no approval
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(TheHall.NotApproved.selector));
        hall.createListing(id, 10);
    }

    function testCancelListing_notSeller_reverts() public {
        uint256 id = 0;
        createAndListToken(id, 10);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(TheHall.NotSeller.selector));
        hall.cancelListing(id);
    }

    function testBuyToken_notListed_reverts() public {
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(TheHall.NotListed.selector));
        hall.buyToken(9999, 1);
    }

    function testBuyToken_invalidPrice_reverts() public {
        uint256 id = 0;

        approveMarketplaceAsSeller(id);
        vm.prank(seller);
        hall.createListing(id, TOKEN_PRICE);

        vm.prank(buyer);
        usdc.approve(address(hall), TOKEN_PRICE);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(TheHall.InvalidPrice.selector));
        hall.buyToken(id, 99);
    }

    function testWithdraw_nonOwner_reverts() public {
        vm.prank(buyer);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        hall.withdrawStuckTokens(address(usdc), 1, buyer);
    }

    function testWithdraw_invalidParams_reverts() public {
        uint256 amt = 1_000e6;
        vm.prank(seller);
        usdc.transfer(address(hall), amt);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(TheHall.InvalidWithdrawal.selector));
        hall.withdrawStuckTokens(address(usdc), 0, owner);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(TheHall.InvalidWithdrawal.selector));
        hall.withdrawStuckTokens(address(usdc), amt + 1, owner);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(TheHall.InvalidWithdrawal.selector));
        hall.withdrawStuckTokens(address(usdc), amt, address(0));
    }

    function testPause_nonOwner_reverts() public {
        vm.prank(buyer);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        hall.pause();
    }

    function testOperations_whenPaused_revert() public {
        vm.prank(owner);
        hall.pause();

        vm.prank(seller);
        vm.expectRevert(bytes("Pausable: paused"));
        hall.createListing(0, 1);
    }

    // test InvalidRoyalty by using malicious token 

    function testBuyToken_invalidRoyalty_reverts() public {
        
        MockBadRoyalty bad = new MockBadRoyalty(seller);
        vm.expectRevert();
        new TheHall(IERC20(address(usdc)), ISToken(address(bad)));
    }
}

contract MockBadRoyalty is ISToken {
    address public ownerAddr;
    address private _approved;

    constructor(address _owner) {
        ownerAddr = _owner;
    }

    function royaltyInfo(uint256, uint256 salePrice)
        external
        pure
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (address(0xDEAD), salePrice); // royalty == price
    }

    function ownerOf(uint256) external view override returns (address) {
        return ownerAddr;
    }

    function safeTransferFrom(address, address, uint256) external override {}

    function getApproved(uint256) external view override returns (address) {
        return address(this);
    }

    function isApprovedForAll(address, address) external pure override returns (bool) {
        return true;
    }
}
