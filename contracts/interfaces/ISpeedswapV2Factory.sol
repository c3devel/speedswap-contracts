// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

interface ISpeedswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint allPairsLength, uint8 fee);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, uint256 tokenBWithFee) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB, uint8 fee) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
