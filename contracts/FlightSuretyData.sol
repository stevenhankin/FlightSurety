pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                          // Account used to deploy contract
    bool private operational = true;                        // Blocks all state changes throughout the contract if false


    struct Insurance {
        bytes32 flightKey;
        address passenger;
        uint256 payment;
    }

    struct Flight {
        address airline;
        uint256 departureTimestamp;
        uint8 statusCode;
    }


    struct Airline {
        address airlineAccount;
        bool isRegistered;
        bool isFunded;
        uint256 votes;
        mapping(address => bool) voters;                        // track airlines that have already voted
    }

    Airline[] private airlines;
    Insurance[] private insurance;                              // List of passenger insurance
    mapping(address => uint256) private passengerCredit;        // For a given passenger has the total credit due
    uint256 private constant SENTINEL = 2 ^ 256 - 1;                // MAX VALUE => "not found"
    mapping(bytes32 => Flight) private flights;                 // keys (see getFlightKey) of flights for airline
    mapping(address => bool) private authorizedAppContracts;


    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;




    ////////////////////
    // State for Oracles
    ////////////////////
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

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    *      First airline is registered at deployment
    */
    constructor
    (address firstAirline
    )
    public
    {
        require(firstAirline != address(0), 'Must specify the first airline to register when deploying contract');
        contractOwner = msg.sender;
        airlines.push(Airline({airlineAccount : firstAirline, isRegistered : true, isFunded : false, votes : 0}));
    }

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
        require(operational, "Contract is currently not operational");
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
    * @dev Modifier that requires the calling contract has been authorized
    */
    modifier requireAuthorizedCaller()
    {
        require(authorizedAppContracts[msg.sender], "Caller is not an authorized contract");
        _;
    }

    /**
    * @dev Modifier requires the Airline that is calling is already funded
    */
    modifier requireIsFundedAirline(address airline)
    {
        require(isFundedAirline(airline), "Airline is not funded");
        _;
    }

    // A voter can only raise one registration vote
    // for a given airline
    modifier requireNotAlreadyVoted(address _airline, address _voter)
    {
        require(hasNotAlreadyVoted(_airline, _voter), "A registered airline cannot vote more than once for same airline");
        _;
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational()
    public
    view
    returns (bool)
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus
    (
        bool mode
    )
    external
    requireContractOwner
    {
        operational = mode;
    }


    /**
    * @dev Authorize an App Contract to delegate to this data contract
    */
    function authorizeCaller(address _appContract)
    public
    {
        authorizedAppContracts[_appContract] = true;
    }


    // Return index of the Airline for the matching address
    // or SENTINEL if no match
    function findAirline(address _airline)
    internal
    view
    returns (uint256)
    {
        // Loop through airline until found or end
        uint256 i = 0;
        uint256 airlineCount = airlines.length;
        while (i < airlineCount) {
            if (airlines[i].airlineAccount == _airline) {
                return i;
            }
            i++;
        }
        return SENTINEL;
    }


    // True if the Voter has not already raise
    // a registration vote for airline
    function hasNotAlreadyVoted(address _airline, address _voter)
    internal
    view
    returns (bool)
    {
        uint256 idx = findAirline(_airline);
        if (idx != SENTINEL) {
            return !airlines[idx].voters[_voter];
        }
        return true;
    }


    // Used for testing
    function getCredit(address passenger)
    public
    view
    requireContractOwner
    returns (uint256)
    {
        return passengerCredit[passenger];
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/



    // Useful to check how close an airline is to being registered
    // based on number of votes
    function getAirlineStatus(address _airline)
    external
    view
    requireAuthorizedCaller
    requireIsOperational
    returns (bool isRegistered,
        bool isFunded,
        uint256 votes)
    {
        uint256 idx = findAirline(_airline);
        if (idx != SENTINEL) {
            Airline memory airline = airlines[idx];
            return (airline.isRegistered, airline.isFunded, airline.votes);
        }
        return (false, false, 0);
    }


    /***
     * @dev Return number of airlines registered so far
     *
     */
    function registeredAirlinesCount()
    public
    view
    returns (uint256) {
        return airlines.length;
    }


    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline
    (address _airline, address _voter
    )
    external
    requireAuthorizedCaller
    requireIsOperational
    requireNotAlreadyVoted(_airline, _voter)
    {
        uint256 _registeredAirlines = registeredAirlinesCount();
        if (_registeredAirlines < 4) {
            // Votes are not necessary for initial airlines - setting to 0
            airlines.push(Airline({airlineAccount : _airline, isRegistered : true, isFunded : false, votes : 0}));
        } else {
            uint256 idx = findAirline(_airline);
            if (idx != SENTINEL) {
                // Airline has had at least one registration request
                // Incrementing by 1 vote..
                airlines[idx].votes++;
                // Record vote
                airlines[idx].voters[_voter] = true;
                // Once 50% membership votes for this airline, it will be registered
                uint256 _count50pct = _registeredAirlines.div(2);
                if (airlines[idx].votes >= _count50pct) {
                    airlines[idx].isRegistered = true;
                }
            } else {
                // First request - Start with 1 vote and not yet registered
                airlines.push(Airline({airlineAccount : _airline, isRegistered : false, isFunded : false, votes : 1}));
                // Record vote
                idx = findAirline(_airline);
                airlines[idx].voters[_voter] = true;
            }
        }
    }


    // Add a flight schedule to an airline
    function registerFlight(address _airline,
        string  _flight,
        uint256 _timestamp)
    external
    requireIsOperational
    requireAuthorizedCaller
    requireIsFundedAirline(_airline)
    {
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        flights[flightKey] = Flight({airline : _airline, departureTimestamp : _timestamp, statusCode : 0});
    }



    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy
    (address passenger,
        address _airline,
        string  _flight,
        uint256 _timestamp
    )
    external
    payable
    requireIsOperational
    requireAuthorizedCaller
    requireIsFundedAirline(_airline)
    {
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        Flight memory flight = flights[flightKey];
        require(address(flight.airline) != address(0), 'Flight does not exist');
        Insurance memory _insurance = Insurance({flightKey : flightKey, passenger : passenger, payment : msg.value});
        insurance.push(_insurance);
    }

    /**
     *  @dev Credits payouts to insurees at 1.5x the original payment
    */
    function creditInsurees
    (
        address airline,
        string  flight,
        uint256 timestamp
    )
    external
    requireAuthorizedCaller
    requireIsOperational
    {
        bytes32 delayedFlightKey = getFlightKey(airline, flight, timestamp);
        uint256 i = 0;
        uint256 totalRecords = insurance.length;
        while (i < totalRecords) {
            Insurance memory _insurance = insurance[i];
            if (_insurance.flightKey == delayedFlightKey) {
                address passenger = _insurance.passenger;
                // Add payment to each passenger affected by the delayed flight
                // and at 1.5x original amount
                uint256 halfOriginal = _insurance.payment.div(2);
                passengerCredit[passenger] += _insurance.payment.add(halfOriginal);
                // ..and remove insurance record to prevent possible double-spend
                delete insurance[i];
            }
            i++;
        }
    }


    // Called after oracle has updated flight status
    function processFlightStatus
    (
        address airline,
        string  flight,
        uint256 timestamp,
        uint8 statusCode
    )
    external
    requireAuthorizedCaller
    requireIsOperational
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        flights[flightKey].statusCode = statusCode;
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
    (address  passenger
    )
    external
    requireAuthorizedCaller
    requireIsOperational
    {
        uint256 amount = passengerCredit[passenger];
        passengerCredit[passenger] = 0;
        passenger.transfer(amount);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund
    (address airlineAddr)
    public
    payable
    requireAuthorizedCaller
    requireIsOperational
    {
        uint256 idx = findAirline(airlineAddr);
        if (idx != SENTINEL) {
            airlines[idx].isFunded = true;
        }
    }

    // Unique hash
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

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function()
    external
    payable
    requireAuthorizedCaller
    {
        //                fund();
    }

    /**
    * @dev Returns true if supplied address matches an airline address
    */
    function isAirline(address _airline)
    public
    view
    returns (bool)
    {
        uint256 idx = findAirline(_airline);
        if (idx != SENTINEL) {
            return true;
        }
        return false;
    }


    /**
    * @dev Returns true if airline is funded
    */
    function isFundedAirline(address _airline)
    public
    view
    returns (bool)
    {
        uint256 idx = findAirline(_airline);
        if (idx != SENTINEL) {
            return airlines[idx].isFunded;
        }
        // Airline account doesn't exist
        return false;
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
    (
        address airline,
        string  flight,
        uint256 timestamp,
        address passenderAddr
    )
    requireAuthorizedCaller
    requireIsOperational
    external
    {
        uint8 index = getRandomIndex(passenderAddr);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
            requester : passenderAddr,
            isOpen : true
            });

        emit OracleRequest(index, airline, flight, timestamp);
    }


    // Register an oracle with the contract
    function registerOracle
    (address oracleAddr
    )
    external
    payable
    requireIsOperational
    requireAuthorizedCaller
    {
        uint8[3] memory indexes = generateIndexes(oracleAddr);

//        Oracle memory newOracle = Oracle({
//            isRegistered : true,
//            indexes : indexes
//            });
//
//        oracles[oracleAddr] = newOracle;

    }

    function getMyIndexes
    (address oracleAddr
    )
    view
    public
    returns (uint8[3] memory)
    {
        require(oracles[oracleAddr].isRegistered, "Not registered as an oracle");

        return oracles[oracleAddr].indexes;
    }


    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
    (
        uint8 index,
        address airline,
        string  flight,
        uint256 timestamp,
        uint8 statusCode,
        uint256 min_responses,
        address oracleAddr
    )
    external
    requireIsOperational
    requireAuthorizedCaller
    {
        require((oracles[oracleAddr].indexes[0] == index) || (oracles[oracleAddr].indexes[1] == index) || (oracles[oracleAddr].indexes[2] == index), "Index does not match oracle request");

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(oracleAddr);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= min_responses) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            this.processFlightStatus(airline, flight, timestamp, statusCode);
        }
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
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number), nonce++, account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;
            // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
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


}

