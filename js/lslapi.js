function prepareWeb3() {
  if (window.web3) {
    // We keep the old web3 around for event fetching.
    window.oldWeb3 = web3;
    window.web3 = new Web3(window.web3.currentProvider);
  }
  else {
    return reject(Error("No web3 object found!"));
  }

  // Track all the promises, so we can return a Promise.all in the end.
  web3Promises = []

  web3Promises.push(web3.eth.getAccounts().then(function(accounts) {
    web3.eth.defaultAccount = accounts[0];
  }));

  //Create lslContract objects (including one with the old web3 interface, for event watching)
  window.lslContract = new web3.eth.Contract(lslABI, lslAddress);
  window.oldWeb3LotteryContract = new oldWeb3.eth.contract(lslABI).at(lslAddress);

  web3Promises.push(lslContract.methods.ticketPrice().call().then(function(ticketCostWei) {
    window.ticketCostWei = ticketCostWei;
  }));

  return Promise.all(web3Promises);
}

function blockIntervalToTimeInterval(blockInterval) {
  return blockInterval * AVERAGE_BLOCKTIME;
}

function pastBlocknumToTimestamp(blocknum) {
  return web3.eth.getBlock(blocknum).then(function(block) {
    return block.timestamp;
  });
}

function futureBlocknumToTimestampEstimate(blocknum) {
  return web3.eth.getBlock('latest').then(function(block) {
    var blockInterval = blocknum - block.number;
    return block.timestamp + blockIntervalToTimeInterval(blockInterval);
  });
}

function getPhase() {
  return lslContract.methods.phase().call();
}

function getOpenPhaseEndBlock() {
  return lslContract.methods.openPhaseEndBlock();
}

function getJudgementEndBlock() {
  return lslContract.methods.judgementPhaseEndBlock();
}

function getNumTickets() {
  return lslContract.methods.numTickets.call();
}

function getNumTicketsFor(address) {
  return lslContract.methods.numTicketsFor(address).call();
}
