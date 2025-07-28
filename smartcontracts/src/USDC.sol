// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "lib/solady/src/tokens/ERC20.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

contract USDC is ERC20, Ownable {
    constructor() {
        _mint(msg.sender, 1000 * 10 ** decimals());
        _initializeOwner(msg.sender);
    }

    function name() public pure override returns (string memory) {
        return "USD Coin";
    }

    function symbol() public pure override returns (string memory) {
        return "USDC";
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint2(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }
}
