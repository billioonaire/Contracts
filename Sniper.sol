// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Address.sol";

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
}

contract CoinSniper {
    mapping(address => address[]) private userWallets;
    mapping(address => uint256) private lastExecutionTime;

    uint256 private constant UNLOCKED = 1;
    uint256 private constant LOCKED = 2;
    uint256 private lockStatus = UNLOCKED;
    uint256 private constant COOLDOWN_PERIOD = 1 minutes;

    modifier nonReentrant() {
        require(lockStatus == UNLOCKED, "Reentrant call");
        lockStatus = LOCKED;
        _;
        lockStatus = UNLOCKED;
    }

    modifier cooldown() {
        require(block.timestamp >= lastExecutionTime[msg.sender] + COOLDOWN_PERIOD, "Cooldown period not elapsed");
        _;
        lastExecutionTime[msg.sender] = block.timestamp;
    }

    constructor() {}

    fallback() external payable { }
    receive() external payable {}

    function storeWallets(address[] calldata _wallets) external {
        userWallets[msg.sender] = _wallets;
    }

    function getUserWallets() external view returns (address[] memory) {
        return userWallets[msg.sender];
    }

    function checkSwapPossible(
        IUniswapV2Router02 router,
        address tokenAddress,
        uint256 amountETH,
        uint256 minBps
    ) public view returns (bool) {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = tokenAddress;

        try router.getAmountsOut(amountETH, path) returns (uint[] memory amounts) {
            if (amounts.length != 2 || amounts[1] == 0) return false;
            uint256 tokenSupply = IERC20(tokenAddress).totalSupply();
            uint256 minTokens = (tokenSupply * minBps) / 10000;
            return amounts[1] >= minTokens;
        } catch {
            return false;
        }
    }

    function checkTaxes(
        IUniswapV2Router02 router,
        address tokenAddress,
        uint256 maxBuyTax,
        uint256 maxSellTax
    ) private returns (bool) {
        uint256 testAmount = 1e15;
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = tokenAddress;

        uint256 expectedOutput = router.getAmountsOut(testAmount, path)[1];
        uint256 balanceBefore = IERC20(tokenAddress).balanceOf(address(this));

        router.swapExactETHForTokens{value: testAmount}(0, path, address(this), block.timestamp + 60);

        uint256 receivedAmount = IERC20(tokenAddress).balanceOf(address(this)) - balanceBefore;
        uint256 buyTax = ((expectedOutput - receivedAmount) * 10000) / expectedOutput;
        if (buyTax > maxBuyTax) {
            return false;
        }

        IERC20(tokenAddress).approve(address(router), receivedAmount);
        path[0] = tokenAddress;
        path[1] = router.WETH();

        uint256 expectedETH = router.getAmountsOut(receivedAmount, path)[1];
        uint256 ethBalanceBefore = address(this).balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            receivedAmount, 0, path, address(this), block.timestamp + 60
        );

        uint256 receivedETH = address(this).balance - ethBalanceBefore;
        uint256 sellTax = ((expectedETH - receivedETH) * 10000) / expectedETH;
        if (sellTax > maxSellTax) {
            return false;
        }

        return true;
    }

    function _performSwap(
        IUniswapV2Router02 router,
        address tokenAddress,
        uint256 ethAmount,
        address recipient
    ) private returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = tokenAddress;

        uint256[] memory amounts = router.swapExactETHForTokens{value: ethAmount}(
            0, path, recipient, block.timestamp + 180
        );

        return amounts[1];
    }

function snipeEthV2(
        address tokenAddress,
        address dex,
        uint256 minBps,
        uint256 minLoops,
        uint256 maxBuyTax,
        uint256 maxSellTax,
        uint256 bribeAmount,
        bool protected,
        bool spamming
    ) external payable nonReentrant cooldown {
        require(msg.value > 0, "No ETH sent for snipe");

        IUniswapV2Router02 router = IUniswapV2Router02(dex);
        uint256 totalBribeAmount = bribeAmount * 10**16;
        uint256 ethForSwap = msg.value - totalBribeAmount;

        require(checkSwapPossible(router, tokenAddress, ethForSwap, minBps), "Swap not possible or insufficient output");
        if (protected) {
            require(checkTaxes(router, tokenAddress, maxBuyTax, maxSellTax), "Tax check failed");
        }


            _performSwap(router, tokenAddress, ethForSwap, msg.sender);
            
            payable(block.coinbase).transfer(totalBribeAmount * 10**16);
        

        uint256 remainingBalance = address(this).balance;
        if (remainingBalance > 0) {
            payable(msg.sender).transfer(remainingBalance);
        }
    }

}