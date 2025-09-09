// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice zAMM stETH zap helper.
/// @dev Includes exactIn/exactOut
/// for Lido staking and ETH claims
/// in 0.01% Uniswap V3 wstETH pool.
contract ZstETH {
    constructor() payable {
        IERC20(STETH).approve(WSTETH, type(uint256).max);
    }

    // LIDO STAKING ****

    // **** EXACT ETH IN - MAX TOKEN OUT
    // note: If user doesn't care about `to` then just send ETH to STETH or WSTETH

    function exactETHToSTETH(address to) public payable returns (uint256 shares) {
        assembly ("memory-safe") {
            mstore(0x00, 0xa1903eab000000000000000000000000)
            pop(call(gas(), STETH, callvalue(), 0x10, 0x24, 0x00, 0x20))
            shares := mload(0x00)
            mstore(0x00, 0x8fcb4e5b000000000000000000000000)
            mstore(0x14, to)
            mstore(0x34, shares)
            pop(call(gas(), STETH, 0, 0x10, 0x44, codesize(), 0x00))
            mstore(0x34, 0)
        }
    }

    function exactETHToWSTETH(address to) public payable returns (uint256 wstOut) {
        assembly ("memory-safe") {
            pop(call(gas(), WSTETH, callvalue(), codesize(), 0x00, codesize(), 0x00))
            mstore(0x14, address())
            mstore(0x00, 0x70a08231000000000000000000000000)
            pop(staticcall(gas(), WSTETH, 0x10, 0x24, 0x00, 0x20))
            wstOut := mload(0x00)
            mstore(0x00, 0xa9059cbb000000000000000000000000)
            mstore(0x14, to)
            mstore(0x34, wstOut)
            pop(call(gas(), WSTETH, 0, 0x10, 0x44, codesize(), 0x00))
            mstore(0x34, 0)
        }
    }

    // **** EXACT TOKEN OUT - REFUND EXCESS ETH IN

    function ethToExactSTETH(address to, uint256 exactOut) public payable {
        assembly ("memory-safe") {
            mstore(0x00, 0xd5002f2e000000000000000000000000)
            pop(staticcall(gas(), STETH, 0x10, 0x04, 0x00, 0x20))
            let S := mload(0x00)
            mstore(0x00, 0x37cfdaca000000000000000000000000)
            pop(staticcall(gas(), STETH, 0x10, 0x04, 0x00, 0x20))
            let T := mload(0x00)
            let z := mul(exactOut, S)
            let sharesNeeded := add(iszero(iszero(mod(z, T))), div(z, T))
            z := mul(sharesNeeded, T)
            let ethIn := add(iszero(iszero(mod(z, S))), div(z, S))
            if gt(ethIn, callvalue()) { revert(0x00, 0x00) }
            pop(call(gas(), STETH, ethIn, codesize(), 0x00, codesize(), 0x00))
            mstore(0x00, 0x8fcb4e5b000000000000000000000000)
            mstore(0x14, to)
            mstore(0x34, sharesNeeded)
            pop(call(gas(), STETH, 0, 0x10, 0x44, codesize(), 0x00))
            if gt(callvalue(), ethIn) {
                pop(
                    call(
                        gas(), caller(), sub(callvalue(), ethIn), codesize(), 0x00, codesize(), 0x00
                    )
                )
            }
        }
    }

    function ethToExactWSTETH(address to, uint256 exactOut) public payable {
        assembly ("memory-safe") {
            mstore(0x00, 0xd5002f2e000000000000000000000000)
            pop(staticcall(gas(), STETH, 0x10, 0x04, 0x00, 0x20))
            let S := mload(0x00)
            mstore(0x00, 0x37cfdaca000000000000000000000000)
            pop(staticcall(gas(), STETH, 0x10, 0x04, 0x00, 0x20))
            let ethIn := mul(exactOut, mload(0x00))
            ethIn := add(iszero(iszero(mod(ethIn, S))), div(ethIn, S))
            if gt(ethIn, callvalue()) { revert(0x00, 0x00) }
            pop(call(gas(), WSTETH, ethIn, codesize(), 0x00, codesize(), 0x00))
            mstore(0x00, 0xa9059cbb000000000000000000000000)
            mstore(0x14, to)
            mstore(0x34, exactOut)
            pop(call(gas(), WSTETH, 0, 0x10, 0x44, codesize(), 0x00))
            if gt(callvalue(), ethIn) {
                pop(
                    call(
                        gas(), caller(), sub(callvalue(), ethIn), codesize(), 0x00, codesize(), 0x00
                    )
                )
            }
        }
    }

    // AMM SWAPS ****

    error Slippage();

    // **** EXACT IN - MAX OUT WITH MIN

    function swapExactETHToWSTETH(address to, uint256 minOut) public payable {
        (int256 amount0,) = IV3Swap(POOL).swap(
            to,
            false,
            int256(msg.value),
            MAX_SQRT_RATIO_MINUS_ONE,
            abi.encodePacked(false, false, false, msg.sender, to)
        );
        require(uint256(-amount0) >= minOut, Slippage());
    }

    function swapExactSTETHtoETH(address to, uint256 amount, uint256 minOut) public {
        uint256 wstOut;
        assembly ("memory-safe") {
            let m := mload(0x40)
            mstore(0x60, amount)
            mstore(0x40, address())
            mstore(0x2c, shl(96, caller()))
            mstore(0x0c, 0x23b872dd000000000000000000000000)
            pop(call(gas(), STETH, 0, 0x1c, 0x64, 0x00, 0x20))
            mstore(0x40, m)
            mstore(0x00, 0xea598cb0)
            mstore(0x20, amount)
            pop(call(gas(), WSTETH, 0, 0x1c, 0x24, codesize(), 0x00))
            mstore(0x14, address())
            mstore(0x00, 0x70a08231000000000000000000000000)
            pop(staticcall(gas(), WSTETH, 0x10, 0x24, 0x00, 0x20))
            wstOut := mload(0x00)
        }
        (, int256 amount1) = IV3Swap(POOL).swap(
            address(this),
            true,
            int256(wstOut),
            MIN_SQRT_RATIO_PLUS_ONE,
            abi.encodePacked(true, true, false, msg.sender, to)
        );
        require(uint256(-amount1) >= minOut, Slippage());
    }

    function swapExactWSTETHtoETH(address to, uint256 amount, uint256 minOut) public {
        (, int256 amount1) = IV3Swap(POOL).swap(
            address(this),
            true,
            int256(amount),
            MIN_SQRT_RATIO_PLUS_ONE,
            abi.encodePacked(true, false, false, msg.sender, to)
        );
        require(uint256(-amount1) >= minOut, Slippage());
    }

    // **** EXACT OUT - REFUND EXCESS IN

    function swapETHToExactWSTETH(address to, uint256 exactOut) public payable {
        (, int256 amount1) = IV3Swap(POOL).swap(
            to,
            false,
            -int256(exactOut),
            MAX_SQRT_RATIO_MINUS_ONE,
            abi.encodePacked(false, false, true, msg.sender, to)
        );
        assembly ("memory-safe") {
            if gt(callvalue(), amount1) {
                pop(
                    call(
                        gas(),
                        caller(),
                        sub(callvalue(), amount1),
                        codesize(),
                        0x00,
                        codesize(),
                        0x00
                    )
                )
            }
        }
    }

    /// @dev note: adjust `maxIn` on the WSTETH basis - this is for onchain simplicity
    function swapSTETHtoExactETH(address to, uint256 exactOut, uint256 maxIn) public {
        (int256 amount0,) = IV3Swap(POOL).swap(
            address(this),
            true,
            -int256(exactOut),
            MIN_SQRT_RATIO_PLUS_ONE,
            abi.encodePacked(true, true, true, msg.sender, to)
        );
        require(uint256(amount0) <= maxIn, Slippage());
    }

    function swapWSTETHtoExactETH(address to, uint256 exactOut, uint256 maxIn) public {
        (int256 amount0,) = IV3Swap(POOL).swap(
            address(this),
            true,
            -int256(exactOut),
            MIN_SQRT_RATIO_PLUS_ONE,
            abi.encodePacked(true, false, true, msg.sender, to)
        );
        require(uint256(amount0) <= maxIn, Slippage());
    }

    receive() external payable {}

    error Unauthorized();

    /// @dev `uniswapV3SwapCallback`
    fallback() external payable {
        unchecked {
            int256 amount0Delta;
            int256 amount1Delta;
            bool zeroForOne;
            bool fromSteth;
            bool exactOut;
            address payer;
            address to;
            assembly ("memory-safe") {
                amount0Delta := calldataload(0x4)
                amount1Delta := calldataload(0x24)
                zeroForOne := byte(0, calldataload(0x84))
                fromSteth := byte(0, calldataload(add(0x84, 1)))
                exactOut := byte(0, calldataload(add(0x84, 2)))
                payer := shr(96, calldataload(add(0x84, 3)))
                to := shr(96, calldataload(add(0x84, 23)))
            }
            require(msg.sender == POOL, Unauthorized());
            if (!zeroForOne) {
                assembly ("memory-safe") {
                    pop(call(gas(), WETH, amount1Delta, codesize(), 0x00, codesize(), 0x00))
                    mstore(0x00, 0xa9059cbb000000000000000000000000)
                    mstore(0x14, POOL)
                    mstore(0x34, amount1Delta)
                    pop(call(gas(), WETH, 0, 0x10, 0x44, codesize(), 0x00))
                }
            } else {
                if (!fromSteth) {
                    assembly ("memory-safe") {
                        let m := mload(0x40)
                        mstore(0x60, amount0Delta)
                        mstore(0x40, POOL)
                        mstore(0x2c, shl(96, payer))
                        mstore(0x0c, 0x23b872dd000000000000000000000000)
                        pop(call(gas(), WSTETH, 0, 0x1c, 0x64, 0x00, 0x20))
                        mstore(0x40, m)
                    }
                } else {
                    if (!exactOut) {
                        assembly ("memory-safe") {
                            mstore(0x00, 0xa9059cbb000000000000000000000000)
                            mstore(0x14, POOL)
                            mstore(0x34, amount0Delta)
                            pop(call(gas(), WSTETH, 0, 0x10, 0x44, codesize(), 0x00))
                        }
                    } else {
                        assembly ("memory-safe") {
                            mstore(0x00, 0xd5002f2e000000000000000000000000)
                            pop(staticcall(gas(), STETH, 0x10, 0x04, 0x00, 0x20))
                            let S := mload(0x00)
                            mstore(0x00, 0x37cfdaca000000000000000000000000)
                            pop(staticcall(gas(), STETH, 0x10, 0x04, 0x00, 0x20))
                            let z := mul(amount0Delta, mload(0x00))
                            let stNeeded := add(iszero(iszero(mod(z, S))), div(z, S))
                            let m := mload(0x40)
                            mstore(0x60, stNeeded)
                            mstore(0x40, address())
                            mstore(0x2c, shl(96, payer))
                            mstore(0x0c, 0x23b872dd000000000000000000000000)
                            pop(call(gas(), STETH, 0, 0x1c, 0x64, 0x00, 0x20))
                            mstore(0x40, m)
                            mstore(0x00, 0xea598cb0)
                            mstore(0x20, stNeeded)
                            pop(call(gas(), WSTETH, 0, 0x1c, 0x24, codesize(), 0x00))
                            mstore(0x00, 0xa9059cbb000000000000000000000000)
                            mstore(0x14, POOL)
                            mstore(0x34, amount0Delta)
                            pop(call(gas(), WSTETH, 0, 0x10, 0x44, codesize(), 0x00))
                        }
                    }
                }
                uint256 amountOut = uint256(-(amount1Delta));
                assembly ("memory-safe") {
                    mstore(0x00, 0x2e1a7d4d)
                    mstore(0x20, amountOut)
                    pop(call(gas(), WETH, 0, 0x1c, 0x24, codesize(), 0x00))
                    pop(call(gas(), to, amountOut, codesize(), 0x00, codesize(), 0x00))
                }
            }
        }
    }
}

address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant POOL = 0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa;

uint160 constant MIN_SQRT_RATIO_PLUS_ONE = 4295128740;
uint160 constant MAX_SQRT_RATIO_MINUS_ONE = 1461446703485210103287273052203988822378723970341;

interface IV3Swap {
    function swap(address, bool, int256, uint160, bytes calldata)
        external
        returns (int256, int256);
}

interface IERC20 {
    function approve(address, uint256) external returns (bool);
}
