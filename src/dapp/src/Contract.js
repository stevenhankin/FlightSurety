import React, {useState, useEffect} from 'react';

import Tabs from 'react-bootstrap/Tabs';
import Tab from 'react-bootstrap/Tab';

import FlightSuretyApp from './build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import Container from "react-bootstrap/es/Container";
import Row from "react-bootstrap/Row";
// import Badge from "react-bootstrap/Badge";
import Col from "react-bootstrap/es/Col";
// import {Accordion, AccordionCollapse, AccordionToggle, Card} from "react-bootstrap";
import InfoTab from "./InfoTab"
import InsuranceTab from "./InsuranceTab";

const axiosJS = require('axios');

// import {connect} from "react-redux";
// import {addFlight} from "./actions";


const NETWORK = 'localhost'; // hardcoded for now
const config = Config[NETWORK];
const web3 = (new Web3(new Web3.providers.HttpProvider(config.url)));
const TEN_ETH = web3.utils.toWei("10");
const flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);


const Contract = (props) => {

    const [owner, setOwner] = useState("");
    const [airlines, setAirlines] = useState([]);
    const [flights, setFlights] = useState([]);
    const [passengers, setPassengers] = useState([]);
    const [isOperational, setIsOperational] = useState(false);


    const axios = axiosJS.create({
        baseURL: '/api/',
        timeout: 1000
    });


    const getAirlines = async () => {
        try {
            let airlineCount = await flightSuretyApp.methods.getAirlineCount().call({from: owner});
            console.log({airlineCount});
            // Add each registered and funded airline (created by server) to state
            for (let i = 0; i < airlineCount; i++) {
                let airline = await flightSuretyApp.methods.getAirlineByIdx(i).call({from: owner});
                setAirlines(a => a.concat({
                    airlineAccount: airline.airlineAccount,
                    companyName: airline.companyName
                }));
            }
        } catch (e) {
            console.error({e});
        }
    };


    const getFlights = async () => {
        try {
            const {data} = await axios.get('/flights');
            setFlights(data);
            console.log({data});
        } catch (e) {
            console.error({e});
        }
    };


    const getPassengers = (accts) => {
        return () => {
            const offset = 10;
            let counter = 1;
            while (counter < 5) {
                setPassengers((p) => p.concat(accts[offset + counter++]));
            }
        }
    };

    const buyInsurance = () => {
        alert('buy!')
    };

    // On startup, initialise
    useEffect(() => {
        console.log({config}, {web3});
        console.log("initialize", {owner});

        web3.eth.getAccounts((error, accts) => {
            console.log('Got accounts!', {accts}, {error})
            if (error) {
                alert(error)
            } else {

                setOwner(accts[0]);

                getAirlines().then(getFlights).then(getPassengers(accts));

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

    console.log({airlines})

    // const {flights} = props;

    return (
        <React.Fragment>
            <Container>
                <Row>
                    <Col>
                        <Tabs defaultActiveKey="info" id="uncontrolled-tab-example">

                            <Tab eventKey="info" title="Info">
                                <InfoTab isoperational={isOperational.toString()} airlines={airlines} flights={flights}
                                         passengers={passengers}/>
                            </Tab>

                            <Tab eventKey="profile" title="Book Insurance">
                                <InsuranceTab  flights={flights}
                                               passengers={passengers} />
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

export default Contract;
