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

    mapping(bytes32 => Flight) private flights;

    mapping(address => bool) private authorizedAppContracts;
    mapping(address => bool) private funded;                  // maps an airline to true when funded

    uint256 totalFund;   // Total available fund for contract

    address[] private airlines;

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
        require(firstAirline != address(0x0), 'Must specify the first airline to register when deploying contract');
        contractOwner = msg.sender;
        airlines.push(firstAirline);
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
    modifier requireIsFundedAirline()
    {
        require(isFundedAirline(), "Airline is not funded");
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



    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline
    (address airline
    )
    external
    requireAuthorizedCaller
    requireIsOperational
    {
        airlines.push(airline);
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
    (
    )
    public
    payable
    requireAuthorizedCaller
    {
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
        fund();
    }

    /**
    * @dev Returns true if supplied address matches an airline address
    */
    function isAirline(address _airline)
    public
    view
    returns (bool)
    {
        uint8 i = 0;
        bool addrIsAirline = false;
        while (i < airlines.length && !addrIsAirline) {
            if (airlines[i] == _airline) {
                addrIsAirline = true;
            }
            i++;
        }
        return addrIsAirline;
    }


    /**
    * @dev Returns true if airline is funded
    */
    function isFundedAirline()
    public
    view
    returns (bool)
    {
        return funded[msg.sender];
    }

}

