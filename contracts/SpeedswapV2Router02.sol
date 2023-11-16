// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.6.12;

pragma experimental ABIEncoderV2;

import './libraries/SpeedswapV2Library.sol';
import './libraries/SafeMath.sol';
import './libraries/TransferHelper.sol';
import './interfaces/ISpeedswapV2Router02.sol';
import './interfaces/ISpeedswapV2Factory.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract SpeedswapV2Router02 is ISpeedswapV2Router02 {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'SpeedswapV2Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint8 fee,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (ISpeedswapV2Factory(factory).getPair(tokenA, encodeKey(tokenB, fee)) == address(0)) {
            ISpeedswapV2Factory(factory).createPair(tokenA, tokenB, fee);
        }
        (uint reserveA, uint reserveB) = SpeedswapV2Library.getReserves(factory, tokenA, tokenB, fee);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = SpeedswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'SpeedswapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = SpeedswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'SpeedswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint8 fee,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, fee, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = SpeedswapV2Library.pairFor(factory, tokenA, tokenB, fee);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = ISpeedswapV2Pair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint8 fee,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            fee,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = SpeedswapV2Library.pairFor(factory, token, WETH, fee);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = ISpeedswapV2Pair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint8 fee,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = SpeedswapV2Library.pairFor(factory, tokenA, tokenB, fee);
        ISpeedswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = ISpeedswapV2Pair(pair).burn(to);
        (address token0,) = SpeedswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'SpeedswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'SpeedswapV2Router: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint8 fee,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            fee,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint8 fee,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        PermitParams calldata params
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = SpeedswapV2Library.pairFor(factory, tokenA, tokenB, fee);
        uint value = params.approveMax ? uint(-1) : liquidity;
        ISpeedswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, params.v, params.r, params.s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, fee, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint8 fee,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        PermitParams calldata params
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = SpeedswapV2Library.pairFor(factory, token, WETH, fee);
        uint value = params.approveMax ? uint(-1) : liquidity;
        ISpeedswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, params.v, params.r, params.s);
        (amountToken, amountETH) = removeLiquidityETH(token, fee, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint8 fee,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            fee,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint8 fee,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        PermitParams calldata params
    ) external virtual override returns (uint amountETH) {
        address pair = SpeedswapV2Library.pairFor(factory, token, WETH, fee);
        uint value = params.approveMax ? uint(-1) : liquidity;
        ISpeedswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, params.v, params.r, params.s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, fee, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, uint8 fee, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SpeedswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? SpeedswapV2Library.pairFor(factory, output, path[i + 2], fee) : _to;
            ISpeedswapV2Pair(SpeedswapV2Library.pairFor(factory, input, output, fee)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint8 fee,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = SpeedswapV2Library.getAmountsOut(factory, amountIn, path, fee);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SpeedswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpeedswapV2Library.pairFor(factory, path[0], path[1], fee), amounts[0]
        );
        _swap(amounts, path, fee, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        uint8 fee,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = SpeedswapV2Library.getAmountsIn(factory, amountOut, path, fee);
        require(amounts[0] <= amountInMax, 'SpeedswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpeedswapV2Library.pairFor(factory, path[0], path[1], fee), amounts[0]
        );
        _swap(amounts, path, fee, to);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, uint8 fee, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'SpeedswapV2Router: INVALID_PATH');
        amounts = SpeedswapV2Library.getAmountsOut(factory, msg.value, path, fee);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SpeedswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(SpeedswapV2Library.pairFor(factory, path[0], path[1], fee), amounts[0]));
        _swap(amounts, path, fee, to);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, uint8 fee, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'SpeedswapV2Router: INVALID_PATH');
        amounts = SpeedswapV2Library.getAmountsIn(factory, amountOut, path, fee);
        require(amounts[0] <= amountInMax, 'SpeedswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpeedswapV2Library.pairFor(factory, path[0], path[1], fee), amounts[0]
        );
        _swap(amounts, path, fee, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, uint8 fee, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'SpeedswapV2Router: INVALID_PATH');
        amounts = SpeedswapV2Library.getAmountsOut(factory, amountIn, path, fee);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SpeedswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpeedswapV2Library.pairFor(factory, path[0], path[1], fee), amounts[0]
        );
        _swap(amounts, path, fee, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, uint8 fee, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'SpeedswapV2Router: INVALID_PATH');
        amounts = SpeedswapV2Library.getAmountsIn(factory, amountOut, path, fee);
        require(amounts[0] <= msg.value, 'SpeedswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(SpeedswapV2Library.pairFor(factory, path[0], path[1], fee), amounts[0]));
        _swap(amounts, path, fee, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to, uint8 fee) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SpeedswapV2Library.sortTokens(input, output);
            ISpeedswapV2Pair pair = ISpeedswapV2Pair(SpeedswapV2Library.pairFor(factory, input, output, fee));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = SpeedswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? SpeedswapV2Library.pairFor(factory, output, path[i + 2], fee) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint8 fee,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpeedswapV2Library.pairFor(factory, path[0], path[1], fee), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, fee);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'SpeedswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        uint8 fee,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'SpeedswapV2Router: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(SpeedswapV2Library.pairFor(factory, path[0], path[1], fee), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, fee);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'SpeedswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint8 fee,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'SpeedswapV2Router: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpeedswapV2Library.pairFor(factory, path[0], path[1], fee), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this), fee);
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'SpeedswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return SpeedswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return SpeedswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return SpeedswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path, uint8 fee)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return SpeedswapV2Library.getAmountsOut(factory, amountIn, path, fee);
    }

    function getAmountsIn(uint amountOut, address[] memory path, uint8 fee)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return SpeedswapV2Library.getAmountsIn(factory, amountOut, path, fee);
    }

    // Helper function to encode an address and uint8 into a uint256
    function encodeKey(address addr, uint8 num) internal pure returns (uint256) {
        return (uint256(uint160(addr)) << 8) | num;
    }
}
