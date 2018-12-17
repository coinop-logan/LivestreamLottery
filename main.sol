pragma solidity 0.5.1;

import "browser/prandom.sol";

contract LSLottery is PseudoRandom {
  enum Phase {Open, Resolving, Judgement}
  Phase public phase;

  modifier inPhase(Phase p) {
    require (phase == p, "Contract is in the wrong phase for that function.");
    _;
  }

  uint public ticketPrice;
  uint public judgementIntervalInBlocks;

  constructor(uint _ticketPrice, uint _judgementIntervalInBlocks)
  PseudoRandom(2)
  public {
    phase = Phase.Open;

    ticketPrice = _ticketPrice;
    judgementIntervalInBlocks = _judgementIntervalInBlocks;
  }

  address payable[] public tickets;
  //mapping (address => uint[]) public ticketsForAccounts;

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

  uint randomSourceBlocknum;

  function startResolving()
  external
  inPhase(Phase.Open) {
    require(tickets.length > 6, "Can't start a lottery with 6 tickets or less!");

    randomSourceBlocknum = block.number + 3;

    phase = Phase.Resolving;
  }

  address payable public winningAddress;

  struct Judge {
    address who;
    bool voteToBurn;
  }
  Judge[5] public judges;

  uint releaseAvailableBlocknum;

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

    releaseAvailableBlocknum = block.number + judgementIntervalInBlocks;
  }

  function voteToBurn(uint judgeIter)
  external
  inPhase(Phase.Judgement) {
    require(judges[judgeIter].who == msg.sender, "You aren't the judge at that iterator!");
    judges[judgeIter].voteToBurn = true;

    burnIfNecessary();
  }

  function burnIfNecessary()
  internal {
    uint numBurnVotes;
    for (uint i=0; i<judges.length; i++) {
      if (judges[i].voteToBurn) {
        numBurnVotes++;
      }
    }

    if (numBurnVotes == 2) {
      burnReward();
      restart();
    }
  }

  function burnReward()
  internal {
    address(0x0).transfer(address(this).balance); // Damn son that's cold
  }

  function releasePrizeAndRestart()
  external
  inPhase(Phase.Judgement) {
    require(block.number >= releaseAvailableBlocknum, "Release is not yet available!");

    winningAddress.transfer(address(this).balance);

    restart();
  }

  function removeTicket(uint iter)
  internal {
    tickets[iter] = tickets[tickets.length-1];
    tickets.length--;
  }

  function restart()
  internal {
    phase = Phase.Open;
    tickets.length = 0;
  }
}
