import 'babel-polyfill';
import FlightSuretyApp from '../dapp/src/build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../dapp/src/build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import faker from 'faker';

const BigNumber = require('bignumber.js');
const TEN_ETHER = Web3.utils.toWei("10");

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
// var web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:7545'));
web3.eth.defaultAccount = web3.eth.accounts[0];


let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

// Account Index to choose accounts for each airline and oracle
let accIdx = 1;


const AIRLINES_COUNT = 3;
const ORACLES_COUNT = 25;

// Flights will keep a track of all scheduled
// flights for the WebApp for convenience
let flights = [];

// Store accounts of Oracles for responding to flight status requests
let oracles = [];


/////////////
// Airlines
/////////////
const registerAirlines = async () => {
    console.log('\nRegistering Airlines..\n');
    try {
        const accounts = await web3.eth.getAccounts();
        let totalRegistered = 0;
        let attempts = 0;
        // Contract will be created with an initial first airline
        let firstAirline = await flightSuretyApp
            .methods
            .getAirlineByIdx(0)
            .call({from: accounts[0], gas: "450000"});
        await flightSuretyApp
            .methods
            .fund()
            .send({from: firstAirline.airlineAccount, value: TEN_ETHER});
        console.log({firstAirline})
        while (accIdx <= accounts.length &&
        totalRegistered < AIRLINES_COUNT) {
            attempts++;
            const acc = accounts[accIdx];
            const companyName = faker.company.companyName();
            console.log(`${accIdx}: ${companyName} ${acc}`);
            try {
                // Register a new airline...
                await flightSuretyApp
                    .methods
                    .registerAirline(acc, companyName)
                    .send({from: firstAirline.airlineAccount, gas: "450000"});
                await flightSuretyApp
                    .methods
                    .fund()
                    .send({from: acc, value: TEN_ETHER});
                accIdx++;
                totalRegistered++;
            } catch (e) {
                console.log(e)
                process.abort();
            }
        }
        try {
            let total = await flightSuretyApp
                .methods
                .getAirlineCount()
                .call({from: accounts[0], gas: "450000"});
            console.log('\nAll Airlines registered!', {total});

        } catch (e) {
            console.log(e)
            process.abort();
        }
    } catch (e) {
        console.error('** ouch', e)
    }
};


/////////////
// Flights
/////////////
const registerFlights = async () => {

    console.log('\nRegistering Flights..\n');
    try {
        const accounts = await web3.eth.getAccounts();

        let airlineCount = await flightSuretyApp.methods.getAirlineCount().call({from: accounts[0]});
        // Add each registered and funded airline (created by server) to state
        for (let i = 0; i < airlineCount; i++) {
            let airline = await flightSuretyApp.methods.getAirlineByIdx(i).call({from: accounts[0]});
            for (let k = 0; k < 2; k++) {
                const callSign = `${airline.companyName.substring(0, 2).toUpperCase()}${i}0${k}`;
                const timestamp = Date.now() + Math.floor(Math.random() * 10000000);
                const flight = {callSign, timestamp};
                console.log({flight});
                // setFlights(flights => flights.concat({flight}));
                await flightSuretyApp.methods.registerFlight(callSign, timestamp).send({
                    from: airline.airlineAccount,
                    gas: "450000"
                });
                flights.push({...flight, airline: airline.airlineAccount});
            }
        }
        console.log({flights})
    } catch (e) {
        console.log(e)
        process.abort();
    }
};


/////////////
// Oracles
/////////////
const registerOracles = async () => {
    console.log('\nRegistering Oracles..\n');
    try {
        const accounts = await web3.eth.getAccounts();
        let totalRegistered = 0;
        let fee = BigNumber(await flightSuretyApp.methods.getRegistrationFee().call()).toString();
        let attempts = 0;
        while (accIdx <= accounts.length &&
        totalRegistered <= ORACLES_COUNT) {
            attempts++;
            const acc = accounts[accIdx];
            console.log(`${accIdx}: ${acc}`);
            try {
                await flightSuretyApp
                    .methods
                    .registerOracle()
                    .send({from: acc, value: fee, gas: "450000"});
                oracles.push(acc);
                accIdx++;
                totalRegistered++;
            } catch (e) {
                console.log('failed on this attempt..not enough blocks in chain yet?')
                process.abort()
            }
        }
        console.log('\nAll Oracles registered!');
    } catch (e) {
        console.error('** ouch', e)
    }
};

// Oracle submits a response
const submitResponse = async (oracle, index,airline,flight,timestamp) => {
    // Produces a random status code of either  20, 30, or 40
    let statusCode = 10+(Math.floor(Math.random()*3)*10);
    try {
        console.log('Submitting...')
        await flightSuretyApp.methods.submitOracleResponse(index,airline,flight,timestamp, statusCode).send({ from: oracle, gas:"450000" });
        console.log(`${oracle} submitted code ${statusCode}`)
    } catch (e) {
        console.log(`Rejected Oracle ${oracle}`)
    }
};


/////////////
// If an OracleRequest is detected, make all Oracles attempt to service it
/////////////
const listenForRequests = async () => {
    // Listen for events
    flightSuretyData.events.OracleRequest({
        fromBlock: 0
    }, function (error, event) {
        if (error) {
            console.log(error);
        } else {
            console.log('Event!!!');
            console.log(event.returnValues);

            const {index,airline,flight,timestamp} = event.returnValues;

            for (let i = 0; i < oracles.length; i++) {
                console.log(oracles[i]);
                submitResponse(oracles[i], index,airline,flight,timestamp);
            }
        }

    });

    flightSuretyData.events.FlightStatusInfo({
        fromBlock: 0
    }, function (error, event) {
        if (error) {
            console.log(error);
        } else {
            console.log('Status determined:',event.returnValues.status);
            // console.log(event.returnValues);
        }

    });

};


registerAirlines()
    .then(registerFlights)
    .then(registerOracles)
    .then(listenForRequests);


// Simple API to let client know what flights were setup
const app = express();
app.get('/api/flights', (req, res) => {
    res.json(flights);
});


export default app;

