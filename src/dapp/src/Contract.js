import React, {useState, useEffect} from 'react';

import Tabs from 'react-bootstrap/Tabs';
import Tab from 'react-bootstrap/Tab';

import FlightSuretyApp from './build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import Container from "react-bootstrap/es/Container";
import Row from "react-bootstrap/Row";
import Badge from "react-bootstrap/Badge";
import Col from "react-bootstrap/es/Col";

import {connect} from "react-redux";
import {addFlight} from "./actions";


/*
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

 */


const Contract = (props) => {

    console.log("PROPS",{props});


    const NETWORK = 'localhost'; // hardcoded for now
    const [owner, setOwner] = useState("");
    const [airlines, setAirlines] = useState([]);
    const [passengers, setPassengers] = useState([]);
    const [isOperational, setIsOperational] = useState(false);


    useEffect(() => {
        let config = Config[NETWORK];
        const web3 = (new Web3(new Web3.providers.HttpProvider(config.url)));
        console.log({config}, {web3});
        const flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

        console.log("initialize", {owner});

        web3.eth.getAccounts((error, accts) => {

            console.log('Got accounts!', {accts}, {error})

            if (error) {
                alert(error)
            } else {
                console.log('HERE');

                setOwner(accts[0]);

                let counter = 1;
                const TEN_ETH = web3.utils.toWei("10");

                let _airlines = [];
                let idx = 1;
                while (_airlines.length < 5) {
                    const account = accts[counter++];
                    _airlines.push(account);
                    // Associate 2 flights with airline
                    const fund = flightSuretyApp.methods.fund();
                    console.log('before fund', {fund});
                    const resp = fund.send({from: account, value: TEN_ETH},
                        (err, resp) => {
                            if (err) {
                                console.log(err);
                            } else {
                                const callSign = `Flight${idx++}`;
                                const timestamp = Date.now() + Math.floor(Math.random() * 10000000);
                                const flight = {callSign, timestamp};
                                console.log(addFlight);
                                addFlight(flight);
                                flightSuretyApp.methods.registerFlight(callSign, timestamp);

                            }
                        }
                    );
                    console.log('after fund')
                }
                setAirlines(_airlines);

                while (passengers.length < 5) {
                    passengers.push(accts[counter++]);
                }

                flightSuretyApp.methods
                    .isOperational()
                    .call({from: owner}, (err, result) => {
                        if (err) {
                            console.error(err)
                        } else {
                            setIsOperational(result);
                            console.log('isOperational: ', {err, result});
                        }
                    });
            }
        });
    }, []);


    console.log({props})
    const {flights} = props;

    return (
        <React.Fragment>
            <Container>
                <Row>
                    <Col>
                        <Tabs defaultActiveKey="info" id="uncontrolled-tab-example">
                            <Tab eventKey="info" title="Info">
                                <h2>Accounts</h2>
                                <h4>Owner</h4>
                                <div>{owner}</div>
                                <div>
                                    Service:
                                    <Badge variant={isOperational ? "primary" : "danger"}>
                                        {isOperational ? "Operational" : "Unavailable"}
                                    </Badge>
                                </div>
                                <h4>Airlines</h4>
                                <div>
                                    {
                                        airlines.map((airline, idx) => <div
                                            key={airline}>Airline {idx}: {airline}</div>)
                                    }
                                </div>
                                <h4>Flights</h4>
                                <div>
                                    {
                                        flights && flights.map((flight, idx) => <div
                                            key={idx}>flight {idx}: {flight.callSign} @ {new Date(flight.timestamp).toLocaleString()}</div>)
                                    }
                                </div>
                                <div>Number of flights: {flights && flights.length}
                                </div>
                            </Tab>
                            <Tab eventKey="profile" title="Book Insurance">
                                <div></div>
                            </Tab>
                            <Tab eventKey="contact" title="Flight Status" disabled>
                                <div></div>
                            </Tab>
                        </Tabs>
                    </Col>
                </Row>
            </Container>
        </React.Fragment>
    )
};

const mapStateToProps = state => ({flights:state.flights});

export default connect(mapStateToProps)(Contract);
