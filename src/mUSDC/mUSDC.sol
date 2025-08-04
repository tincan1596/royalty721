// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC20Permit} from "solmate/tokens/ERC20Permit.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract mUSDC is ERC20Permit, Ownable {
    constructor(address _owner)
        ERC20("Mock USDC", "mUSDC", 6)
        ERC20Permit("Mock USDC")
        Ownable(_owner)
    {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

