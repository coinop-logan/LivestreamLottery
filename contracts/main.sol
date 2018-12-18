pragma solidity 0.5.1;

import "prandom.sol";

contract LSLottery is PseudoRandom {
  enum Phase {Open, Resolving, Judgement}
  Phase public phase;

  //In the Open phase, people can buy tickets to the lottery.
  //In the Resolving phase, the lottery waits 3 blocks to get a block header as a source of randomness (see PseudoRandom).
  //In the Judgement phase, judges have the opportunity to burn the prize if the winner didn't deliver a livestream.
  //Once Judgement ends, the contract cycles to the Open phase.

  modifier inPhase(Phase p) {
    require (phase == p, "Contract is in the wrong phase for that function.");
    _;
  }

  uint public ticketPrice;
  uint public judgementIntervalInBlocks;
  uint public openIntervalInBlocks;

  uint public openPhaseEndBlock;

  constructor(uint _ticketPrice, uint _judgementIntervalInBlocks, uint _openIntervalInBlocks)
  PseudoRandom(2) // PseudoRandom will use 2 block headers as a source of randomness.
  public {
    phase = Phase.Open;

    ticketPrice = _ticketPrice;
    judgementIntervalInBlocks = _judgementIntervalInBlocks;
    openIntervalInBlocks = _openIntervalInBlocks;

    openPhaseEndBlock = block.number + openIntervalInBlocks;
  }

  // Each ticket is simply the address of the buyer.
  address payable[] public tickets;

  function buyTickets(uint numTickets)
  external
  inPhase(Phase.Open)
  payable {
    uint cost = numTickets * ticketPrice;
    require(msg.value == cost, "You included the wrong amount of ether!");

    createTickets(msg.sender, numTickets);
  }

  function createTickets(address payable who, uint numTickets)
  internal {
    for (uint i=0; i<numTickets; i++) {
      tickets.push(who);
    }
  }

  // What block number will we give to PseudoRandom to generate random values?
  uint randomSourceBlocknum;

  // Sets randomSourceBlocknum and starts the Resolving phase.
  function startResolving()
  external
  inPhase(Phase.Open) {
    require(tickets.length > 6, "Can't start a lottery with 6 tickets or less!");
    require(block.number >= openPhaseEndBlock, "Can't end the Open phase so soon!");

    randomSourceBlocknum = block.number + 3;

    phase = Phase.Resolving;
  }

  address payable public winningAddress;

  struct Judge {
    address who;
    bool voteToBurn;
  }
  Judge[5] public judges;

  // When can the winner take the prize (assuming it hasn't been burned yet)?
  uint public judgementPhaseEndBlock;

  // If the randomSourceBlocknum block is mined, determine the winner and judges,
  // change to Judgement phase, and set judgementPhaseEndBlock.
  function resolve()
  external
  inPhase(Phase.Resolving) {
    require(block.number > randomSourceBlocknum, "The random source block hasn't been mined yet!");

    PseudoRandom.seedFromBlocknum(randomSourceBlocknum);

    uint winningTicket = PseudoRandom.nextUint(tickets.length-1);
    winningAddress = tickets[winningTicket];
    removeTicket(winningTicket);
    for (uint i=0; i<judges.length; i++) {
      uint judgeTicket = PseudoRandom.nextUint(tickets.length-1);
      judges[i] = Judge(tickets[judgeTicket], false);
      removeTicket(judgeTicket);
    }

    phase = Phase.Judgement;

    judgementPhaseEndBlock = block.number + judgementIntervalInBlocks;
  }

  // Efficiently removes one ticket
  function removeTicket(uint iter)
  internal {
    tickets[iter] = tickets[tickets.length-1];
    tickets.length--; // pop last item off of tickets
  }

  function voteToBurn(uint judgeIter)
  external
  inPhase(Phase.Judgement) {
    require(judges[judgeIter].who == msg.sender, "You aren't the judge at that iterator!");
    judges[judgeIter].voteToBurn = true;

    burnIfNecessary();
  }

  // Tallies 'burn' votes. If there are enough, burn the prize and restart Lottery.
  function burnIfNecessary()
  internal {
    uint numBurnVotes;
    for (uint i=0; i<judges.length; i++) {
      if (judges[i].voteToBurn) {
        numBurnVotes++;
      }
    }

    if (numBurnVotes == 2) {
      burnRewardAndRestart();
    }
  }

  function burnRewardAndRestart()
  internal {
    address(0x0).transfer(address(this).balance); // Damn son that's cold

    restart();
  }

  // The winner or anyone else can call this if the prize has not yet been burned
  function releasePrizeAndRestart()
  external
  inPhase(Phase.Judgement) {
    require(block.number >= judgementPhaseEndBlock, "Release is not yet available!");

    winningAddress.transfer(address(this).balance); // Hella

    restart();
  }

  function restart()
  internal {
    phase = Phase.Open;
    tickets.length = 0; // clear tickets array
  }

  // --------------------- INTERFACE GETTERS --------------------------

  function numTickets()
  external
  view {
    return tickets.length;
  }
}
