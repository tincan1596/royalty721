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

    event sum(uint256 output);

    function setUp() public {
        stokenOwner = address(this);

        usdc = new mUSDC();
        stoken = new sToken();
        hall = new TheHall(IERC20(address(usdc)), ISToken(address(stoken)));
        handler = new HallHandler(address(usdc), address(stoken), address(hall), stokenOwner);

        stoken.setTheHall(address(hall));
    }

    function testSanityMintAndList() public {
        uint256 seed = 1;
        uint256 beed = 2;
        uint256 rawId = 5;
        uint256 rawPrice = 500e6;
        uint256 approveModeSeed = 0;

        handler.mintAndList(seed, rawId, rawPrice, approveModeSeed);
        //handler.buy(beed, rawId);
        handler.mintListBuy(seed, beed, rawId, rawPrice, approveModeSeed);

        emit sum(handler.sumPrice());
        emit sum(handler.sumRoyalty() + handler.sumRevenue());
    }
}
