pragma solidity ^0.5.8;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                          // Account used to deploy contract
    bool private operational = true;                        // Blocks all state changes throughout the contract if false

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }


    struct Airline {
//        bool isRegistered;
//        uint8 statusCode;
//        uint256 updatedTimestamp;
        address airlineAccount;
        bool isFunded;

    }

    Airline[] private airlines;

    uint256 private constant SENTINEL = 9999999999; //2^250; // Used as a return value for "not found"

    mapping(bytes32 => Flight) private flights;

    mapping(address => bool) private authorizedAppContracts;
//    mapping(address => bool) private funded;                  // maps an airline to true when funded


    address  private  firstOne; // TODO: DELETE THIS!

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
        firstOne = firstAirline;
        contractOwner = msg.sender;
//        Airline airline = new Airline({airlineAccount:firstAirline, funded:false});
        airlines.push(Airline({airlineAccount:firstAirline, isFunded:false}));
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


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

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
    (address airlineAccount
    )
    external
    requireAuthorizedCaller
    requireIsOperational
    {
        if (registeredAirlinesCount() <= 4) {
            airlines.push(Airline({airlineAccount:airlineAccount, isFunded:false}));
        } else {
            bool y = true;
            revert('Not yet implemented registerAirline for 4 or more accounts');
//            success = false;
//            votes = 0;
        }
    }


    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy
    (
    )
    external
    payable
    requireAuthorizedCaller
    {

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

//        // Loop through airline until found or end
//        uint8 i = 0;
//        bool addrIsAirline = false;
//        uint16 airlineCount = airlines.length;
//        while (i < airlineCount && !addrIsAirline) {
//            if (airlines[i].airlineAccount == _airline) {
//                addrIsAirline = true;
//            }
//            i++;
//        }
//        return addrIsAirline;
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
//        // Loop through airline until found or end
//        uint8 i = 0;
//        bool isFunded = false;
//        while (i < airlines.length && !addrIsAirline) {
//            if (airlines[i].airlineAccount == _airline) {
//                return airlines[i].isFunded;
//            }
//            i++;
//        }
        return false; // Airline account doesn't exist
    }

}

