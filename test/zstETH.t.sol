// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {STETH, WSTETH, ZstETH} from "../src/ZstETH.sol";

address constant ZROUTER = 0x0000000000404FECAf36E6184245475eE1254835;

interface IZROUTER {
    function swapV3(
        address to,
        bool exactOut,
        uint24 swapFee,
        address tokenIn,
        address tokenOut,
        uint256 swapAmount,
        uint256 amountLimit,
        uint256 deadline
    ) external payable returns (uint256 amountIn, uint256 amountOut);
}

contract StakerTest is Test {
    ZstETH internal staker;

    function setUp() public payable {
        vm.createSelectFork(vm.rpcUrl("main"));
        staker = new ZstETH();
    }

    function testExactETHToSTETH() public payable {
        uint256 out = staker.exactETHToSTETH{value: 1 ether}(address(this));
        uint256 bal = IERC20(STETH).balanceOf(address(this));
        console.log(out);
        console.log(bal);
    }

    function testExactETHToWSTETH() public payable {
        uint256 out = staker.exactETHToWSTETH{value: 1 ether}(address(this));
        uint256 bal = IERC20(WSTETH).balanceOf(address(this));
        console.log(out);
        console.log(bal);
    }

    function testExactETHToWSTETH_ZROUTER() public payable {
        (, uint256 out) = IZROUTER(ZROUTER).swapV3{value: 1 ether}(
            address(this), false, 100, address(0), WSTETH, 1 ether, 0, block.timestamp + 30 minutes
        );
        uint256 bal = IERC20(WSTETH).balanceOf(address(this));
        console.log(out);
        console.log(bal);
    }

    function testExactETHToWSTETH_1000_ETH() public payable {
        uint256 out = staker.exactETHToWSTETH{value: 1000 ether}(address(this));
        uint256 bal = IERC20(WSTETH).balanceOf(address(this));
        console.log(out);
        console.log(bal);
    }

    function testExactETHToWSTETH_ZROUTER_1000_ETH() public payable {
        (, uint256 out) = IZROUTER(ZROUTER).swapV3{value: 1000 ether}(
            address(this),
            false,
            100,
            address(0),
            WSTETH,
            1000 ether,
            0,
            block.timestamp + 30 minutes
        );
        uint256 bal = IERC20(WSTETH).balanceOf(address(this));
        console.log(out);
        console.log(bal);
    }

    function testETHToExactSTETH() public payable {
        uint256 before = address(staker).balance;
        staker.ethToExactSTETH{value: 1 ether}(address(this), 0.3 ether);
        uint256 bal = IERC20(STETH).balanceOf(address(this));
        console.log(bal);
        console.log(address(staker).balance - before);
    }

    function testETHToExactWSTETH() public payable {
        uint256 before = address(staker).balance;
        staker.ethToExactWSTETH{value: 1 ether}(address(this), 0.3 ether);
        uint256 bal = IERC20(WSTETH).balanceOf(address(this));
        console.log(bal);
        console.log(address(staker).balance - before);
    }

    receive() external payable {}

    // ---------- helpers ----------
    function _approveMax() internal {
        IERC20Approve(STETH).approve(address(staker), type(uint256).max);
        IERC20Approve(WSTETH).approve(address(staker), type(uint256).max);
    }

    function _getSTETH(uint256 ethIn) internal returns (uint256) {
        return staker.exactETHToSTETH{value: ethIn}(address(this));
    }

    function _getWSTETH(uint256 ethIn) internal returns (uint256) {
        return staker.exactETHToWSTETH{value: ethIn}(address(this));
    }

    // ---------- swap: exact in -> max out ----------

    function testSwapExactETHToWSTETH() public payable {
        uint256 before = IERC20(WSTETH).balanceOf(address(this));
        staker.swapExactETHToWSTETH{value: 1 ether}(address(this), 0);
        uint256 afterBal = IERC20(WSTETH).balanceOf(address(this));
        uint256 out = afterBal - before;

        console.log("swapExactETHToWSTETH out (wstETH):", out);
        assertGt(out, 0);

        // ZstETH should not retain tokens
        assertEq(IERC20(WSTETH).balanceOf(address(staker)), 0);
        assertEq(IERC20(STETH).balanceOf(address(staker)), 0);
    }

    function testSwapExactETHToWSTETH_SlippageReverts() public {
        vm.expectRevert(ZstETH.Slippage.selector);
        staker.swapExactETHToWSTETH{value: 1 ether}(address(this), type(uint256).max);
    }

    function testSwapExactSTETHtoETH() public payable {
        _approveMax();

        _getSTETH(1 ether);
        uint256 stEthIn = IERC20(STETH).balanceOf(address(this));
        uint256 ethBefore = address(this).balance;

        staker.swapExactSTETHtoETH(address(this), stEthIn, 0);

        uint256 ethAfter = address(this).balance;
        uint256 ethGained = ethAfter - ethBefore;

        console.log("swapExactSTETHtoETH STETH in:", stEthIn);
        console.log("swapExactSTETHtoETH ETH gained:", ethGained);
        assertGt(ethGained, 0);
        assertEq(IERC20(WSTETH).balanceOf(address(staker)), 0);
        assertEq(IERC20(STETH).balanceOf(address(staker)), 0);
    }

    function testSwapExactSTETHtoETH_SlippageReverts() public payable {
        _approveMax();
        uint256 stEthIn = _getSTETH(0.5 ether);
        vm.expectRevert(ZstETH.Slippage.selector);
        staker.swapExactSTETHtoETH(address(this), stEthIn, type(uint256).max);
    }

    function testSwapExactWSTETHtoETH() public payable {
        _approveMax();
        uint256 wstIn = _getWSTETH(1 ether);
        uint256 ethBefore = address(this).balance;

        staker.swapExactWSTETHtoETH(address(this), wstIn, 0);

        uint256 ethAfter = address(this).balance;
        uint256 ethGained = ethAfter - ethBefore;

        console.log("swapExactWSTETHtoETH wstETH in:", wstIn);
        console.log("swapExactWSTETHtoETH ETH gained:", ethGained);
        assertGt(ethGained, 0);
        assertEq(IERC20(WSTETH).balanceOf(address(staker)), 0);
        assertEq(IERC20(STETH).balanceOf(address(staker)), 0);
    }

    // ---------- swap: exact out ----------

    function testSwapETHToExactWSTETH_refundsExcessETH() public payable {
        uint256 targetOut = 0.1 ether; // 0.1 wstETH out
        uint256 wstBefore = IERC20(WSTETH).balanceOf(address(this));
        uint256 ethBefore = address(this).balance;

        staker.swapETHToExactWSTETH{value: 1 ether}(address(this), targetOut);

        uint256 wstAfter = IERC20(WSTETH).balanceOf(address(this));
        uint256 ethAfter = address(this).balance;

        uint256 wstGained = wstAfter - wstBefore;
        uint256 ethSpent = ethBefore - ethAfter; // gasprice is 0 by default in Foundry mainnet fork

        console.log("swapETHToExactWSTETH wstETH target out:", targetOut);
        console.log("swapETHToExactWSTETH wstETH gained:", wstGained);
        console.log("swapETHToExactWSTETH ETH spent:", ethSpent);
        console.log("swapETHToExactWSTETH ETH refunded:", 1 ether - ethSpent);

        assertEq(wstGained, targetOut);
        assertLt(ethSpent, 1 ether); // refund happened
        assertEq(IERC20(WSTETH).balanceOf(address(staker)), 0);
        assertEq(IERC20(STETH).balanceOf(address(staker)), 0);
    }

    function testSwapSTETHtoExactETH() public payable {
        _approveMax();
        _getSTETH(1 ether); // mint some stETH to us

        uint256 exactOut = 0.2 ether;
        uint256 ethBefore = address(this).balance;

        // generous maxIn, rely on contract's internal <= maxIn guard
        staker.swapSTETHtoExactETH(address(this), exactOut, type(uint256).max);

        uint256 ethAfter = address(this).balance;
        uint256 ethGained = ethAfter - ethBefore;

        console.log("swapSTETHtoExactETH ETH exact out:", exactOut);
        console.log("swapSTETHtoExactETH ETH gained:", ethGained);

        // In Foundry the default tx gasPrice is 0, so this should be exact:
        assertEq(ethGained, exactOut);

        assertEq(IERC20(WSTETH).balanceOf(address(staker)), 0);
        assertEq(IERC20(STETH).balanceOf(address(staker)), 0);
    }

    function testSwapWSTETHtoExactETH() public payable {
        _approveMax();
        _getWSTETH(1 ether);

        uint256 exactOut = 0.2 ether;
        uint256 ethBefore = address(this).balance;

        staker.swapWSTETHtoExactETH(address(this), exactOut, type(uint256).max);

        uint256 ethAfter = address(this).balance;
        uint256 ethGained = ethAfter - ethBefore;

        console.log("swapWSTETHtoExactETH ETH exact out:", exactOut);
        console.log("swapWSTETHtoExactETH ETH gained:", ethGained);
        assertEq(ethGained, exactOut);

        assertEq(IERC20(WSTETH).balanceOf(address(staker)), 0);
        assertEq(IERC20(STETH).balanceOf(address(staker)), 0);
    }

    // ---------- callback guard ----------

    function testFallbackUnauthorizedReverts() public {
        // simulate calling fallback without being the pool
        bytes memory bogus = abi.encodeWithSelector(
            bytes4(keccak256("uniswapV3SwapCallback(int256,int256,bytes)")),
            int256(1),
            int256(1),
            hex""
        );
        vm.expectRevert(ZstETH.Unauthorized.selector);
        (bool ok,) = address(staker).call(bogus);
        ok; // silence var
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IERC20Approve {
    function approve(address, uint256) external returns (bool);
}
