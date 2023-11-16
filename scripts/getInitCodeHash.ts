const { keccak256 } = require('viem');

const bytecode = require('../artifacts/contracts/SpeedswapV2Pair.sol/SpeedswapV2Pair.json').bytecode;
console.log(keccak256(bytecode));
