pragma solidity ^0.4.24;

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

    // Account used to deploy contract
    address private contractOwner;

    // App links to the Data Contract
    FlightSuretyData  flightSuretyData;

    // Fee for an airline to join
    uint256 private constant JOIN_FEE = 10 ether;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

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


    /**
    * @dev Modifier prevent double-funding of airline
    */
    modifier requireNotAlreadyVoted(address airline, address voter)
    {
        require(flightSuretyData.hasNotAlreadyVoted(airline, voter), "A registered airline cannot vote more than once for same airline");
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

    function getRegistrationFee()
    public
    pure
    returns (uint256)
    {
        return REGISTRATION_FEE;
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
    (address airline, string companyName
    )
    external
    requireIsOperational
    requireIsFundedAirline(msg.sender) // the SENDER needs to be a funded airline
    requireNotAlreadyVoted(airline, msg.sender)
    {
        uint256 _registeredAirlines = flightSuretyData.registeredAirlinesCount();
        address voter = msg.sender;
        if (_registeredAirlines < 4) {
            // Votes are not necessary for initial 4 airlines
            // so automatically make them with registered status
            // BUT they are not yet funded
            flightSuretyData.addAirline(airline, companyName, true, false, 0);
        } else {
            uint256 idx = flightSuretyData.findAirline(airline);
            if (idx < flightSuretyData.getAirlineCount()) {
                // Matches the registration request for an existing airline...
                flightSuretyData.registerVote(idx, voter);
                // Once 50% membership votes for this airline, it will be registered
                uint256 _count50pct = _registeredAirlines.div(2);
                if (flightSuretyData.airlineVotes(idx) >= _count50pct) {
                    flightSuretyData.registerAirline(idx);
                }
            } else {
                // First request - Start with 1 vote and not yet registered
                flightSuretyData.addAirline(airline, companyName, false, false, 0);
                // Record vote
                idx = flightSuretyData.findAirline(airline);
                flightSuretyData.registerVote(idx, voter);
            }
        }
    }

    /**
     * Return status of specified airline
     */
    function getAirlineByIdx(uint256 idx)
    external
    view
    returns (bool isRegistered,
        bool isFunded,
        uint256 votes,
        address airlineAccount,
        string companyName)
    {
        //        retAcc = new address[](50);
        return flightSuretyData.getAirlineStatus(idx);
        //        uint256 airlineCount = flightSuretyData.getAirlineCount();
        //        uint256 i = 0;
        //        while (i<airlineCount && acc[i] != 0) {
        //            retAcc.push(acc[i]);
        //        }
        //        retAcc.length=i;
        //        return retAcc;
    }


    function getAirlineCount()
    external
    view
    returns (uint256)
    {
        return flightSuretyData.getAirlineCount();
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
        string _flight,
        uint256 _timestamp)
    external
    payable
    requireIsOperational
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
    requireIsOperational
    {
        flightSuretyData.pay(msg.sender);
    }


    // Get the current credit available
    function getCredit()
    public
    view
    returns (uint256)
    {
        return flightSuretyData.getCredit(msg.sender);
    }


    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight
    (
        string _flight,
        uint256 _timestamp
    )
    external
    requireIsOperational
    requireIsFundedAirline(msg.sender)
    {
        flightSuretyData.registerFlight(msg.sender, _flight, _timestamp);
    }


    /**
     * For testing purposes
     *
     */
    function processFlightStatus
    (
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode,
        uint8 multiplyBy,
        uint8 divideBy,
        uint8 payoutCode
    )
    external
    requireIsOperational
    {
        flightSuretyData.processFlightStatus(airline, flight, timestamp, statusCode, multiplyBy, divideBy, payoutCode);
    }


    ////////////////////////////////////////////////////////////////
    // region ORACLE MANAGEMENT
    ////////////////////////////////////////////////////////////////

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

        // SafeMath : determine any excess to return
        uint256 amountToReturn = 0;
        //msg.value.sub(REGISTRATION_FEE);
        // transfer payment on to data contract and flag as funded
        flightSuretyData.registerOracle.value(REGISTRATION_FEE)(msg.sender);
        // ..before crediting any overspend
        msg.sender.transfer(amountToReturn);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
    (
        address airline,
        string flight,
        uint256 timestamp
    )
    requireIsOperational
    external
    {
        flightSuretyData.fetchFlightStatus(airline, flight, timestamp, msg.sender);
    }


    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
    (
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    )
    external
    requireIsOperational
    {
        /* To ADD 150% compensation using integers, can multiply by 1 and divide by 2
           This approach can allow for any range of percentages by representing rationals
         */
        uint8 multiplyBy = 1;
        uint8 divideBy = 2;
        flightSuretyData.submitOracleResponse(index, airline, flight, timestamp, statusCode, MIN_RESPONSES,
            msg.sender, multiplyBy, divideBy, STATUS_CODE_LATE_AIRLINE);
    }


    function getMyIndexes
    (
    )
    view
    public
    returns (uint8[3] memory)
    {
        return flightSuretyData.getMyIndexes(msg.sender);
    }

    // endregion

}

////////////////////////////////////////////////////////////////
// API for the Data Contract
////////////////////////////////////////////////////////////////
contract FlightSuretyData {
    function isOperational()
    public
    view
    returns (bool);

    function isFundedAirline(address _airline)
    public
    view
    returns (bool);

    function addAirline
    (address airlineAccount, string companyName, bool isRegistered, bool isFunded, uint8 votes
    )
    external;

    function getAirlineStatus(address _airline)
    external
    view
    returns (bool isRegistered,
        bool isFunded,
        uint256 votes);

    function getAirlineStatus(uint256 idx)
    external
    view
    returns (bool isRegistered,
        bool isFunded,
        uint256 votes,
        address airlineAccount,
        string companyName);

    function registeredAirlinesCount()
    public
    view
    returns (uint256);

    function fund
    (address airline)
    public
    payable;

    function registerFlight(address _airline,
        string _flight,
        uint256 _timestamp)
    external;

    function buy
    (address passenger,
        address _airline,
        string _flight,
        uint256 _timestamp
    )
    external
    payable;

    function processFlightStatus
    (
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode,
        uint8 multiplyBy,
        uint8 divideBy,
        uint8 payoutCode
    ) public;

    function pay
    (address passenger
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
        string flight,
        uint256 timestamp,
        address passenderAddr
    )
    external;

    function submitOracleResponse
    (
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode,
        uint256 min_responses,
        address oracleAddr,
        uint8 multiplyBy,
        uint8 divideBy,
        uint8 payoutCode
    )
    external;

    function getMyIndexes
    (address oracleAddr
    )
    view
    public
    returns (uint8[3] memory);

    function findAirline(address _airline)
    external
    view
    returns (uint256);

    function registerVote(uint256 idx, address _voter)
    external;

    function airlineVotes(uint256 idx)
    external
    view
    returns (uint256);

    function registerAirline(uint256 idx)
    external;

    function hasNotAlreadyVoted(address _airline, address _voter)
    external
    view
    returns (bool);

    function getAirlineCount()
    public
    view
    returns (uint256);

    function getCredit(address passenger)
    public
    view
    returns (uint256);

}
