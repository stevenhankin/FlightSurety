import React from "react";
// import Tab from "react-bootstrap/Tab";
import Row from "react-bootstrap/Row";
import Col from "react-bootstrap/es/Col";
import Badge from "react-bootstrap/Badge";
import {Accordion, Card} from "react-bootstrap";
// import Tabs from "react-bootstrap/Tabs";


const InfoTab = (props) => {

    console.log({props})
    const {isoperational, airlines, flights, passengers} = props;

    return (<div className="panel">
            <Row>
                <Col xs={1}>
                    Service
                </Col>
                <Col>
                    <Badge variant={isoperational ? "success" : "danger"}>
                        {isoperational ? "✔️ Operational" : "Unavailable"}
                    </Badge>
                </Col>
            </Row>

            <Row>
                <Col>
                    <Accordion defaultActiveKey="0">
                        <Card>
                            <Accordion.Toggle eventKey="0"><h4>Airlines</h4>
                                <Badge className="badge badge-primary info-badge">
                                    {airlines && airlines.length}
                                </Badge>
                            </Accordion.Toggle>
                            <Accordion.Collapse eventKey="0">
                                <Card>
                                    {
                                        airlines.map((airline, idx) =>
                                            <div key={airline.airlineAccount}>
                                                {airline.companyName}
                                                ({airline.airlineAccount
                                            && airline.airlineAccount.substring(0, 8)}...)
                                            </div>)
                                    }
                                </Card>
                            </Accordion.Collapse>
                        </Card>
                    </Accordion>
                </Col>

                <Col>
                    <Accordion defaultActiveKey="0">
                        <Card>
                            <Accordion.Toggle eventKey="0"><h4>Flights</h4>
                                <Badge className="badge badge-primary info-badge">
                                    {flights && flights.length}
                                </Badge>
                            </Accordion.Toggle>
                            <Accordion.Collapse eventKey="0">
                                <Card>
                                    {
                                        flights && flights.map((flight, idx) =>
                                            <div key={idx}>
                                                {flight.callSign} @ {new Date(flight.timestamp).toLocaleString()}
                                            </div>)
                                    }
                                </Card>
                            </Accordion.Collapse>
                        </Card>
                    </Accordion>
                </Col>

                <Col>
                    <Accordion defaultActiveKey="0">
                        <Card>
                            <Accordion.Toggle eventKey="0"><h4>Passengers</h4>
                                <Badge className="badge badge-primary info-badge">
                                    {passengers && passengers.length}
                                </Badge>
                            </Accordion.Toggle>
                            <Accordion.Collapse eventKey="0">
                                <Card>
                                    {
                                        passengers && passengers.map((passenger, idx) => <div
                                            key={idx}>{passenger.substring(0, 15)}...</div>)
                                    }
                                </Card>
                            </Accordion.Collapse>
                        </Card>
                    </Accordion>
                </Col>
            </Row>
        </div>)

};

export default InfoTab;
