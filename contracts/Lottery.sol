pragma solidity ^0.5.0;

import "./oraclizeAPI.sol";

contract Lottery is usingOraclize {

    enum LotteryState { Accepting, Finished, Paid }

    event LogWinnerDetermined(address winner, uint256 amount);
    event LogBidMade(address participant);
    event LogGeneratedRandomNumber(uint randomNumber);

    address payable public organizer;
    address payable[] participants;
    LotteryState state; 


    constructor() public {
        organizer = msg.sender;
        state = LotteryState.Accepting;
    }

    modifier onlyOwner() {
        require(msg.sender == organizer, "only the organizer can execute it"); 
        _;
    }

    function bid() public payable {
        require(state == LotteryState.Accepting, "lottery is already over");
        require(msg.value == 0.1 ether, "you can bid with exactly 0.1 ether");
        participants.push(msg.sender);

        emit LogBidMade(msg.sender);
    }

    function determineWinner() public payable onlyOwner {
        require(participants.length > 0, "required at least one participant");
        require(state != LotteryState.Paid, "Lottery has already been paid");
        require(address(this).balance > oraclize_getPrice("URL"), "too low balance to pay for random number");

        state = LotteryState.Finished;
        oraclize_setProof(proofType_Ledger); // sets the Ledger authenticity proof in the constructor        
        oraclize_query("URL", "https://www.uuidgenerator.net/api/version4");
    }    

    function __callback(bytes32 _myid, string memory _result, bytes memory _proof) public {
        require(msg.sender == oraclize_cbAddress());
        require(state != LotteryState.Paid, "Lottery has already been paid");
       // if (oraclize_randomDS_proofVerify__returnCode(queryId, result, proof) != 0) {
            //revert();
      //  } 
        uint maxRange = 2**(8* 7);
        uint randomNumber = uint(keccak256(abi.encodePacked(_result))) % maxRange;
        emit LogGeneratedRandomNumber(randomNumber);

        uint256 balance = address(this).balance;
        uint256 winningPrice = balance - (balance / 10);
    
        uint256 winningIndex = randomNumber % participants.length + 1;
        address payable winner = participants[winningIndex];
        
        winner.transfer(winningPrice);
        state = LotteryState.Paid;

        emit LogWinnerDetermined(winner, winningPrice);
        selfdestruct(organizer);
    }
}
