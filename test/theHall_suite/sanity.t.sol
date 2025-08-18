// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {mUSDC} from "../../src/mUSDC/mUSDC.sol";
import {sToken} from "../../src/sToken/sToken.sol";
import {TheHall, IERC20, ISToken} from "../../src/theHall/theHall.sol";
import {HallHandler} from "./currency_handler.t.sol";

contract Sanity is Test {
    mUSDC usdc;
    sToken stoken;
    TheHall hall;
    HallHandler handler;
    address stokenOwner;

    function setUp() public {
        usdc = new mUSDC();
        stoken = new sToken();
        hall = new TheHall(IERC20(address(usdc)), ISToken(address(stoken)));
        handler = new HallHandler(address(usdc), address(stoken), address(hall), stokenOwner);
        stokenOwner = msg.sender;
    }

    function testSanityMintAndList() public {
        uint256 seed = 1; // arbitrary
        uint256 rawId = 5; // maps to tokenId 5
        uint256 rawPrice = 500e6; // maps nicely into your price range
        uint256 approveModeSeed = 0; // depends on your handler logic

        handler.mintAndList(seed, rawId, rawPrice, approveModeSeed);
    }
}
