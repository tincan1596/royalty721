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
        uint256 id = 3;
        vm.prank(owner);
        stoken.transferFrom(owner, seller, id);

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

    function testBuyToken_notTokenOwner_reverts() public {
        uint256 id = 4;
        vm.prank(owner);
        stoken.transferFrom(owner, seller, id);

        approveMarketplaceAsSeller(id);
        vm.prank(seller);
        hall.createListing(id, 50);

        // transfer token away to someone else
        vm.prank(seller);
        stoken.transferFrom(seller, buyer, id);

        vm.prank(buyer);
        usdc.approve(address(hall), 50);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(TheHall.NotTokenOwner.selector));
        hall.buyToken(id, 50);
    }

    function testBuyToken_invalidPrice_reverts() public {
        uint256 id = 5;
        vm.prank(owner);
        stoken.transferFrom(owner, seller, id);

        approveMarketplaceAsSeller(id);
        vm.prank(seller);
        hall.createListing(id, 100);

        vm.prank(buyer);
        usdc.approve(address(hall), 100);

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

    // test InvalidRoyalty by using malicious token that returns royalty >= price

    function testBuyToken_invalidRoyalty_reverts() public {
        // deploy MockBadRoyalty and a new hall instance pointing at it
        MockBadRoyalty bad = new MockBadRoyalty(seller);
        TheHall badHall = new TheHall(IERC20(address(usdc)), ISToken(address(bad)));

        // list token id 1 using the mock (we don't need an actual token transfer because mock pretends owner)
        // call buyToken via the badHall; underlying listing storage is independent so create listing by calling createListing on badHall
        // but createListing checks sToken.ownerOf(id) == msg.sender; so prank seller
        vm.prank(seller);
        badHall.createListing(1, 100);

        vm.prank(buyer);
        usdc.approve(address(badHall), 100);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(TheHall.InvalidRoyalty.selector));
        badHall.buyToken(1, 100);
    }
}

// test InvalidRoyalty by using malicious token that returns royalty >= price
contract MockBadRoyalty is ISToken {
    address public ownerAddr;
    address private _approved;
    constructor(address _owner) {
        ownerAddr = _owner;
    }
    function royaltyInfo(uint256, uint256 salePrice) external pure override returns (address receiver, uint256 royaltyAmount) {
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
