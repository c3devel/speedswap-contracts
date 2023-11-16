// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.6.12;

import './interfaces/ISpeedswapV2Factory.sol';
import './SpeedswapV2Pair.sol';

contract SpeedswapV2Factory is ISpeedswapV2Factory {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(uint256 => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(SpeedswapV2Pair).creationCode);
    }

    function createPair(address tokenA, address tokenB, uint8 fee) external override returns (address pair) {
        require(tokenA != tokenB, 'SpeedswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'SpeedswapV2: ZERO_ADDRESS');
        require(getPair[token0][encodeKey(token1, fee)] == address(0), 'SpeedswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(SpeedswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        SpeedswapV2Pair(pair).initialize(token0, token1, fee);
        getPair[token0][encodeKey(token1, fee)] = pair;
        getPair[token1][encodeKey(token0, fee)] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'SpeedswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'SpeedswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    // Helper function to encode an address and uint8 into a uint256
    function encodeKey(address addr, uint8 num) internal pure returns (uint256) {
        return (uint256(uint160(addr)) << 8) | num;
    }
}
