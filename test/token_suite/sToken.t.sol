// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {sToken} from "../../src/sToken/sToken.sol";
import {TheHall, IERC20, ISToken} from "../../src/theHall/theHall.sol";

contract sTokenTest is Test {
    TheHall public hall;
    sToken public token;
    address owner = address(0xBEEF);
    address alice = address(0xABCD);
    address bob = address(0xCAFE);

    function setUp() public {
        vm.startPrank(owner);
        token = new sToken();
        hall = new TheHall(IERC20(address(0)), ISToken(address(token)));
        token.setTheHall(address(hall));
        vm.stopPrank();
    }

    // --- Constructor ---
    function testConstructorSetsOwnerAndRoyalty() public view {
        assertEq(token.owner(), owner);
        (address rReceiver, uint256 fee) = token.royaltyInfo(1, 10000);
        assertEq(rReceiver, owner);
        assertEq(fee, 500); // 5%
    }

    // --- Mint ---
    function testMint() public {
        vm.prank(owner);
        token.mint(alice, 1);
        assertEq(token.ownerOf(1), alice);
    }

    function testMintRevertNotOwner() public {
        vm.expectRevert(sToken.NotOwner.selector);
        token.mint(alice, 1);
    }

    // --- setTheHall ---
    function testSetTheHall() public {
        vm.prank(owner);
        token.setTheHall(address(hall));
        assertEq(token.theHall(), address(hall));
    }

    function testSetTheHallRevertNotOwner() public {
        vm.expectRevert(sToken.NotOwner.selector);
        token.setTheHall(address(hall));
    }

    function testSetTheHallRevertZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(sToken.HallNotFixed.selector);
        token.setTheHall(address(0));
    }

    function testSetTheHallRevertHallAlreadySet() public {
        vm.startPrank(owner);
        token.setTheHall(address(hall));
        vm.expectRevert(sToken.HallFixed.selector);
        token.setTheHall(address(0x123));
        vm.stopPrank();
    }

    // --- Approve ---
    function testApprove() public {
        vm.startPrank(owner);
        token.mint(alice, 1);
        token.setTheHall(address(hall));
        vm.stopPrank();

        vm.prank(alice);
        token.approve(address(hall), 1);
        assertEq(token.getApproved(1), address(hall));
    }

    function testApproveRevertHallNotSet() public {
        vm.startPrank(owner);
        token.mint(alice, 1);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(sToken.HallNotFixed.selector);
        token.approve(address(hall), 1);
    }

    function testApproveRevertOnlyMarketplace() public {
        vm.startPrank(owner);
        token.mint(alice, 1);
        token.setTheHall(address(hall));
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(sToken.OnlyMarketplace.selector);
        token.approve(address(0x123), 1);
    }

    // --- setApprovalForAll ---
    function testSetApprovalForAll() public {
        vm.prank(owner);
        token.setTheHall(address(hall));

        vm.prank(owner);
        token.setApprovalForAll(address(hall), true);
        assertTrue(token.isApprovedForAll(owner, address(hall)));
    }

    function testSetApprovalForAllRevertHallNotSet() public {
        vm.prank(owner);
        vm.expectRevert(sToken.HallNotFixed.selector);
        token.setApprovalForAll(address(hall), true);
    }

    function testSetApprovalForAllRevertOnlyMarketplace() public {
        vm.prank(owner);
        token.setTheHall(address(hall));

        vm.expectRevert(sToken.OnlyMarketplace.selector);
        token.setApprovalForAll(address(0x999), true);
    }

    // --- Transfers ---
    function testTransferFrom() public {
        vm.startPrank(owner);
        token.mint(alice, 1);
        vm.stopPrank();

        vm.prank(alice);
        token.approve(address(hall), 1);

        vm.prank(address(hall));
        token.transferFrom(alice, bob, 1);
        assertEq(token.ownerOf(1), bob);
    }

    function testTransferFromRevertHallNotSet() public {
        vm.startPrank(owner);
        token.mint(alice, 1);
        vm.stopPrank();

        vm.prank(alice);
        token.approve(address(hall), 1);

        vm.prank(alice);
        vm.expectRevert(sToken.HallNotFixed.selector);
        token.transferFrom(alice, bob, 1);
    }

    function testTransferFromRevertNotHall() public {
        vm.startPrank(owner);
        token.mint(alice, 1);
        token.setTheHall(address(hall));
        vm.stopPrank();

        vm.prank(alice);
        token.approve(address(hall), 1);

        vm.prank(alice);
        vm.expectRevert();
        token.transferFrom(alice, bob, 1);
    }

    function testSafeTransferFrom() public {
        vm.startPrank(owner);
        token.mint(alice, 1);
        token.setTheHall(address(hall));
        vm.stopPrank();

        vm.prank(alice);
        token.approve(address(hall), 1);

        vm.prank(address(hall));
        token.safeTransferFrom(alice, bob, 1);
        assertEq(token.ownerOf(1), bob);
    }

    function testSafeTransferFromWithData() public {
        vm.startPrank(owner);
        token.mint(alice, 1);
        token.setTheHall(address(hall));
        vm.stopPrank();

        vm.prank(alice);
        token.approve(address(hall), 1);

        vm.prank(address(hall));
        token.safeTransferFrom(alice, bob, 1, "0x1234");
        assertEq(token.ownerOf(1), bob);
    }

    function testSafeTransferFromRevertNotHall() public {
        vm.startPrank(owner);
        token.mint(alice, 1);
        token.setTheHall(address(hall));
        vm.stopPrank();

        vm.prank(alice);
        token.approve(address(hall), 1);

        vm.prank(alice);
        vm.expectRevert();
        token.safeTransferFrom(alice, bob, 1);
    }

    // --- tokenURI ---
    function testTokenURI() public view {
        string memory uri = token.tokenURI(1);
        assertEq(uri, "ipfs://base/1.json");
    }

    // --- supportsInterface ---
    function testSupportsInterface() public view {
        assertTrue(token.supportsInterface(0x01ffc9a7)); // ERC165
        assertTrue(token.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(token.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertTrue(token.supportsInterface(0x2a55205a)); // ERC2981
    }
}
