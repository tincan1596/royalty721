// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/sToken/sToken.sol";
import "../src/theHall/theHall.sol";
import "../src/mUSDC/mUSDC.sol";

contract Deploy is Script {
    function run() external {
        // Use the default deployer
        address deployer = msg.sender;

        vm.startBroadcast();

        // 1. Deploy mUSDC
        mUSDC usdc = new mUSDC();

        // 2. Predict TheHall's address (deployer's next nonce will be used)
        uint256 futureNonce = vm.getNonce(deployer) + 1;
        address predictedHall = computeCreateAddress(deployer, futureNonce);

        // 3. Deploy sToken using predicted TheHall address
        sToken token = new sToken(predictedHall, "ipfs://baseURI/");

        // 4. Deploy TheHall using actual deployed sToken
        TheHall hall = new TheHall(IERC20(address(usdc)), ISToken(address(token)));

        // 5. Fund the buyer for testing (optional)
        usdc.mint(deployer, 10_000e6);

        // 6. Batch-list all 10 NFTs
        for (uint256 i = 0; i < 10; ++i) {
            hall.createListing(i, 500e6);
        }

        vm.stopBroadcast();

        console.log("Predicted TheHall address: ", predictedHall);
        console.log("Actual TheHall address: ", address(hall));
    }

    function computeCreateAddress(address deployer, uint256 nonce) internal pure override returns (address) {
        if (nonce == 0x00) {
            return address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80)))))
            );
        }
        if (nonce <= 0x7f) {
            return address(
                uint160(
                    uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(uint8(nonce)))))
                )
            );
        }
        if (nonce <= 0xff) {
            return address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), bytes1(uint8(nonce)))
                        )
                    )
                )
            );
        }
        if (nonce <= 0xffff) {
            return address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), bytes2(uint16(nonce)))
                        )
                    )
                )
            );
        }
        revert("Nonce too high");
    }
}
