// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "./SaleContract.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ISaleContract {
    function buy(address user, uint256 minTokensOut) external payable returns (uint256, uint256);
    function sell(address user, uint256 tokenAmount, uint256 minEthOut) external returns (uint256, uint256);
    function claimTokens(address user) external;
    function launchSale(
        address _launchContract,
        uint8 buyLpFee,
        uint8 sellLpFee,
        uint8 buyProtocolFee,
        uint8 sellProtocolFee,
        address firstBuyer,
        address saleInitiator
    ) external;
    function takeFee(address lockFactoryOwner) external;
    function token() external view returns (address);
}

contract EtherFunFactory is ReentrancyGuard {
    address public owner;

    address public launchContractAddress = 0xCEDd366065A146a039B92Db35756ecD7688FCC77;
    uint256 public saleCounter;

    uint256 public totalTokens = 1000000000 * 1e18;
    uint256 public defaultSaleGoal = 1.5 ether;
    uint8 public creatorshare = 4;
    uint8 public feepercent = 2;
    uint256 public defaultK = 222 * 1e15;
    uint256 public defaultAlpha = 2878 * 1e6;

    uint8 public buyLpFee = 5;
    uint8 public sellLpFee = 5;
    uint8 public buyProtocolFee = 5;
    uint8 public sellProtocolFee = 5;

    struct Sale {
        address creator;
        string name;
        string symbol;
        uint256 totalRaised;
        uint256 saleGoal;
        bool launched;
        uint256 creationNonce;
    }

    struct SaleMetadata {
        string logoUrl;
        string websiteUrl;
        string twitterUrl;
        string telegramUrl;
        string description; 
    }

    mapping(address => Sale) public sales;
    mapping(address => mapping(address => bool)) public hasClaimed;
    mapping(address => SaleMetadata) public saleMetadata;
    mapping(address => address[]) public userBoughtTokens;
    mapping(address => mapping(address => bool)) public userHasBoughtToken;
    mapping(address => uint256) creationNonce;
    mapping(address => address) public firstBuyer;
    mapping(address => address[]) public creatorTokens;


    event SaleCreated(
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol,
        uint256 saleGoal,
        string logoUrl,
        string websiteUrl, 
        string twitterUrl, 
        string telegramUrl, 
        string description
    );

    event SaleLaunched(address indexed tokenAddress, address indexed launcher);
    event Claimed(address indexed tokenAddress, address indexed claimant);
    event MetaUpdated(address indexed tokenAddress, string logoUrl, string websiteUrl, string twitterUrl, string telegramUrl, string description);
    event TokensBought(address indexed tokenAddress, address indexed buyer, uint256 totalRaised, uint256 tokenBalance);
    event TokensSold(address indexed tokenAddress, address indexed seller, uint256 totalRaised, uint256 tokenBalance);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlySaleCreator(address tokenAddress) {
        require(msg.sender == sales[tokenAddress].creator, "Not creator");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createSale(
        string memory name, 
        string memory symbol,
        string memory logoUrl,
        string memory websiteUrl,
        string memory twitterUrl,
        string memory telegramUrl,
        string memory description 
    ) external payable nonReentrant {
        creationNonce[msg.sender]++;
        uint256 currentNonce = creationNonce[msg.sender];
        address tokenAddress = predictTokenAddress(msg.sender, name, symbol, currentNonce);

        sales[tokenAddress] = Sale({
            creator: msg.sender,
            name: name,
            symbol: symbol,
            totalRaised: 0,
            saleGoal: defaultSaleGoal,
            launched: false,
            creationNonce: currentNonce  
        });

        saleMetadata[tokenAddress] = SaleMetadata({
            logoUrl: logoUrl,
            websiteUrl: websiteUrl,
            twitterUrl: twitterUrl,
            telegramUrl: telegramUrl,
            description: description 
        });

        creatorTokens[msg.sender].push(tokenAddress);
        saleCounter++;

        emit SaleCreated(
            tokenAddress,
            msg.sender,
            name,
            symbol,
            defaultSaleGoal,
            logoUrl, 
            websiteUrl, 
            twitterUrl, 
            telegramUrl, 
            description
        );

        if (msg.value > 0) {
            require(msg.value < 0.2 ether, "Too many tokens bought");

            bytes32 salt = keccak256(abi.encodePacked(msg.sender, currentNonce)); 
            
            bytes memory bytecode = abi.encodePacked(
                type(EtherfunSale).creationCode,
                abi.encode(
                    name,
                    symbol,
                    msg.sender,
                    address(this),
                    totalTokens,
                    defaultK,
                    defaultAlpha,
                    defaultSaleGoal,
                    creatorshare,
                    feepercent
                )
            );

            assembly {
                tokenAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
                if iszero(extcodesize(tokenAddress)) { revert(0, 0) }
            }

            firstBuyer[tokenAddress] = msg.sender; 

            uint256 minTokensOut = 0;
            (uint256 totalRaised, uint256 tokenBalance) = ISaleContract(tokenAddress).buy{value: msg.value}(msg.sender, minTokensOut);
            sales[tokenAddress].totalRaised = totalRaised;

            userBoughtTokens[msg.sender].push(tokenAddress);
            userHasBoughtToken[msg.sender][tokenAddress] = true;
        
            emit TokensBought(tokenAddress, msg.sender, totalRaised, tokenBalance);
        }
    }

    function buyToken(address tokenAddress, uint256 minTokensOut) external payable nonReentrant {
        Sale storage sale = sales[tokenAddress];
        require(!sale.launched, "Sale already launched");

        if (firstBuyer[tokenAddress] == address(0)) {
            bytes32 salt = keccak256(abi.encodePacked(sale.creator, sale.creationNonce)); 
            
            bytes memory bytecode = abi.encodePacked(
                type(EtherfunSale).creationCode,
                abi.encode(
                    sale.name,
                    sale.symbol,
                    sale.creator,
                    address(this),
                    totalTokens,
                    defaultK,
                    defaultAlpha,
                    defaultSaleGoal,
                    creatorshare,
                    feepercent
                )
            );

            assembly {
                tokenAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
                if iszero(extcodesize(tokenAddress)) { revert(0, 0) }
            }

            firstBuyer[tokenAddress] = msg.sender; 
        }

        (uint256 totalRaised, uint256 tokenBalance) = ISaleContract(tokenAddress).buy{value: msg.value}(msg.sender, minTokensOut);
        sale.totalRaised = totalRaised;

        if (!userHasBoughtToken[msg.sender][tokenAddress]) {
            userBoughtTokens[msg.sender].push(tokenAddress);
            userHasBoughtToken[msg.sender][tokenAddress] = true;
        }

        if (totalRaised >= sale.saleGoal) {
            sale.launched = true;
            emit SaleLaunched(tokenAddress, msg.sender);
            ISaleContract(tokenAddress).launchSale(
                launchContractAddress,
                buyLpFee,
                sellLpFee,
                buyProtocolFee,
                sellProtocolFee,
                firstBuyer[tokenAddress],
                msg.sender
            );
        }

        emit TokensBought(tokenAddress, msg.sender, totalRaised, tokenBalance);
    }


    function sellToken(address tokenAddress, uint256 tokenAmount, uint256 minEthOut) external nonReentrant {
        Sale storage sale = sales[tokenAddress];
        require(!sale.launched, "Sale already launched");

        (uint256 totalRaised, uint256 tokenBalance) = ISaleContract(tokenAddress).sell(msg.sender, tokenAmount, minEthOut);
        sale.totalRaised = totalRaised;

        emit TokensSold(tokenAddress, msg.sender, totalRaised, tokenBalance);
    }

    function claim(address tokenAddress) external nonReentrant {
        Sale storage sale = sales[tokenAddress];
        require(sale.launched, "Sale not launched");
        require(!hasClaimed[tokenAddress][msg.sender], "Already claimed");

        hasClaimed[tokenAddress][msg.sender] = true;

        emit Claimed(tokenAddress, msg.sender);

        ISaleContract(tokenAddress).claimTokens(msg.sender);
    }

    function setSaleMetadata(
        address tokenAddress,
        string memory logoUrl,
        string memory websiteUrl,
        string memory twitterUrl,
        string memory telegramUrl,
        string memory description  // New parameter for description
    ) external onlySaleCreator(tokenAddress) {
        SaleMetadata storage metadata = saleMetadata[tokenAddress];

        metadata.logoUrl = logoUrl;
        metadata.websiteUrl = websiteUrl;
        metadata.twitterUrl = twitterUrl;
        metadata.telegramUrl = telegramUrl;
        metadata.description = description;  // Update the description

        emit MetaUpdated(tokenAddress, logoUrl, websiteUrl, twitterUrl, telegramUrl, description);
    }

    function getUserBoughtTokens(address user) external view returns (address[] memory) {
        return userBoughtTokens[user];
    }

    function getUserBoughtTokensLength(address user) external view returns (uint256) {
        return userBoughtTokens[user].length;
    }

    function getCurrentNonce(address user) public view returns (uint256) {
        return creationNonce[user];
    }

    function getCreatorTokens(address creator) external view returns (address[] memory) {
        return creatorTokens[creator];
    }

    function predictTokenAddress(
        address creator,
        string memory name,
        string memory symbol,
        uint256 nonce
    ) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(creator, nonce));
        bytes32 initCodeHash = keccak256(abi.encodePacked(
            type(EtherfunSale).creationCode,
            abi.encode(
                name,
                symbol,
                creator,
                address(this),
                totalTokens,
                defaultK,
                defaultAlpha,
                defaultSaleGoal,
                creatorshare,
                feepercent
            )
        ));

        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            initCodeHash
        )))));
    }

//OWNER FUNCTIONS

    function takeFeeFrom(address tokenAddress) external nonReentrant {
        Sale storage sale = sales[tokenAddress];
        require(sale.launched, "Sale not launched");
        ISaleContract(tokenAddress).takeFee(owner);
    }

    function updateParameters(
        uint256 _defaultSaleGoal,
        uint256 _defaultK,
        uint256 _defaultAlpha,
        address _launchContractAddress,
        uint8 _buyLpFee,
        uint8 _sellLpFee,
        uint8 _buyProtocolFee,
        uint8 _sellProtocolFee
    ) external onlyOwner {
        require(_defaultSaleGoal > 0, "Invalid sale goal");
        require(_defaultK > 0, "Invalid K value");
        require(_defaultAlpha > 0, "Invalid alpha value");
        require(_launchContractAddress != address(0), "Invalid launch contract");
        
        defaultSaleGoal = _defaultSaleGoal;
        defaultK = _defaultK;
        defaultAlpha = _defaultAlpha;
        launchContractAddress = _launchContractAddress;
        buyLpFee = _buyLpFee;
        sellLpFee = _sellLpFee;
        buyProtocolFee = _buyProtocolFee;
        sellProtocolFee = _sellProtocolFee;
    }

    function updateFeeShares(
        uint8 _creatorShare,
        uint8 _feePercent
    ) external onlyOwner {
        require(_creatorShare > 0 && _creatorShare <= 100, "Invalid creator share");
        require(_feePercent > 0 && _feePercent <= 100, "Invalid fee share");
        
        creatorshare = _creatorShare;
        feepercent = _feePercent;
    }

}