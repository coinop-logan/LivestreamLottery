pragma solidity 0.5.1;

contract PseudoRandom {
  uint8 strength; // How many blocks' hashes should we combine? (2 or 3 is probably fine for most use cases)
  bytes32 private nextRandomSource; // Will be converted to uint when called for a random number

  constructor(uint8 _strength) public {
    strength = _strength;
  }

  // Sets nextRandomSource to the specified block's hash.
  // Analogous to many random libraries' seed() function.
  function seedFromBlocknum(uint blocknum)
  internal {
    bytes32 seed;
    for (uint i=0; i<strength; i++) {
      seed = keccak256(abi.encodePacked(seed, blockhash(blocknum-i)));
    }
    nextRandomSource = seed;
  }

  // Returns the source of randomness and generate a new source for the next call
  function getSourceAndAdvance()
  private
  returns(bytes32) {
    bytes32 source = nextRandomSource;
    nextRandomSource = keccak256(abi.encodePacked(nextRandomSource));
    return source;
  }

  // Provides a pseudorandom uint in the given range
  function nextUint(uint max)
  internal
  returns(uint) {
    require(max+1 != 0, "Error! PseudoRandom cannot handle a 'max' value of MAX_INT!"); // otherwise max+1 below overflows
    return uint(getSourceAndAdvance())%(max+1);
  }
}
