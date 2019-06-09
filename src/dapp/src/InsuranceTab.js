import React from "react";
import Row from "react-bootstrap/Row";
import Col from "react-bootstrap/es/Col";
import Tab from "react-bootstrap/Tab";


const InsuranceTab = (props) => {

    const {passengers, flights} = props;

    const buyInsurance = () => {
      alert('hi')
    };

    return <Row>
        <Col>
            <div className="panel">
                <div className="input-group mb-3">
                    <div className="input-group-prepend">
                        <label className="input-group-text">Passenger</label>
                    </div>
                    <select className="custom-select">
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
                    <select className="custom-select">
                        <option>Choose flight...</option>
                        {
                            flights && flights.map((flight, idx) =>
                                <option
                                    value={idx}>{flight.callSign} @ {new Date(flight.timestamp).toLocaleString()}</option>
                            )
                        }
                    </select>
                </div>

                <div className="input-group mb-3">
                    <div className="input-group-prepend">
                        <span className="input-group-text">Pay Ξ</span>
                    </div>
                    <input type="text" className="form-control"
                           aria-label="Amount (to the nearest dollar)"
                           value="0"
                    />
                </div>

                <button type="button" className="btn btn-primary" onClick={buyInsurance}>Buy
                    Insurance!
                </button>
            </div>
        </Col>
    </Row>


};

export default InsuranceTab;
