import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

var BigNumber = require('bignumber.js');

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];


let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);


const ORACLES_COUNT = 35;

let totalRegistered=0;

// Register Oracles
(async () => {
    try {
        const accounts = await web3.eth.getAccounts();
        let fee = BigNumber(await flightSuretyApp.methods.getRegistrationFee().call()).toString();
        for (let a = 1; a <= ORACLES_COUNT; a++) {
            const acc=accounts[a];
            flightSuretyApp
                .methods
                .registerOracle()
                .send({from: accounts[a], value: fee, gas:"450000"}, (error, result) => {
                    if (error) {
                        console.error('ERROR',error)
                    } else {
                        totalRegistered++;
                        console.log(`Registered Oracle ${a} (${totalRegistered} so far)`,acc)
                    }
                });
        }
    } catch (e) {
        console.error(e)
    }

})();


// Listen for events
flightSuretyData.events.OracleRequest({
    fromBlock: 0
}, function (error, event) {

    if (error) console.log(error)
    console.log('Event!',event)
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
        message: 'An API for use with your Dapp!'
    })
});

export default app;
