import 'babel-polyfill';
import FlightSuretyApp from '../dapp/src/build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../dapp/src/build/contracts/FlightSuretyData.json';
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
        let a = 1;
        let attempts = 0;
        while (a <= accounts.length &&
        totalRegistered <= ORACLES_COUNT) {

            attempts ++;

            const acc=accounts[a];
            console.log(`${a}: ${acc}`);

            try {

                let result = await flightSuretyApp
                    .methods
                    .registerOracle()
                    .send({from: accounts[0], value: fee, gas: "450000"});

                a++;
                totalRegistered++;
                console.log(`${totalRegistered} after ${attempts} attempts`, acc)

            }
            catch (e) {
                console.log('failed on this attempt..not enough blocks in chain yet?')
            }
            // ((a,acc) => (
            // flightSuretyApp
            //     .methods
            //     .registerOracle()
            //     .send({from: acc, value: fee, gas:"450000"}, (error, result) => {
            //         console.log({result})
            //         if (error) {
            //             console.error('ERROR',error);
            //             console.log('\n** Unstable! Please restart as follows;   truffle migrate --reset  &&  npm run server');
            //             process.exit(1);
            //         } else {
            //             totalRegistered++;
            //             if (totalRegistered == ORACLES_COUNT) {
            //                 console.log('\nAll Oracles registered successfully!');
            //             } else {
            //                 console.log(`Registered Oracle ${a} (${totalRegistered} so far)`,acc)
            //             }
            //         }
            //     })
            // ))(a,acc);
        }
    } catch (e) {
        console.error('** ouch',e)
    }

})();


// Listen for events
flightSuretyData.events.OracleRequest({
    fromBlock: 0
}, function (error, event) {

    if (error) console.log(error);
    console.log('Event!',event);
    console.log(event.returnValues);
});


const app = express();
app.get('/api', (req, res) => {
    res.send({
        message: 'An API for use with your Dapp!'
    })
});


export default app;
