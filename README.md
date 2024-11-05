是否要轉嫁gas fee用給第一跟最後的使用者？
開虛擬池的比例？ 1B new tokens : ? based tokens 
抽pool手續費？
token全部都會先mint到銷售合約
ERC20合約要拆開還是一起跟pool寫在一起？

## AiFunPoolFactory contract
### ERC20 interface
### Ownable
### aiFunPool interface
### mappings and events
### default params:
- aiFunPoolAddr
To point to the AiFunPool contract
- defaultTotalTokens= 1B
- defaultSaleGoal (MarketCap or totalTokens sold)
- feeShares = 1 %
- feeTo: owner
- defaultK
The K value for the bonding curve (decided by the virtual pool)
- defaultAlpha
The steepness of the bonding curve (decided by the virtual pool)

### functions:
- createAiFun
To call the creation function in the AiFunPool contract and store the informations
  
optional:
- getUserBoughtTokens
```solidity
    function getUserBoughtTokensLength(
        address user
    ) external view returns (uint256) {
        return userBoughtTokens[user].length;
    }
```
- getUserBoughtTokensLength

```solidity    
    function getUserBoughtTokensLength(
        address user
    ) external view returns (uint256) {
        return userBoughtTokens[user].length;
    }
```
- getCreatorTokens
```
    function getCreatorTokens(
        address creator
    ) external view returns (address[] memory) {
        return creatorTokens[creator];
    }
```

ownerOnly:
- takeFeeFrom
To call the takeFee function of the aiFunPoolContract contract

```solidity
function takeFeeFrom(address tokenAddress) external nonReentrant {
        IAiFunPoolContract(tokenAddress).takeFee(owner);
    }
```

- updateParameters
  To update the default parameters

- updateFeeShares
To update the fee percentage 

## AiFunPool contract

- createAiFun(name, symbol, baseTokenAddr)
1. clone erc20 contract and mint all to AiFunPool contract
2. preserve 0.2 B ?
- buyTokens
1. calculate the amount of base token needed
2. check if the sell goal or market cap is reached
3. add liquidity to the dex pool
- sellTokens
- getFee (SAKABA/ owner)
- launchAiFun (to dex pool)
- getBaseIn
Function to calculate the amount of base token for a given token amount
- getTokenIn
Function to calculate the number of tokens for a given base token amount

## ERC20 contract
- initialize
mint all token to AiFunPool contract when created
- _validateTransfer
if not listed to dex, can not transfer to other address (only can sell in AiFunPool contract)
- initiateDex
  if the token is listed to dex, initiate the dex pool