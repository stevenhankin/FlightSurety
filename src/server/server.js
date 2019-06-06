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

const ORACLES_COUNT = 35;

let totalRegistered = 0;

console.log('\nRegistering Oracles..\n');
// Register Oracles

const registerOracles = async () => {
    try {
        const accounts = await web3.eth.getAccounts();
        let fee = BigNumber(await flightSuretyApp.methods.getRegistrationFee().call()).toString();
        let a = 1;
        let attempts = 0;
        while (a <= accounts.length &&
        totalRegistered <= ORACLES_COUNT) {
            attempts++;
            const acc = accounts[a];
            console.log(`${a}: ${acc}`);
            try {
                await flightSuretyApp
                    .methods
                    .registerOracle()
                    .send({from: accounts[0], value: fee, gas: "450000"});
                a++;
                totalRegistered++;
            } catch (e) {
                console.log('failed on this attempt..not enough blocks in chain yet?')
            }
        }
        console.log('\n\nAll Oracles registered!');
    } catch (e) {
        console.error('** ouch', e)
    }
};

registerOracles().then(
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
