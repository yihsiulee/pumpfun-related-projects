// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";  // Use UD60x18 type and ud() constructor


interface IVistaFactory {
    function getPair(address tokenA, address tokenB) external view returns (address);
}

interface IPair {
    function claimShare() external;
    function viewShare() external view returns (uint256 share);
}

interface ILaunchContract {
    function launch(
        address token,
        uint256 amountTokenDesired,
        uint256 amountETHMin,
        uint256 amountTokenMin,
        uint8 buyLpFee,
        uint8 sellLpFee,
        uint8 buyProtocolFee,
        uint8 sellProtocolFee,
        address protocolAddress
    ) external payable;
}

contract EtherfunSale is ReentrancyGuard, ERC20 {
    //using UD60x18 for uint256;

    //address public token;
    address public creator;
    address public factory;
    uint256 public totalTokens;
    uint256 public totalRaised;
    uint256 public maxContribution;
    uint8 public creatorshare;
    bool public launched;
    bool public status;
    uint256 public k; // Initial price factor
    uint256 public alpha; // Steepness factor for bonding curve
    uint256 public saleGoal; // Sale goal in ETH
    uint256 public tokensSold; // Track the number of tokens sold, initially 0
    mapping(address => uint256) public tokenBalances; // Track user token balances (not actual tokens)

    address[] public tokenHolders;
    mapping(address => bool) public isTokenHolder;

    address public wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public vistaFactoryAddress = 0x9a27cb5ae0B2cEe0bb71f9A85C0D60f3920757B4;
    uint256 public feePercent;
    address public feeWallet = 0xc07DFf4C8c129aA8FA8b91CC67d74AEd77e4feF1;

    struct HistoricalData {
        uint256 timestamp;
        uint256 totalRaised;
    }
    HistoricalData[] public historicalData;

    event TokensPurchased(
        address indexed buyer,
        uint256 ethAmount,
        uint256 tokenAmount,
        uint256 timestamp
    );
    
    event TokensSold(
        address indexed seller,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 timestamp
    );


    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        address _creator,
        address _factory,
        uint256 _totalTokens,
        uint256 _k, // Initial price factor
        uint256 _alpha, // Steepness of bonding curve
        uint256 _saleGoal, // ETH goal for sale
        uint8 _creatorshare,
        uint256 _feePercent
    ) ERC20(name, symbol) {
        creator = _creator;
        factory = _factory;
        totalTokens = _totalTokens;
        k = _k;
        alpha = _alpha;
        saleGoal = _saleGoal;
        creatorshare = _creatorshare;
        feePercent = _feePercent;

        tokensSold = 0; // Initialize tokensSold to 0
        _mint(address(this), _totalTokens);

        //EtherfunToken newToken = new EtherfunToken(name, symbol, _totalTokens, address(this));
        //token = address(newToken);
    }

    function getEthIn(uint256 tokenAmount) public view returns (uint256) {
        UD60x18 soldTokensFixed = ud(tokensSold);
        UD60x18 tokenAmountFixed = ud(tokenAmount);
        UD60x18 kFixed = ud(k);
        UD60x18 alphaFixed = ud(alpha);

        // Calculate ethBefore = k * (exp(alpha * tokensSold) - 1)
        UD60x18 ethBefore = kFixed.mul(alphaFixed.mul(soldTokensFixed).exp()).sub(kFixed);

        // Calculate ethAfter = k * (exp(alpha * (tokensSold - tokenAmount)) - 1)
        UD60x18 ethAfter = kFixed.mul(alphaFixed.mul(soldTokensFixed.sub(tokenAmountFixed)).exp()).sub(kFixed);

        // Return the difference in Wei (ETH)
        return ethBefore.sub(ethAfter).unwrap();
    }

    // Function to calculate the number of tokens for a given ETH amount
    function getTokenIn(uint256 ethAmount) public view returns (uint256) {
        UD60x18 totalRaisedFixed = ud(totalRaised);
        UD60x18 ethAmountFixed = ud(ethAmount);
        UD60x18 kFixed = ud(k);
        UD60x18 alphaFixed = ud(alpha);

        // Calculate tokensBefore = ln((totalRaised / k) + 1) / alpha
        UD60x18 tokensBefore = totalRaisedFixed.div(kFixed).add(ud(1e18)).ln().div(alphaFixed);

        // Calculate tokensAfter = ln(((totalRaised + ethAmount) / k) + 1) / alpha
        UD60x18 tokensAfter = totalRaisedFixed.add(ethAmountFixed).div(kFixed).add(ud(1e18)).ln().div(alphaFixed);

        // Return the difference in tokens
        return tokensAfter.sub(tokensBefore).unwrap();
    }

    // Optimized buy function with direct fee distribution
    function buy(address user, uint256 minTokensOut) external payable onlyFactory nonReentrant returns (uint256, uint256) {
        require(!launched, "Sale already launched");
        require(totalRaised + msg.value <= saleGoal + 0.1 ether, "Sale goal reached");
        require(msg.value > 0, "No ETH sent");
        require(!status, "bonded");

        // Calculate the fee and amount after fee deduction
        uint256 fee = (msg.value * feePercent) / 100;
        uint256 amountAfterFee = msg.value - fee;

        // Calculate tokens to buy with amountAfterFee
        uint256 tokensToBuy = getTokenIn(amountAfterFee);
        require(tokensToBuy >= minTokensOut, "Slippage too high, transaction reverted");

        tokensSold += tokensToBuy;
        totalRaised += amountAfterFee;

        tokenBalances[user] += tokensToBuy;

        if (!isTokenHolder[user]) {
            tokenHolders.push(user);
            isTokenHolder[user] = true;
        }

        payable(feeWallet).transfer(fee / 2);
        payable(0x4C5fbF8D815379379b3695ba77B5D3f898C1230b).transfer(fee / 2);

        if (totalRaised >= saleGoal) {
            status = true;
        }

        updateHistoricalData();

        emit TokensPurchased(
            user,
            amountAfterFee,
            tokensToBuy,
            block.timestamp
        );

        return (totalRaised, tokenBalances[user]);
    }

    // Optimized sell function with direct fee distribution
    function sell(address user, uint256 tokenAmount, uint256 minEthOut) external onlyFactory nonReentrant returns (uint256, uint256) {
        require(!launched, "Sale already launched");
        require(tokenAmount > 0, "Token amount must be greater than 0");
        require(tokenBalances[user] >= tokenAmount, "Insufficient token balance");
        require(!status, "bonded");

        uint256 ethToReturn = getEthIn(tokenAmount);
        require(ethToReturn >= minEthOut, "Slippage too high, transaction reverted");
        require(ethToReturn <= address(this).balance, "Insufficient contract balance");

        // Calculate the fee and amount after fee deduction
        uint256 fee = (ethToReturn * feePercent) / 100;
        uint256 ethAfterFee = ethToReturn - fee;

        tokensSold -= tokenAmount;
        totalRaised -= ethToReturn;

        tokenBalances[user] -= tokenAmount;

        // Transfer ETH after fee to the user
        payable(user).transfer(ethAfterFee);

        payable(feeWallet).transfer(fee / 2);
        payable(0x4C5fbF8D815379379b3695ba77B5D3f898C1230b).transfer(fee / 2);
    

        updateHistoricalData();

        emit TokensSold(
            user,
            tokenAmount,
            ethAfterFee,
            block.timestamp
        );

        return (totalRaised, tokenBalances[user]);
    }

    function updateHistoricalData() internal {
        historicalData.push(HistoricalData({
            timestamp: block.timestamp,
            totalRaised: totalRaised
        }));
        //emit HistoricalDataUpdated(block.timestamp, totalRaised);
    }

    // Launch the sale, users can claim their tokens after launch
    function launchSale(
        address _launchContract,
        uint8 buyLpFee,
        uint8 sellLpFee,
        uint8 buyProtocolFee,
        uint8 sellProtocolFee,
        address firstBuyer,
        address saleInitiator
    ) external onlyFactory nonReentrant {
        require(!launched, "Sale already launched");
        require(totalRaised >= saleGoal, "Sale goal not reached");
        require(status, "not bonded");
        launched = true;

        uint256 tokenAmount = (totalTokens - tokensSold);
        uint256 ethAmount = totalRaised;

        uint256 launchEthAmount = ((100 - creatorshare) * ethAmount) / 100;

        _approve(address(this), _launchContract, tokenAmount);


        ILaunchContract(_launchContract).launch{value: launchEthAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            buyLpFee,
            sellLpFee,
            buyProtocolFee,
            sellProtocolFee,
            creator
        );

        uint256 creatorShareAmount = address(this).balance;
        require(creatorShareAmount > 0, "No balance for creator share");

        payable(firstBuyer).transfer(creatorShareAmount/2);
        payable(saleInitiator).transfer(creatorShareAmount/2);
        

    }

    // Claim tokens after the sale is launched
    function claimTokens(address user) external onlyFactory nonReentrant {
        require(launched, "Sale not launched");
        uint256 tokenAmount = tokenBalances[user];
        require(tokenAmount > 0, "No tokens to claim");

        tokenBalances[user] = 0;

        _transfer(address(this), user, tokenAmount);
    }

    function getTokenHoldersCount() external view returns (uint256) {
        return tokenHolders.length;
    }

    function getAllTokenHolders() external view returns (address[] memory) {
        return tokenHolders;
    }

    function getAllHistoricalData() external view returns (HistoricalData[] memory) {
        return historicalData;
    }

    function takeFee(address lockFactoryOwner) external onlyFactory nonReentrant {
        IVistaFactory vistaFactory = IVistaFactory(vistaFactoryAddress);
        address pairAddress = vistaFactory.getPair(address(this), wethAddress);

        require(pairAddress != address(0), "Pair not found");

        IPair pair = IPair(pairAddress);
        pair.claimShare();

        uint256 claimedEth = address(this).balance;
        require(claimedEth > 0, "No ETH claimed");

        uint256 fee1 = claimedEth/2;
        uint256 fee2 = claimedEth-fee1;

        payable(lockFactoryOwner).transfer(fee1);
        payable(0x4C5fbF8D815379379b3695ba77B5D3f898C1230b).transfer(fee2);
    }

    function getShare() external view returns (uint256) {
        IVistaFactory vistaFactory = IVistaFactory(vistaFactoryAddress);
        address pairAddress = vistaFactory.getPair(address(this), wethAddress);

        return IPair(pairAddress).viewShare();
    }

    receive() external payable {}
}
