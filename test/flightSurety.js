var Test = require('../config/testConfig.js');
// var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {


    var config;

    before('setup contract', async () => {
        config = await Test.Config(accounts);
        try {
            await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
        } catch (e) {
            console.error('Failed during setup contract', {e})
        }
    });


    //////////////////////////
    // Operations and Settings
    //////////////////////////

    it(`(deployment) has an app contract linked to the data contract`, async function () {
        const dataAddr = await config.flightSuretyApp.getDataContractAddress();
        assert.equal(dataAddr, config.flightSuretyData.address, 'App should be linked to correct data contract');
    });


    it(`(deployment) has one registered airline`, async function () {
        const num = await config.flightSuretyApp.registeredAirlinesCount();
        assert.equal(num.toNumber(), 1, 'Exactly one airline should be registered');
    });


    it(`(multiparty) has correct initial isOperational() value`, async function () {


        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });


    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {


        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSurety.setOperatingStatus(false, {from: config.testAddresses[2]});
        } catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });


    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {


        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, {from: config.owner});
        } catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access should not be denied to Contract Owner");
    });


    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {


        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
        } catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);


    });


    it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

        // ARRANGE
        let newAirline = accounts[2];

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
        } catch (e) {
            // ignore
        }
        let result = await config.flightSuretyData.isAirline.call(newAirline);

        // ASSERT
        assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

    });


    it('(airline) cannot be funded below MINIMUM FUND requirements', async () => {
        // ARRANGE
        const tenEth = web3.utils.toWei("9");
        // ACT
        try {
            await config.flightSuretyApp.fund({from: config.firstAirline, value: tenEth});
        } catch (e) {
            // ignore
        }
        let result = await config.flightSuretyData.isFundedAirline.call(config.firstAirline);
        // ASSERT
        assert.equal(result, false, "Airline should not be funded if it is unable to meet the minimum funding requirements");
    });


    it('(airline) can be FUNDED if funding requirements are met', async () => {
        // ARRANGE
        const tenEth = web3.utils.toWei("10");
        // ACT
        try {
            await config.flightSuretyApp.fund({from: config.firstAirline, value: tenEth});
        } catch (e) {
            console.error("Ooops - unexpected error!", {e})
        }
        let result = await config.flightSuretyData.isFundedAirline.call(config.firstAirline);
        // ASSERT
        assert.equal(result, true, "Airline should be funded if minimum funding requirements met");
    });


    it(`(deployment) has an app contract linked to the data contract`, async function () {
        const dataAddr = await config.flightSuretyApp.getDataContractAddress();
        assert.equal(dataAddr, config.flightSuretyData.address, 'App should be linked to correct data contract');
    });


    it('(airline) cannot be funded twice', async () => {

        // ARRANGE
        const tenEth = web3.utils.toWei("10");
        let reverted = false;
        // ACT
        try {
            await config.flightSuretyApp.fund({from: config.firstAirline, value: tenEth});
        } catch (e) {
            reverted = true;
        }
        // ASSERT
        assert.equal(reverted, true, "Airline should not be able to supply funding twice");
    });


    it('(airline) once funded can register a new airline', async () => {
        // ARRANGE

        // NOTE: Airline 1 is already funded from previous step
        const airline2 = accounts[2];

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(airline2, {from: config.firstAirline, gas: 100000});
        } catch (e) {
            console.error("Ooops - unexpected error!", {e})
        }
        let resultA = await config.flightSuretyData.isAirline.call(airline2);

        // ASSERT
        assert.equal(resultA, true, "When first airline is funded it should be able to register another airline");
    });


    it('(airline) once funded can register two more airlines', async () => {
        // ARRANGE

        // NOTE: Airline 1 is already funded from previous step
        // const airline2 = accounts[2];
        const airline3 = accounts[3];
        const airline4 = accounts[4];

        // ACT
        try {
            // await config.flightSuretyApp.registerAirline(airline2, {from: config.firstAirline});
            await config.flightSuretyApp.registerAirline(airline3, {from: config.firstAirline});
            await config.flightSuretyApp.registerAirline(airline4, {from: config.firstAirline});
        } catch (e) {
            console.error("Ooops - unexpected error!", {e})
        }
        // let resultA = await config.flightSuretyData.isAirline.call(airline2);
        let resultB = await config.flightSuretyData.isAirline.call(airline3);
        let resultC = await config.flightSuretyData.isAirline.call(airline4);

        // ASSERT
        // assert.equal(resultA, true, "When first airline is funded it should be able to register another airline");
        assert.equal(resultB, true, "When first airline is funded it should be able to register a second airline");
        assert.equal(resultC, true, "When first airline is funded it should be able to register a third airline");
    });


    it('(airline) can request to register fifth airline, but will not initially succeed (minimum votes required)', async () => {
        // ARRANGE
        let result = {};
        const num = await config.flightSuretyApp.registeredAirlinesCount();
        assert.equal(num.toNumber(), 4, 'At this point there should be 4 registered airlines (from previous steps)');
        const airline5 = accounts[5];

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(airline5, {from: config.firstAirline});
            result = await config.flightSuretyApp.getAirlineStatus(airline5);
        } catch (e) {
            console.error("Ooops - unexpected error!", {e})
        }

        // ASSERT
        assert.equal(result.votes.toNumber(), 1, "When registering the fifth airline, a single vote should be returned");
        assert.equal(result.isRegistered, false, "Should not register until minimum votes reached");
    });


    it('(airline) cannot repeatedly have vote counted for same airline', async () => {
        // ARRANGE
        let result = {};
        const airline5 = accounts[5];
        let reverted = false;

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(airline5, {from: config.firstAirline});
            await config.flightSuretyApp.registerAirline(airline5, {from: config.firstAirline});
            await config.flightSuretyApp.registerAirline(airline5, {from: config.firstAirline});
            result = await config.flightSuretyApp.getAirlineStatus(airline5);
        } catch (e) {
            reverted = true;
        }

        // ASSERT
        assert.equal(reverted, true, "A given airline can only raise one vote for a new airline");
    });


    it('(airline) cannot repeatedly have vote counted for same airline', async () => {
        // ARRANGE
        let result = {};
        const airline5 = accounts[5];
        let reverted = false;

        result = await config.flightSuretyApp.getAirlineStatus(airline5);
        const initialVote = result.votes.toNumber();

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(airline5, {from: config.firstAirline});
            await config.flightSuretyApp.registerAirline(airline5, {from: config.firstAirline});
            await config.flightSuretyApp.registerAirline(airline5, {from: config.firstAirline});
        } catch (e) {
            reverted = true;
        }

        result = await config.flightSuretyApp.getAirlineStatus(airline5);
        const endVote = result.votes.toNumber();

        // ASSERT
        assert.equal(reverted, true, "A given airline can only raise one vote for a new airline");
        assert.equal(initialVote, endVote, "Voting multiple times for a new airline should not change vote count");
    });


    it('(airline) can register a fifth airline if it has not yet voted (2 of 4 votes) ', async () => {
        // ARRANGE
        let result = {};
        const airline5 = accounts[5];
        const tenEth = web3.utils.toWei("10");

        // ACT
        try {
            // Fund airline 2..
            await config.flightSuretyApp.fund({from: accounts[2], value: tenEth});
            // ..before attempting to register another airline
            await config.flightSuretyApp.registerAirline(airline5, {from: accounts[2]});
            result = await config.flightSuretyApp.getAirlineStatus(airline5);
        } catch (e) {
            console.error("Ooops - unexpected error!", {e})
        }

        // ASSERT
        assert.equal(result.votes.toNumber(), 2, "Vote by a 2nd airline should be recognized as a 2nd vote");
        assert.equal(result.isRegistered, true, "2 of 4 consensus should result in registration");
    });


    /*
            it('(airline) CAN register an Airline using registerAirline() if it IS FUNDED', async () => {

                // ARRANGE
                let newAirline = accounts[2];
                const tenEth = web3.utils.toWei("79");
                await config.flightSuretyApp.fund({from: config.firstAirline, value: tenEth});

                // ACT
                try {
                    await config.flightSuretyApp.registerAirline(config.firstAirline, {from: config.firstAirline});
                } catch (e) {

                }
                let result = await config.flightSuretyData.isAirline.call(newAirline);

                // ASSERT
                assert.equal(result, true, "Airline should be able to register another airline if it has provided funding");

            });
        */

});
