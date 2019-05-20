pragma solidity ^0.5.8;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
//import "./FlightSuretyData.sol";

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
    //    address payable private  flightSuretyDataAddress; // Need payable address to the data contract to transfer ether

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
        // SafeMath
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
        flightSuretyData.processFlightStatus(airline,flight,timestamp,statusCode);
        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            flightSuretyData.creditInsurees(airline,flight,timestamp);
        }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
    (
        address airline,
        string calldata flight,
        uint256 timestamp
    )
    external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
            requester : msg.sender,
            isOpen : true
            });

        emit OracleRequest(index, airline, flight, timestamp);
    }


    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


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

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
            isRegistered : true,
            indexes : indexes
            });
    }

    function getMyIndexes
    (
    )
    view
    external
    returns (uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
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
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            this.processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
    (
        address airline,
        string memory flight,
        uint256 timestamp
    )
    pure
    internal
    returns (bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
    (
        address account
    )
    internal
    returns (uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
    (
        address account
    )
    internal
    returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;
            // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
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
}
