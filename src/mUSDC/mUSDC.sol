// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract mUSDC is ERC20, Ownable {
    event minted(address indexed to, uint256 amount);

    constructor() ERC20("Mock USDC", "mUSDC", 6) Ownable() {}

    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Cannot mint to zero address");
        _mint(to, amount);
        emit minted(to, amount);
    }
}
