import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {

    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {

        console.log("initialize")

        this.web3.eth.getAccounts((error, accts) => {

            console.log({accts})

            this.owner = accts[0];

            let counter = 1;
            const TEN_ETH = this.web3.utils.toWei("10");


            while (this.airlines.length < 5) {
                const account = accts[counter++];
                console.log({account})
                this.airlines.push(account);

                // Associate 2 flights with airline
                this.flightSuretyApp.methods.fund().send({from: account, value: TEN_ETH})
                    .then(() => {
                        this.flightSuretyApp.methods.registerFlight('moomoomoo', Date.now()).send({from: account});

                    })
            }

            while (this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }


            // Generate some test flights
            const flights = [];


            callback();
        });
    }

    isOperational(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .isOperational()
            .call({from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        }
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }
}