// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { FlashLoanerPool } from "./FlashLoanerPool.sol";
import { TheRewarderPool } from "./TheRewarderPool.sol";
import "../DamnValuableToken.sol";

contract HackTheRewarder {
    FlashLoanerPool flashLoan;
    TheRewarderPool pool;

    constructor(FlashLoanerPool _flashLoan, TheRewarderPool _pool) {
        flashLoan = _flashLoan;
        pool = _pool;
    }

    function hack(uint amount) {
        flashLoan.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) {
        
    }

}