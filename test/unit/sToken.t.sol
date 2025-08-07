// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {sToken} from "../../src/sToken/sToken.sol";

contract sTokenTest is Test {
    sToken public token;
    address theHall = address(0xBEEF);
    address alice = address(0xABCD);
    address bob = address(0xCAFE);

    function setUp() public {
        vm.prank(alice);
        token = new sToken(theHall, "ipfs://base/");
    }

    function testConstructor_MintsTenTokensToSender() public view {
        for (uint256 i = 0; i < 10; ++i) {
            assertEq(token.ownerOf(i), alice);
        }
    }

    function testConstructor_RevertsIfHallIsZero() public {
        vm.expectRevert(sToken.InvalidHallAddress.selector);
        new sToken(address(0), "ipfs://fail/");
    }

    function testTokenURI_ReturnsCorrectURI() public view {
        string memory expected = "ipfs://base/5.json";
        assertEq(token.tokenURI(5), expected);
    }

    function testApprove_WorksWhenOperatorIsTheHall() public {
        vm.startPrank(alice);
        token.approve(theHall, 1);
        assertEq(token.getApproved(1), theHall);
    }

    function testApprove_RevertsWhenOperatorIsNotTheHall() public {
        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true);
        emit sToken.ApprovalRestricted(1, bob);
        vm.expectRevert(sToken.OnlyMarketplace.selector);
        token.approve(bob, 1);
    }

    function testSetApprovalForAll_WorksWhenOperatorIsTheHall() public {
        vm.startPrank(alice);
        token.setApprovalForAll(theHall, true);
        assertTrue(token.isApprovedForAll(alice, theHall));
    }

    function testSetApprovalForAll_RevertsWhenOperatorIsNotTheHall() public {
        vm.startPrank(alice);
        vm.expectEmit(false, true, false, true);
        emit sToken.ApprovalRestricted(type(uint256).max, bob);
        vm.expectRevert(sToken.OnlyMarketplace.selector);
        token.setApprovalForAll(bob, true);
    }

    function testTransferFrom_WorksWhenCalledByTheHall() public {
        vm.startPrank(alice);
        token.approve(theHall, 3);

        vm.prank(theHall);
        token.transferFrom(alice, bob, 3);
        assertEq(token.ownerOf(3), bob);
    }

    function testTransferFrom_RevertsWhenCalledByNonHall() public {
        vm.startPrank(alice);
        token.approve(bob, 2);

        vm.expectRevert(abi.encodeWithSelector(sToken.TransferRestricted.selector, 2, alice, bob));
        vm.prank(bob);
        token.transferFrom(alice, bob, 2);
    }

    function testSafeTransferFrom_WorksWhenCalledByTheHall() public {
        vm.startPrank(alice);
        token.approve(theHall, 4);

        vm.prank(theHall);
        token.safeTransferFrom(alice, bob, 4);
        assertEq(token.ownerOf(4), bob);
    }

    function testSafeTransferFromWithData_WorksWhenCalledByTheHall() public {
        vm.startPrank(alice);
        token.approve(theHall, 7);

        vm.prank(theHall);
        token.safeTransferFrom(alice, bob, 7, "hello");
        assertEq(token.ownerOf(7), bob);
    }

    function testSafeTransferFrom_RevertsWhenCallerIsNotHall() public {
        vm.startPrank(alice);
        token.approve(bob, 8);

        vm.expectRevert(abi.encodeWithSelector(sToken.TransferRestricted.selector, 8, alice, bob));
        vm.prank(bob);
        token.safeTransferFrom(alice, bob, 8);
    }

    function testSupportsInterface_ReturnsTrueForSupportedInterfaces() public view {
        assertTrue(token.supportsInterface(0x01ffc9a7)); // ERC165
        assertTrue(token.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(token.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertTrue(token.supportsInterface(0x2a55205a)); // ERC2981
    }

    function testSupportsInterface_ReturnsFalseForUnsupportedInterface() public view {
        assertFalse(token.supportsInterface(0x12345678));
    }
}
