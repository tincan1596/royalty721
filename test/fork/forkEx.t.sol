// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/* interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract ExampleForkTest is Test {
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    uint256 mainnetFork;

    function setUp() public {
        // Select Ethereum mainnet fork with RPC set in CI
        mainnetFork = vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 18_000_000);
    }

    function testDAIBalance() public view {
        // Known whale address
        address whale = 0x28C6c06298d514Db089934071355E5743bf21d60;
        uint256 bal = DAI.balanceOf(whale);

        // Should hold at least 1000 DAI
        assertGt(bal, 1000e18);
    }
}*/
