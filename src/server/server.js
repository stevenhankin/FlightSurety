import 'babel-polyfill';
import FlightSuretyApp from '../dapp/src/build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../dapp/src/build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

const BigNumber = require('bignumber.js');

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];


let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

// Account Index to choose accounts for each airline and oracle
let accIdx = 1;


const AIRLINES_COUNT = 4;
const ORACLES_COUNT = 25;


/////////////
// Airlines
/////////////
const registerAirlines = async () => {
    console.log('\nRegistering Airlines..\n');
    try {
        const accounts = await web3.eth.getAccounts();
        let totalRegistered = 0;
        let attempts = 0;
        while (accIdx <= accounts.length &&
        totalRegistered <= AIRLINES_COUNT) {
            attempts++;
            const acc = accounts[accIdx];
            console.log(`${accIdx}: ${acc}`);
            try {
                await flightSuretyApp
                    .methods
                    .registerAirline
                    .call(acc, {from: accounts[0], gas: "450000"});
                accIdx++;
                totalRegistered++;
            } catch (e) {
                console.log(e)
                process.abort();
            }
        }
        console.log('\nAll Airlines registered!');
    } catch (e) {
        console.error('** ouch', e)
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

registerAirlines()
// registerOracles()
//     .then(registerAirlines)
    .then(registerOracles)
    .then(
    // Listen for events
    flightSuretyData.events.OracleRequest({
        fromBlock: 0
    }, function (error, event) {

        if (error) console.log(error);
        console.log('Event!', event);
        console.log(event.returnValues);
    })
);

const app = express();
app.get('/api', (req, res) => {
    res.send({
        message: 'An API for use with your Dapp!'
    })
});


export default app;
