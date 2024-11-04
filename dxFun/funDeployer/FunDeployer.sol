// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//dx.fun//base.fun powered by dextools and dxsale.

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external returns (uint256);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function decimals() external returns (uint8);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;
    address public voter;

    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyVoter() {
        require(msg.sender == voter);
        _;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(owner);
        owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function transferOwnership(address _newOwner) public onlyOwner {
        _transferOwnership(_newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address _newOwner) internal {
        require(_newOwner != address(0));
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}

interface IFunStorageInterface {
    function addFunContract(
        address _funOwner,
        address _funAddress,
        address _tokenAddress,
        address _routerAddress,
        string memory _name,
        string memory _symbol,
        string memory _data,
        uint256 _totalSupply,
        uint256 _initialLiquidity
    ) external;

    function getFunContractOwner(
        address _funContract
    ) external view returns (address);

    function updateData(
        address _funOwner,
        uint256 _ownerFunNumber,
        string memory _data
    ) external;

    function addDeployer(address) external;

    function owner() external view;
}

interface IFunEventTracker {
    function buyEvent(
        address _caller,
        address _funContract,
        uint256 _buyAmount,
        uint256 _tokenRecieved
    ) external;

    function sellEvent(
        address _caller,
        address _funContract,
        uint256 _sellAmount,
        uint256 _nativeRecieved
    ) external;

    function createFunEvent(
        address creator,
        address funContract,
        address tokenAddress,
        string memory name,
        string memory symbol,
        string memory data,
        uint256 totalSupply,
        uint256 initialReserve,
        uint256 timestamp
    ) external;

    function listEvent(
        address user,
        address tokenAddress,
        address router,
        uint256 liquidityAmount,
        uint256 tokenAmount,
        uint256 _time,
        uint256 totalVolume
    ) external;

    function callerValidate(address _newFunContract) external;

    function addDeployer(address) external;
}

interface IFunPool {
    function createFun(
        string[2] memory _name_symbol,
        uint256 _totalSupply,
        address _creator,
        address _baseToken,
        address _router,
        uint256[2] memory listThreshold_initReserveEth,
        bool lpBurn
    ) external payable returns (address);

    function buyTokens(
        address funToken,
        uint256 minTokens,
        address _affiliate
    ) external payable;
}

contract FunDeployer is Ownable {
    event funCreated(
        address indexed creator,
        address indexed funContract,
        address indexed tokenAddress,
        string name,
        string symbol,
        string data,
        uint256 totalSupply,
        uint256 initialReserve,
        uint256 timestamp
    );
    event royal(
        address indexed funContract,
        address indexed tokenAddress,
        address indexed router,
        address baseAddress,
        uint256 liquidityAmount,
        uint256 tokenAmount,
        uint256 _time,
        uint256 totalVolume
    );

    address public creationFeeDistributionContract;
    address public funStorage;
    address public eventTracker;
    address public funPool;
    uint256 public teamFee = 10000000; // value in wei
    uint256 public teamFeePer = 100; // base of 10000 -> 100 equals 1%
    uint256 public ownerFeePer = 1000; // base of 10000 -> 1000 means 10%
    uint256 public listThreshold = 12000; // value in ether -> 12000 means 12000 tokens(any decimal place)
    uint256 public antiSnipePer = 5; // base of 100 -> 5 equals 5%
    uint256 public affiliatePer = 1000; // base of 10000 -> 1000 equals 10%
    uint256 public supplyValue = 1000000000 ether;
    uint256 public initialReserveEth = 1 ether;
    uint256 public routerCount;
    uint256 public baseCount;
    bool public supplyLock = true;
    bool public lpBurn = true;
    mapping(address => bool) public routerValid;
    mapping(address => bool) public routerAdded;
    mapping(uint256 => address) public routerStorage;
    mapping(address => bool) public baseValid;
    mapping(address => bool) public baseAdded;
    mapping(uint256 => address) public baseStorage;
    mapping(address => uint256) public affiliateSpecialPer;
    mapping(address => bool) public affiliateSpecial;

    constructor(
        address _funPool,
        address _creationFeeContract,
        address _funStorage,
        address _eventTracker
    ) {
        funPool = _funPool;
        creationFeeDistributionContract = _creationFeeContract;
        funStorage = _funStorage;
        eventTracker = _eventTracker;
    }

    function CreateFun(
        string memory _name,
        string memory _symbol,
        string memory _data,
        uint256 _totalSupply,
        uint256 _liquidityETHAmount,
        address _baseToken,
        address _router,
        bool _antiSnipe,
        uint256 _amountAntiSnipe
    ) public payable {
        require(routerValid[_router], "invalid router");
        require(baseValid[_baseToken], "invalid base token");
        if (supplyLock) {
            require(_totalSupply == supplyValue, "invalid supply");
        }

        if (_antiSnipe) {
            require(_amountAntiSnipe > 0, "invalid antisnipe value");
        }

        require(
            _amountAntiSnipe <= ((initialReserveEth * antiSnipePer) / 100),
            "over antisnipe restrictions"
        );

        require(
            msg.value >= (teamFee + _liquidityETHAmount + _amountAntiSnipe),
            "fee amount error"
        );

        (bool feeSuccess, ) = creationFeeDistributionContract.call{
            value: teamFee
        }("");
        require(feeSuccess, "creation fee failed");

        address funToken = IFunPool(funPool).createFun{
            value: _liquidityETHAmount
        }(
            [_name, _symbol],
            _totalSupply,
            msg.sender,
            _baseToken,
            _router,
            [listThreshold, initialReserveEth],
            lpBurn
        );
        IFunStorageInterface(funStorage).addFunContract(
            msg.sender,
            (funToken),
            funToken,
            address(_router),
            _name,
            _symbol,
            _data,
            _totalSupply,
            _liquidityETHAmount
        );

        if (_antiSnipe) {
            IFunPool(funPool).buyTokens{value: _amountAntiSnipe}(
                funToken,
                0,
                msg.sender
            );
            IERC20(funToken).transfer(
                msg.sender,
                IERC20(funToken).balanceOf(address(this))
            );
        }
        IFunEventTracker(eventTracker).createFunEvent(
            msg.sender,
            (funToken),
            (funToken),
            _name,
            _symbol,
            _data,
            _totalSupply,
            initialReserveEth + _liquidityETHAmount,
            block.timestamp
        );
        emit funCreated(
            msg.sender,
            (funToken),
            (funToken),
            _name,
            _symbol,
            _data,
            _totalSupply,
            initialReserveEth + _liquidityETHAmount,
            block.timestamp
        );
    }

    function updateTeamFee(uint256 _newTeamFeeInWei) public onlyOwner {
        teamFee = _newTeamFeeInWei;
    }

    function updateownerFee(uint256 _newOwnerFeeBaseTenK) public onlyOwner {
        ownerFeePer = _newOwnerFeeBaseTenK;
    }

    function updateSpecialAffiliateData(
        address _affiliateAddrs,
        bool _status,
        uint256 _specialPer
    ) public onlyOwner {
        affiliateSpecial[_affiliateAddrs] = _status;
        affiliateSpecialPer[_affiliateAddrs] = _specialPer;
    }

    function getAffiliatePer(
        address _affiliateAddrs
    ) public view returns (uint256) {
        if (affiliateSpecial[_affiliateAddrs]) {
            return affiliateSpecialPer[_affiliateAddrs];
        } else {
            return affiliatePer;
        }
    }

    function getOwnerPer() public view returns (uint256) {
        return ownerFeePer;
    }

    function getSpecialAffiliateValidity(
        address _affiliateAddrs
    ) public view returns (bool) {
        return affiliateSpecial[_affiliateAddrs];
    }

    function updateSupplyValue(uint256 _newSupplyVal) public onlyOwner {
        supplyValue = _newSupplyVal;
    }

    function updateInitResEthVal(uint256 _newVal) public onlyOwner {
        initialReserveEth = _newVal;
    }

    function stateChangeSupplyLock(bool _lockState) public onlyOwner {
        supplyLock = _lockState;
    }

    function addRouter(address _routerAddress) public onlyOwner {
        require(!routerAdded[_routerAddress], "already added");
        routerAdded[_routerAddress] = true;
        routerValid[_routerAddress] = true;
        routerStorage[routerCount] = _routerAddress;
        routerCount++;
    }

    function disableRouter(address _routerAddress) public onlyOwner {
        require(routerAdded[_routerAddress], "not added");
        require(routerValid[_routerAddress], "not valid");
        routerValid[_routerAddress] = false;
    }

    function enableRouter(address _routerAddress) public onlyOwner {
        require(routerAdded[_routerAddress], "not added");
        require(!routerValid[_routerAddress], "already enabled");
        routerValid[_routerAddress] = true;
    }

    function addBaseToken(address _baseTokenAddress) public onlyOwner {
        require(!baseAdded[_baseTokenAddress], "already added");
        baseAdded[_baseTokenAddress] = true;
        baseValid[_baseTokenAddress] = true;
        baseStorage[baseCount] = _baseTokenAddress;
        baseCount++;
    }

    function disableBaseToken(address _baseTokenAddress) public onlyOwner {
        require(baseAdded[_baseTokenAddress], "not added");
        require(baseValid[_baseTokenAddress], "not valid");
        baseValid[_baseTokenAddress] = false;
    }

    function enableBasetoken(address _baseTokenAddress) public onlyOwner {
        require(baseAdded[_baseTokenAddress], "not added");
        require(!baseValid[_baseTokenAddress], "already enabled");
        baseValid[_baseTokenAddress] = true;
    }

    function updateFunData(
        uint256 _ownerFunCount,
        string memory _newData
    ) public {
        IFunStorageInterface(funStorage).updateData(
            msg.sender,
            _ownerFunCount,
            _newData
        );
    }

    function updateFunPool(address _newfunPool) public onlyOwner {
        funPool = _newfunPool;
    }

    function updateCreationFeeContract(
        address _newCreationFeeContract
    ) public onlyOwner {
        creationFeeDistributionContract = _newCreationFeeContract;
    }

    function updateStorageContract(
        address _newStorageContract
    ) public onlyOwner {
        funStorage = _newStorageContract;
    }

    function updateEventContract(address _newEventContract) public onlyOwner {
        eventTracker = _newEventContract;
    }

    function updateListThreshold(uint256 _newListThreshold) public onlyOwner {
        listThreshold = _newListThreshold;
    }

    function updateAntiSnipePer(uint256 _newAntiSnipePer) public onlyOwner {
        antiSnipePer = _newAntiSnipePer;
    }

    function stateChangeLPBurn(bool _state) public onlyOwner {
        lpBurn = _state;
    }

    function updateAffiliatePerBaseTenK(uint256 _newAffPer) public onlyOwner {
        affiliatePer = _newAffPer;
    }

    function updateteamFeeper(uint256 _newFeePer) public onlyOwner {
        teamFeePer = _newFeePer;
    }

    function emitRoyal(
        address funContract,
        address tokenAddress,
        address router,
        address baseAddress,
        uint256 liquidityAmount,
        uint256 tokenAmount,
        uint256 _time,
        uint256 totalVolume
    ) public {
        require(msg.sender == funPool, "invalid caller");
        emit royal(
            funContract,
            tokenAddress,
            router,
            baseAddress,
            liquidityAmount,
            tokenAmount,
            _time,
            totalVolume
        );
    }

    // Emergency withdrawal by owner
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner).transfer(balance);
    }
}
