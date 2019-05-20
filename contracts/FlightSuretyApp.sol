pragma solidity ^0.5.8;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    FlightSuretyData  flightSuretyData; // App links to the Data Contract

    uint256 private constant JOIN_FEE = 10 ether; // Fee for an airline to join


    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
        // Delegates to data contract's status
        require(flightSuretyData.isOperational(), "Contract is currently not operational");
        _;
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier requires the Airline that is calling is already funded
    */
    modifier requireIsFundedAirline(address airline)
    {
        require(flightSuretyData.isFundedAirline(airline), "Airline is not funded");
        _;
    }

    /**
    * @dev Modifier prevent double-funding of airline
    */
    modifier requireIsNotFundedAirline(address airline)
    {
        require(flightSuretyData.isFundedAirline(airline) == false, "Airline is already funded - should not fund twice");
        _;
    }



    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor.  First airline is registered when contract deployed
    *
    */
    constructor
    (address dataContractAddress)
    public
    {
        require(dataContractAddress != address(0), 'Must supply the data contract associated with the app');
        contractOwner = msg.sender;
        // Link to the deployed data contract
        // and get address for payments to it
        flightSuretyData = FlightSuretyData(dataContractAddress);
        //        flightSuretyDataAddress = address(uint160(address(flightSuretyData)));
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
    public
    view
    returns (bool)
    {
        // Delegates to data contract's status
        return flightSuretyData.isOperational();
    }

    function isFundedAirline(address airline)
    public
    view
    returns (bool)
    {
        return flightSuretyData.isFundedAirline(airline);
    }

    function getDataContractAddress()
    public
    view
    returns (address)
    {
        return address(flightSuretyData);
    }

    function getContractOwner()
    public
    view
    returns (address)
    {
        return address(contractOwner);
    }




    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function getAirlineStatus(address airline)
    public
    view
    returns (bool isRegistered,
        bool isFunded,
        uint256 votes)
    {
        return flightSuretyData.getAirlineStatus(airline);
    }


    /***
     * @dev Return number of airlines registered so far
     *
     */
    function registeredAirlinesCount()
    public
    view
    returns (uint256) {
        return flightSuretyData.registeredAirlinesCount();
    }

    /**
     * @dev Add an airline to the registration queue
     *
     * First 4 airlines can be registered by a single funded airline
     * 5th and more airlines require M-of-N consensus of 50% or more to register
     * (i.e. the same airline must be registered by 50% of existing airlines to take effect)
     *
     */
    function registerAirline
    (address airline
    )
    external
    requireIsOperational
    requireIsFundedAirline(msg.sender) // the SENDER needs to be a funded airline
    {
        // Only called once for a given airline for first 4
        flightSuretyData.registerAirline(airline, msg.sender);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund()
    external payable
    requireIsOperational
    requireIsNotFundedAirline(msg.sender) // Must be not funded otherwise will be overpaying with multiple funds
    {
        require(msg.value >= JOIN_FEE, "Funding payment too low");
        require(address(contractOwner) != address(0), "Contract owner is not set");
        // SafeMath : determine any excess to return
        uint256 amountToReturn = msg.value.sub(JOIN_FEE);
        // transfer payment on to data contract and flag as funded
        flightSuretyData.fund.value(JOIN_FEE)(msg.sender);
        // ..before crediting any overspend
        msg.sender.transfer(amountToReturn);
    }


    ////////////////////////////////////////////////////////////////
    // Passenger functions
    ////////////////////////////////////////////////////////////////

    // Passenger buys insurance for a flight
    // Overpayment will result in a return
    function buy(
        address _airline,
        string calldata _flight,
        uint256 _timestamp)
    external
    payable
    {
        require(msg.value >= 0, "Payment must be greater than 0");
        // Max payment is capped at 1 Ether
        uint256 amountToReturn = (msg.value > 1 ether) ? (msg.value - 1 ether) : 0;
        uint256 acceptedPayment = msg.value.sub(amountToReturn);
        // transfer payment on to data contract
        flightSuretyData.buy.value(acceptedPayment)(msg.sender, _airline, _flight, _timestamp);
        // ..before crediting any overspend
        msg.sender.transfer(amountToReturn);
    }


    // Transfers eligible payout funds to insuree
    function pay()
    external
    {
        flightSuretyData.pay(msg.sender);
    }


    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight
    (
        string calldata _flight,
        uint256 _timestamp
    )
    external
    requireIsOperational
    requireIsFundedAirline(msg.sender)
    {
        flightSuretyData.registerFlight(msg.sender, _flight, _timestamp);
    }


    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus
    (
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode
    )
    external
    requireIsOperational
    {
        flightSuretyData.processFlightStatus(airline, flight, timestamp, statusCode);
        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            flightSuretyData.creditInsurees(airline, flight, timestamp);
        }
    }


    // region ORACLE MANAGEMENT

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    // Register an oracle with the contract
    function registerOracle
    (
    )
    external
    payable
    requireIsOperational
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");
        flightSuretyData.registerOracle.value(msg.value)(msg.sender);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
    (
        address airline,
        string calldata flight,
        uint256 timestamp
    )
    requireIsOperational
    external
    {
        flightSuretyData.fetchFlightStatus(airline, flight, timestamp);
    }


    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
    (
        uint8 index,
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode
    )
    external
    requireIsOperational
    {
        flightSuretyData.submitOracleResponse(index, airline, flight, timestamp, statusCode, MIN_RESPONSES);
    }


    // endregion

}


// API for the Data Contract
contract FlightSuretyData {
    function isOperational()
    public
    view
    returns (bool);

    function isFundedAirline(address _airline)
    public
    view
    returns (bool);

    function registerAirline
    (address airline, address voter
    )
    external;

    function getAirlineStatus(address _airline)
    external
    view
    returns (bool isRegistered,
        bool isFunded,
        uint256 votes);

    function registeredAirlinesCount()
    public
    view
    returns (uint256);

    function fund
    (address airline)
    public
    payable;

    function registerFlight(address _airline,
        string calldata _flight,
        uint256 _timestamp)
    external;

    function buy
    (address passenger,
        address _airline,
        string calldata _flight,
        uint256 _timestamp
    )
    external
    payable;

    function processFlightStatus
    (
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode
    )
    external;

    function creditInsurees
    (
        address airline,
        string calldata flight,
        uint256 timestamp
    )
    external;

    function pay
    (address payable passenger
    )
    external;

    function registerOracle
    (address oracleAddr
    )
    external
    payable;

    function fetchFlightStatus
    (
        address airline,
        string calldata flight,
        uint256 timestamp
    )
    external;

    function submitOracleResponse
    (
        uint8 index,
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode,
        uint256 min_responses
    )
    external;
}
