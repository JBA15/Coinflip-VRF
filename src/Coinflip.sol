// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// Importing the necessary contracts from openzeppelin
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Importing the provided VRF oracle client
import {DirectFundingConsumer} from "./DirectFundingConsumer.sol";

contract Coinflip is Ownable{
    // A map of the player and their corresponding requestId
    mapping(address => uint256) public playerRequestID;
    // A map that stores the player's 3 Coinflip guesses
    mapping(address => uint8[3]) public bets;
    // An instance of the random number requestor, client interface
    DirectFundingConsumer private vrfRequestor;

    /// @dev we no longer use the seed, instead each coinflip deployment should spawn its own VRF instance so that the Coinflip smart contract is the owner of the DirectFunding contract.
    /// @notice This programming pattern is known as a factory model - a contract creating other contracts 
    constructor() Ownable(msg.sender) {
        // Deploying a new DirectFundingConsumer instance
        vrfRequestor = new DirectFundingConsumer();
    }

    /// @notice Fund the VRF instance with **5** LINK tokens.
    /// @return boolean of whether funding the VRF instance with link tokens was successful or not
    /// @dev use the address of LINK token contract provided. Do not change the address!
    /// @custom:important Attention! In order for this contract to fund another contract, which tokens does this contract need to have before calling this function? What **additional** functions does this contract need to "receive" these tokens itself?
    function fundOracle() external returns(bool){
        address Link_addr = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        IERC20 linkToken = IERC20(Link_addr);

        // Assuming LINK has 18 decimals: 5 LINK tokens = 5 * 10**18
        uint256 amount = 5 * 10**18;

        // Transfering 5 LINK from this contract’s balance to the VRF oracle
        bool success = linkToken.transfer(address(vrfRequestor), amount);
        require(success, "LINK transfer failed");
        return success;
    }

    /// @notice user guess THREE flips either a 1 or a 0.
    /// @param Guesses 3 coinflip guesses - which is "required" to be 1 or 0
    /// @dev After validating the user input, store the user input and request ID in their respective global mappings and call the "requestRandomWords" function in VRF instance
    /// @custom:important Attention! How do we make sure 3 random numbers are requested?
    /// @dev Then, store the requestid in global mapping
    function userInput(uint8[3] calldata Guesses) external {
        // Validating that each guess is either 0 or 1
        for (uint i = 0; i < 3; i++) {
            require(Guesses[i] == 0 || Guesses[i] == 1, "Each guess must be 0 or 1");
        }

        // Saving the player’s guesses
        bets[msg.sender] = Guesses;

        // Requesting 3 random words from the VRF oracle
        uint256 requestId = vrfRequestor.requestRandomWords(false);

        // Recording the requestId for this player
        playerRequestID[msg.sender] = requestId;
    }

    /// @notice Due to the fact that a blockchain does not deliver data instantaneously, in fact quite slowly under congestion, allow users to check the status of their request.
    /// @return boolean of whether the request has been fulfilled or not
    function checkStatus() external view returns(bool){
        uint256 requestId = playerRequestID[msg.sender];
        // Retrieving the request status (paid, fulfilled, and randomWords) using the helper function.
        (, bool fulfilled, ) = vrfRequestor.getRequestStatus(requestId);
        return fulfilled;
    }

    /// @return boolean of whether the user won or not based on their input
    /// @dev Check if whether each of the three random numbers is even or odd. If it is even, the randomly generated flip is 0 and if it is odd, the random flip is 1.
    /// @notice Player wins if the 1, 0 flips of the contract matches the 3 guesses of the player.
    function determineFlip() external view returns(bool){
        uint256 requestId = playerRequestID[msg.sender];
        // Retrieve the status including randomWords.
        (, bool fulfilled, uint256[] memory randomWords) = vrfRequestor.getRequestStatus(requestId);
        require(fulfilled, "Randomness not fulfilled yet");
        require(randomWords.length >= 3, "Not enough random words received");

        uint8[3] memory outcomes;
        for (uint i = 0; i < 3; i++) {
            outcomes[i] = uint8(randomWords[i] % 2);
        }
        uint8[3] memory userGuesses = bets[msg.sender];
        return (outcomes[0] == userGuesses[0] &&
                outcomes[1] == userGuesses[1] &&
                outcomes[2] == userGuesses[2]);
    }
}