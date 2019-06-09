const Test = require('../config/testConfig.js');
const faker = require('faker');

// Arbitrary constants for testing
const FLIGHT_NAME = "BA101";
const FLIGHT_TIMESTAMP = parseInt(Date.now() + 100000 + Math.random() * 100000, 10);
const ONE_ETHER = web3.utils.toWei("1");
const THREE_ETHER = web3.utils.toWei("3");
const NINE_ETHER = web3.utils.toWei("9");
const TEN_ETHER = web3.utils.toWei("10");


contract('Flight Surety Tests', async (accounts) => {

    const passenger = accounts[8];
    const airline5 = accounts[5];
    const oracle = accounts[9];


    let config;

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

    it(`(Airline Contract Initialization) App contract is linked to the data contract`, async function () {
        const dataAddr = await config.flightSuretyApp.getDataContractAddress();
        assert.equal(dataAddr, config.flightSuretyData.address, 'App should be linked to correct data contract');
    });


    it(`(Airline Contract Initialization) First airline is registered when contract is deployed`, async function () {
        const num = await config.flightSuretyApp.getAirlineCount();
        const result = await config.flightSuretyApp.getAirlineStatus(config.firstAirline);
        assert.equal(num.toNumber(), 1, 'Exactly one airline should be registered');
        assert.equal(result.isRegistered, true, 'The first airline is registered');
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
            await config.flightSuretyApp.registerAirline(newAirline, faker.company.companyName(),  {from: config.firstAirline});
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
        let reverted = false;
        // ACT
        try {
            await config.flightSuretyApp.registerAirline(newAirline, faker.company.companyName(), {from: config.firstAirline});
        } catch (e) {
            reverted = true;
        }
        let result = await config.flightSuretyData.isAirline.call(newAirline);

        // ASSERT
        assert.equal(reverted, true, "Transaction should revert if unfunded airline attempts a registration");
        assert.equal(result, false, "Airline should not be registered by another airline that is unfunded");
    });


    // it('(airline) list of Airlines can be retrieved', async () => {
    //
    //     // ARRANGE
    //     // let newAirline = accounts[2];
    //     let reverted = false;
    //
    //     // ACT
    //     try {
    //         let airlines = await config.flightSuretyApp.getAirlines({from: config.firstAirline,gas: 100000});
    //         console.log({airlines});
    //     } catch (e) {
    //         reverted = true;
    //         console.error({e})
    //     }
    //
    //     // ASSERT
    //     assert.equal(reverted, true, "Call should not fail to retrieve airlines");
    // });

    it('(airline) cannot be funded below MINIMUM FUND requirements', async () => {
        // ARRANGE
        let reverted = false;
        // ACT
        try {
            await config.flightSuretyApp.fund({from: config.firstAirline, value: NINE_ETHER});
        } catch (e) {
            reverted = true;
        }
        let result = await config.flightSuretyData.isFundedAirline.call(config.firstAirline);
        // ASSERT
        assert.equal(reverted, true, "Transaction should revert if fund request is below requirement");
        assert.equal(result, false, "Airline should not be funded if it is unable to meet the minimum funding requirements");
    });

    it('(airline) can be FUNDED if funding requirements are met', async () => {
        // ARRANGE

        // ACT
        try {
            await config.flightSuretyApp.fund({from: config.firstAirline, value: TEN_ETHER});
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
        let reverted = false;
        // ACT
        try {
            await config.flightSuretyApp.fund({from: config.firstAirline, value: TEN_ETHER});
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
            await config.flightSuretyApp.registerAirline(airline2, faker.company.companyName(), {from: config.firstAirline, gas: 200000});
        } catch (e) {
            console.error("Ooops - unexpected error!", {e})
        }
        let result = await config.flightSuretyData.isAirline.call(airline2);
        // ASSERT
        assert.equal(result, true, "When first airline is funded it should be able to register another airline");
    });


    it('(Multiparty Consensus, <=4 airlines) once funded can register two more airlines', async () => {
        // ARRANGE
        // NOTE: Airline 1 is already funded from previous step
        const airline3 = accounts[3];
        const airline4 = accounts[4];
        // ACT
        try {
            await config.flightSuretyApp.registerAirline(airline3, faker.company.companyName(), {from: config.firstAirline, gas: 200000});
            await config.flightSuretyApp.registerAirline(airline4, faker.company.companyName(), {from: config.firstAirline, gas: 200000});
        } catch (e) {
            console.error("Ooops - unexpected error!", {e})
        }
        let resultB = await config.flightSuretyData.isAirline.call(airline3);
        let resultC = await config.flightSuretyData.isAirline.call(airline4);
        // ASSERT
        assert.equal(resultB, true, "When first airline is funded it should be able to register a second airline");
        assert.equal(resultC, true, "When first airline is funded it should be able to register a third airline");
    });


    it('(4 airlines) contract should be aware of total number of airlines', async () => {
        // ACT
        let totalAirlines = await config.flightSuretyData.getAirlineCount.call();
        //ASSERT
        assert.equal(totalAirlines, 4, "Contract should keep track of total number of airlines");
    });


    it('(Multiparty Consensus, >4 airlines) can request to register fifth airline, but will not initially succeed (minimum votes required)', async () => {
        // ARRANGE
        let result = {};
        const num = await config.flightSuretyApp.registeredAirlinesCount();
        assert.equal(num.toNumber(), 4, 'At this point there should be 4 registered airlines (from previous steps)');
        // ACT
        try {
            await config.flightSuretyApp.registerAirline(airline5, faker.company.companyName(), {from: config.firstAirline, gas: 200000});
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

        let reverted = false;
        // ACT
        try {
            await config.flightSuretyApp.registerAirline(airline5, faker.company.companyName(), {from: config.firstAirline, gas: 200000});
            await config.flightSuretyApp.registerAirline(airline5, faker.company.companyName(), {from: config.firstAirline, gas: 200000});
            await config.flightSuretyApp.registerAirline(airline5, faker.company.companyName(), {from: config.firstAirline, gas: 200000});
            result = await config.flightSuretyApp.getAirlineStatus(airline5);
        } catch (e) {
            reverted = true;
        }
        // ASSERT
        assert.equal(reverted, true, "A given airline can only raise one vote for a new airline");
    });


    it('(airline) cannot repeatedly have vote counted for same airline', async () => {
        // ARRANGE

        let reverted = false;
        let result = await config.flightSuretyApp.getAirlineStatus(airline5);
        const initialVote = result.votes.toNumber();

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(airline5, faker.company.companyName(), {from: config.firstAirline, gas: 200000});
            await config.flightSuretyApp.registerAirline(airline5, faker.company.companyName(), {from: config.firstAirline, gas: 200000});
            await config.flightSuretyApp.registerAirline(airline5, faker.company.companyName(), {from: config.firstAirline, gas: 200000});
        } catch (e) {
            reverted = true;
        }

        result = await config.flightSuretyApp.getAirlineStatus(airline5);
        const endVote = result.votes.toNumber();

        // ASSERT
        assert.equal(reverted, true, "A given airline can only raise one vote for a new airline");
        assert.equal(initialVote, endVote, "Voting multiple times for a new airline should not change vote count");
    });


    it('(Multiparty Consensus) can register a fifth airline if it has not yet voted (2 of 4 votes) ', async () => {
        // ARRANGE
        let result = {};


        // ACT
        try {
            // Fund airline 2..
            await config.flightSuretyApp.fund({from: accounts[2], value: TEN_ETHER});
            // ..before attempting to register another airline
            await config.flightSuretyApp.registerAirline(airline5, faker.company.companyName(), {from: accounts[2], gas: 200000});
            result = await config.flightSuretyApp.getAirlineStatus(airline5);
        } catch (e) {
            console.error("Ooops - unexpected error!", {e})
        }

        // ASSERT
        assert.equal(result.votes.toNumber(), 2, "Vote by a 2nd airline should be recognized as a 2nd vote");
        assert.equal(result.isRegistered, true, "2 of 4 consensus should result in registration");
    });


    it('(Airline Ante) fifth airline (registered) cannot participate when unfunded ', async () => {
        // ARRANGE

        const airline6 = accounts[6];
        let reverted = false;

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(airline6, faker.company.companyName(), {from: airline5, gas: 200000});
        } catch (e) {
            reverted = true;
        }

        // ASSERT
        assert.equal(reverted, true, "A registered airplane cannot participate when unfunded");
    });


    it('(Airline Ante) fifth airline (registered, funded) can participate once funded ', async () => {
        // ARRANGE
        const airline6 = accounts[6];
        let reverted = false;

        // ACT
        try {
            // Fund airline 5 so that it can participate..
            await config.flightSuretyApp.fund({from: airline5, value: TEN_ETHER});
            await config.flightSuretyApp.registerAirline(airline6,faker.company.companyName(), {from: airline5, gas: 200000});
        } catch (e) {
            reverted = true;
            console.error("Ooops - unexpected error!", {e})
        }

        // ASSERT
        assert.equal(reverted, false, "A registered airplane can participate once funded");
    });


    it('(Flight) a funded airline can add a flight schedule ', async () => {
        // ARRANGE
        let reverted = false;

        // ACT
        try {
            await config.flightSuretyApp.registerFlight(FLIGHT_NAME, FLIGHT_TIMESTAMP, {from: airline5});
        } catch (e) {
            reverted = true;
            console.error("Ooops - unexpected error!", {e})
        }

        // ASSERT
        assert.equal(reverted, false, "A funded airplane should be able to add flights");
    });


    it('(Passenger Payment) can pay up to 1 ether for purchasing flight insurance', async () => {
        // ARRANGE
        let reverted = false;

        // ACT
        try {
            await config.flightSuretyApp.buy(airline5, FLIGHT_NAME, FLIGHT_TIMESTAMP, {
                from: passenger,
                value: THREE_ETHER
            });
        } catch (e) {
            reverted = true;
            console.error("Ooops - unexpected error!", {e})
        }

        // ASSERT
        assert.equal(reverted, false, "A passenger should be able to buy insurance");
    });


    it('(Passenger Repayment) passenger receives credit of 1.5X the amount they paid when delay due to airline', async () => {
        // ARRANGE
        let reverted = false;
        let totalCredit = 0;
        // Set status to Delayed to trigger credit
        const STATUS_CODE_LATE_AIRLINE = 20;
        await config.flightSuretyApp.processFlightStatus(airline5, FLIGHT_NAME, FLIGHT_TIMESTAMP, STATUS_CODE_LATE_AIRLINE, 1, 2, STATUS_CODE_LATE_AIRLINE,{from: config.owner});
        // ACT
        try {
            // "passenger was insured in a previous test case"
            const result = await config.flightSuretyData.getCredit(passenger, {from: config.owner});
            totalCredit = web3.utils.fromWei(result, 'ether');
        } catch (e) {
            reverted = true;
            console.error("Ooops - unexpected error!", {e})
        }

        // ASSERT
        assert.equal(reverted, false, "A passenger should be credited if an airline causes a delay");
        assert.equal(totalCredit, 1.5, "Passenger should receive 1.5 Ether for a 1 Ether insurance");
    });


    it('(Passenger Withdraw) receive funds owed as a result of receiving credit for insurance payout', async () => {
        // ARRANGE
        let reverted = false;
        let totalCreditEth;
        const before = web3.utils.fromWei(await web3.eth.getBalance(passenger), 'ether');
        ;

        // ACT
        try {
            // "passenger was Credited in a previous test case"
            await config.flightSuretyApp.pay({from: passenger});
            const after = web3.utils.fromWei(await web3.eth.getBalance(passenger), 'ether');
            ;
            totalCreditEth = after - before;
        } catch (e) {
            reverted = true;
            console.error("Ooops - unexpected error!", {e})
        }

        // ASSERT
        assert.equal(reverted, false, "A passenger should be credited if an airline causes a delay");
        assert.isBelow(1.5 - totalCreditEth, 0.01, "Passenger should receive almost 1.5 Ether for a 1 Ether insurance (minus gas costs)");
    });


});
