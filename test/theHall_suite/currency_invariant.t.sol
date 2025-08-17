// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {mUSDC} from "../../src/mUSDC/mUSDC.sol";
import {sToken} from "../../src/sToken/sToken.sol";
import {TheHall, IERC20, ISToken} from "../../src/theHall/theHall.sol";
import {HallHandler} from "./currency_handler.t.sol";

contract InvariantHallTest is Test {
    mUSDC usdc;
    sToken stoken;
    TheHall hall;
    HallHandler handler;

    address stokenOwner;

    function setUp() public {
        stokenOwner = address(this);

        usdc = new mUSDC();
        stoken = new sToken();
        hall = new TheHall(IERC20(address(usdc)), ISToken(address(stoken)));
        handler = new HallHandler(address(usdc), address(stoken), address(hall), stokenOwner);

        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = handler.mintAndList.selector;
        selectors[1] = handler.buy.selector;
        selectors[2] = handler.mintListBuy.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    // global accounting: sumPrice == sumRoyalty + sumRevenue
    function invariant_currency_accounting() public view {
        assertEq(handler.sumPrice(), handler.sumRoyalty() + handler.sumRevenue());
    }

    // royalty check
    function invariant_royalty_rate() public view {
        assertEq(handler.sumRoyalty() * 100, handler.sumPrice() * 5); // Multiplying avoids fractional rounding.
    }

    // ownership sanity
    function invariant_no_double_ownership() public view {
        for (uint256 id = 0; id < 10; ++id) {
            try stoken.ownerOf(id) returns (address o) {
                require(o != address(0), "owner zero for minted token");
            } catch {}
        }
    }
}
