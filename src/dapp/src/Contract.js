import React, {useEffect, useState} from 'react';

import Tabs from 'react-bootstrap/Tabs';
import Tab from 'react-bootstrap/Tab';

import FlightSuretyApp from './build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import Container from "react-bootstrap/es/Container";
import Row from "react-bootstrap/Row";
import Col from "react-bootstrap/es/Col";
import InfoTab from "./InfoTab"
import InsuranceTab from "./InsuranceTab";

const axiosJS = require('axios');

const NETWORK = 'localhost'; // hardcoded for now
const config = Config[NETWORK];
const web3 = (new Web3(new Web3.providers.HttpProvider(config.url)));
const flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);


const Contract = (props) => {

    const [owner, setOwner] = useState("");
    const [airlines, setAirlines] = useState([]);
    const [flights, setFlights] = useState([]);
    const [passengers, setPassengers] = useState([]);
    const [isOperational, setIsOperational] = useState(false);




    // On startup, initialise
    useEffect(() => {

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
            const passengerConcat = (accts, offset, counter) => (p) => p.concat(accts[offset + counter]);
            return () => {
                const offset = 10;
                let counter = 1;
                while (counter < 5) {
                    setPassengers(passengerConcat(accts, offset, counter++));
                }
            }
        };


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
    }, [owner]);

    console.log({airlines})

    // const {flights} = props;

    return (
        < React.Fragment >
        < Container >
        < Row >
        < Col >
        < Tabs
    defaultActiveKey = "info"
    id = "uncontrolled-tab-example" >

        < Tab
    eventKey = "info"
    title = "Info" >
        < InfoTab
    isoperational = {isOperational.toString()}
    airlines = {airlines}
    flights = {flights}
    passengers = {passengers}
    />
    < /Tab>

    < Tab
    eventKey = "profile"
    title = "Insurance" >
        < InsuranceTab
    flightsuretyapp = {flightSuretyApp}
    flights = {flights}
    passengers = {passengers}
    />
    < /Tab>
    < /Tabs>
    < /Col>
    < /Row>
    < /Container>
    < /React.Fragment>
)
};

export default Contract;
