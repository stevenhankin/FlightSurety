import React, {useState} from "react";
import Row from "react-bootstrap/Row";
import Col from "react-bootstrap/es/Col";
import Web3 from 'web3';


const InsuranceTab = (props) => {

    const {flightsuretyapp, passengers, flights} = props;

    const [passenger, setPassenger] = useState("");
    const [flight, setFlight] = useState("");
    const [amount, setAmount] = useState("");

    console.log({passenger}, {flight}, {amount})


    const buyInsurance = () => {
        const _flight = JSON.parse(flight);
        console.log({amount, _flight})
        const weiValue = Web3.utils.toWei(amount, 'ether');
        flightsuretyapp.methods
            .buy(_flight.airline, _flight.callSign, _flight.timestamp)
            .send({from: passenger, value: weiValue, gas: "450000"}, (err, result) => {
                if (err) {
                    console.error(err)
                } else {
                    alert('hi')
                    // setIsOperational(result);
                    // console.log('isOperational: ', {err, result});
                }
            });
    };


    return <Row>
        <Col>
            <div className="panel">
                <div className="input-group mb-3">
                    <div className="input-group-prepend">
                        <label className="input-group-text">Passenger</label>
                    </div>
                    <select className="custom-select" onChange={(e) => setPassenger(e.target.value)}>
                        <option>Choose account...</option>
                        {
                            passengers && passengers.map((passenger, idx) =>
                                <option value={passenger}>{passenger}</option>
                            )
                        }
                    </select>
                </div>

                <div className="input-group mb-3">
                    <div className="input-group-prepend">
                        <label className="input-group-text">Flight</label>
                    </div>
                    <select className="custom-select" onChange={(e) => setFlight(e.target.value)}>
                        <option>Choose flight...</option>
                        {
                            flights && flights.map((flight, idx) =>
                                <option
                                    value={JSON.stringify(flight)}>{flight.callSign} @ {new Date(flight.timestamp).toLocaleString()}</option>
                            )
                        }
                    </select>
                </div>

                <div className="input-group mb-3">
                    <div className="input-group-prepend">
                        <span className="input-group-text">Pay Ξ</span>
                    </div>
                    <input type="text" className="form-control"
                           aria-label="Amount (in Ether)"
                           value={amount} onChange={(e) => setAmount(e.target.value)}
                           placeholder="Amount (in Ether)"
                    />
                </div>

                <button type="button" className="btn btn-primary" onClick={buyInsurance}
                        disabled={!passenger || !flight || !amount || parseFloat(amount) <= 0}>Buy
                    Insurance!
                </button>
            </div>
        </Col>
    </Row>
};


export default InsuranceTab;
