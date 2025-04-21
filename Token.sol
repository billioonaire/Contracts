pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Token is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public constant deadAddress = address(0xdead);

    bool private swapping;

    address private taxWallet;

    uint256 public convertAtAmount;
    uint256 public maxSwapAmount;

    bool public stageLaunch = true;

    bool public limitsInEffect = true;
    bool public tradingActive = false;
    bool public swapEnabled = false;

    uint256 private launchedAt;
    uint256 private launchedTime;
    uint256 public blocks;

    uint256 public buyTotalFees;
    uint256 public sellTotalFees;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public _isExcludedMaxTransactionAmount;
    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(uint256 => uint256) private blockSwaps;

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event TaxWalletUpdated(address indexed newWallet, address indexed oldWallet);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);

    constructor() ERC20("Token", "T") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        excludeFromMaxTransaction(address(_uniswapV2Router), true);
        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        excludeFromMaxTransaction(address(uniswapV2Pair), true);
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        uint256 totalSupply = 100_000_000 * 1e18;

        maxSwapAmount = 250_000 * 1e18;
        convertAtAmount = 250_000 * 1e18;

        taxWallet = msg.sender;

        _mint(address(this), totalSupply); 

        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);

        excludeFromMaxTransaction(owner(), true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(0xdead), true);
    }

    receive() external payable {}

    function openTrading() external payable onlyOwner {
        _approve(address(this), address(uniswapV2Router), totalSupply());
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);

        tradingActive = true;
        swapEnabled = true;
        launchedAt = block.number;
        launchedTime = block.timestamp;

        // Set initial high fees
        buyTotalFees = 20;
        sellTotalFees = 40;

    }


    function removeLimits() external onlyOwner {
        limitsInEffect = false;
    }

    function updateConvertAtAmount(uint256 newAmount) external {

        require(_msgSender() == taxWallet);
        convertAtAmount = newAmount * (10 ** 18);

    }

    function updateMaxSwap(uint256 newAmount) external {
        require(_msgSender() == taxWallet);
        maxSwapAmount = newAmount * (10 ** 18);

    }


    function whitelistContract(address _whitelist, bool isWL) public onlyOwner {
        _isExcludedMaxTransactionAmount[_whitelist] = isWL;

        _isExcludedFromFees[_whitelist] = isWL;
    }

    function excludeFromMaxTransaction(address updAds, bool isEx) public onlyOwner {
        _isExcludedMaxTransactionAmount[updAds] = isEx;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function maxWallet() public view returns(uint256) {
        if (stageLaunch) {
            return totalSupply();
        }

        uint256 elapsedBlocks = block.number - launchedAt;

        if (elapsedBlocks <= 60) {
            uint256 incrementalMaxWallet = (elapsedBlocks * 25 * totalSupply()) / (60 * 10000);
            return incrementalMaxWallet;
        } else {
            return (25 * totalSupply()) / 10000;
        }
    }

    
    function setStage() external onlyOwner {
        stageLaunch = false;
    }

    function manualswap(uint256 amount) external {
        require(_msgSender() == taxWallet);
        require(amount <= balanceOf(address(this)) && amount > 0, "Wrong amount");
        swapTokensForEth(amount);
    }

    function emptyETH() external {
        address(taxWallet).call{value: address(this).balance}("");
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "The pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateFees(uint256 _swapFee) external onlyOwner {
        require(_swapFee < buyTotalFees, "Cannot Raise Buy Taxes");
        require(_swapFee < sellTotalFees, "Cannot Raise Sell Taxes");

        buyTotalFees = _swapFee;
        sellTotalFees = _swapFee;

    }

    function updateBuyFees(uint256 _swapFee) external onlyOwner {
        require(_swapFee < buyTotalFees, "Cannot Raise Buy Taxes");
        buyTotalFees = _swapFee;
    }

    function updateSellFees(uint256 _swapFee) external onlyOwner {
        require(_swapFee < sellTotalFees, "Cannot Raise Sell Tax");
        sellTotalFees = _swapFee;
    }

    function updateTaxWallet(address newtaxWallet) external onlyOwner {
        emit TaxWalletUpdated(newtaxWallet, taxWallet);
        taxWallet = newtaxWallet;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
    require(from != address(0), "ERC20: transfer from the zero address");
    require(to != address(0), "ERC20: transfer to the zero address");

    if (amount == 0) {
        super._transfer(from, to, 0);
        return;
    }

    if (limitsInEffect) {
        if (from != owner() && to != owner() && to != address(0) && to != address(0xdead) && !swapping) {
            if (!tradingActive) {
                require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "Trading is not active.");
            }

            // When buying
            if (automatedMarketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) {
                require(amount + balanceOf(to) <= maxWallet(), "Max wallet exceeded");
            }

            // When selling or transferring
            if (!_isExcludedMaxTransactionAmount[to]) {
                require(amount + balanceOf(to) <= maxWallet(), "Max wallet exceeded");
            }
        }
    }

    uint256 contractTokenBalance = balanceOf(address(this));

    bool canSwap = contractTokenBalance >= convertAtAmount;

    if (
        canSwap && swapEnabled && !swapping && !automatedMarketMakerPairs[from] && !_isExcludedFromFees[from]
            && !_isExcludedFromFees[to]
    ) {
        // Limit swaps
        if (blockSwaps[block.number] < 3) {
            swapping = true;

            swapBack();

            swapping = false;

            blockSwaps[block.number] = blockSwaps[block.number] + 1;
        }
    }

    bool takeFee = !swapping;

    // If any account belongs to _isExcludedFromFee account, then remove the fee
    if (_isExcludedFromFees[from] || _isExcludedFromFees[to] || stageLaunch) {
        takeFee = false;
    }

    uint256 fees = 0;

    // Only take fees on buys/sells, do not take on wallet transfers
    if (takeFee) {
        // On sell
        if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
            fees = amount.mul(sellTotalFees).div(100);
        }
        // On buy
        else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
            fees = amount.mul(buyTotalFees).div(100);
        }

        if (fees > 0) {
            super._transfer(from, address(this), fees);
        }

        amount = amount.sub(fees);
    }

    super._transfer(from, to, amount);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        bool success;

        if (contractBalance == 0) {
            return;
        }

        if (contractBalance > maxSwapAmount) {
            contractBalance = maxSwapAmount;
        }

        // Halve the amount of liquidity tokens

        uint256 amountToSwapForETH = contractBalance;

        swapTokensForEth(amountToSwapForETH);

        uint256 totalETH = address(this).balance;

        (success,) = address(taxWallet).call{value: totalETH}("");
    }
}
