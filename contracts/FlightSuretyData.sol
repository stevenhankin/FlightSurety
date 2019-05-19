pragma solidity ^0.5.8;

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
    }


    struct Airline {
        address airlineAccount;
        bool isRegistered;
        bool isFunded;
        uint256 votes;
        mapping(address => bool) voters;            // keep track of airlines that have already voted
    }

    Airline[] private airlines;
    Insurance[] private insurance;                          // List of passenger insurance

    uint256 private constant SENTINEL = 9999999999; //2^250; // Used as a return value for "not found"

    mapping(bytes32 => Flight) private flights;   // keys (see getFlightKey) of flights belonging to airline

    mapping(address => bool) private authorizedAppContracts;

    uint256 private constant JOIN_FEE = 10 ether; // Fee for an airline to join


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
        // All modifiers require an "_" which indicates where the function body will be added
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


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/



    // Useful to check how close an airline is to being registered
    // based on number of votes
    function getAirlineStatus(address _airline)
    external
    view
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
        string calldata _flight,
        uint256 _timestamp)
    external
    requireIsOperational
    requireAuthorizedCaller
    requireIsFundedAirline(_airline)
    {
        uint256 idx = findAirline(_airline);
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        Flight memory flight;
        flight.airline = _airline;
        flight.departureTimestamp = _timestamp;
        flights[flightKey] = flight;
    }


    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy
    (   address passenger,
        address _airline,
        string calldata _flight,
        uint256 _timestamp
    )
    external
    payable
    requireIsOperational
    requireAuthorizedCaller
    requireIsFundedAirline(_airline)
    {
        uint256 idx = findAirline(_airline);
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        Flight memory flight = flights[flightKey];
        require(address(flight.airline) != address(0), 'Flight does not exist');
        Insurance memory _insurance = Insurance({flightKey: flightKey, passenger:passenger, payment:msg.value} );
        insurance.push(_insurance);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
    (
    )
    external
    view
    requireAuthorizedCaller
    {
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
    (
    )
    external
    view
    requireAuthorizedCaller
    {
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
    {
        require(msg.value >= JOIN_FEE, "Funding payment (of Data Contract) too low");
        uint256 idx = findAirline(airlineAddr);
        if (idx != SENTINEL) {
            airlines[idx].isFunded = true;
        }
        //        funded[airline] = true;
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

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function()
    external
    payable
    requireAuthorizedCaller
    {
        //        fund();
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
        return false;
        // Airline account doesn't exist
    }

}

