pragma solidity 0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IReader} from "./interfaces/IReader.sol";
import {IDataStore} from "./interfaces/IDataStore.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {IOracle} from "./interfaces/IOracle.sol";

import {Market,Keys,Price,Calc,Precision,MarketPoolValueInfo} from "./Lib.sol";

contract GMXLens is UUPSUpgradeable,OwnableUpgradeable{
    // using Math for int256;
    using SafeCast for int256;

    struct MarketDataState {
        address marketToken;
        address indexToken;
        address longToken;
        address shortToken;
        int256 poolValue; // 30 decimals
        uint256 longTokenAmount; // token decimals
        uint256 longTokenUsd; // 30 decimals
        uint256 shortTokenAmount; // token decimals
        uint256 shortTokenUsd; // 30 decimals
        int256 pnlLong; // 30 decimals
        int256 pnlShort; // 30 decimals
        int256 netPnl;// 30 decimals
        uint256 borrowingFactorPerSecondForLongs; // 30 decimals
        uint256 borrowingFactorPerSecondForShorts; // 30 decimals
        bool longsPayShorts;
        uint256 fundingFactorPerSecond; // 30 decimals
        int256 openInterestLong; // 30 decimals
        int256 openInterestShort; // 30 decimals
        uint256 reservedUsdLong; // 30 decimals
        uint256 reservedUsdShort; // 30 decimals
        uint256 maxOpenInterestUsdLong; // 30 decimals
        uint256 maxOpenInterestUsdShort; // 30 decimals
        int256 fundingFactorPerSecondLongs; // 30 decimals
        int256 fundingFactorPerSecondShorts; // 30 decimals
    }

    IReader private immutable reader;
    address private immutable dataStore;
    address private immutable oracle;

    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @param _reader address of reader contract
    /// @param _dataStore address of dataStore contract
    /// @param _oracle address of oracle contract
    constructor(address _reader, address _dataStore, address _oracle) {
        reader = IReader(_reader);
        dataStore = _dataStore;
        oracle = _oracle;
    }

    //  function initialize(IReader _reader, address _dataStore, address _oracle) external initializer {
    //     reader = _reader;
    //     dataStore = _dataStore;
    //     oracle = _oracle;
    //     __Ownable_init(msg.sender);
    //     __UUPSUpgradeable_init();
    // }

    function getMarketData(address marketID) external returns (MarketDataState memory marketDataState) {
    // getting market addresses
        Market.Props memory marketProps = reader.getMarket(dataStore, marketID);

    // getting prices
        Price.MarketPrices memory marketPrices = Price.MarketPrices(tokenPrice(marketProps.indexToken),tokenPrice(marketProps.longToken),tokenPrice(marketProps.shortToken));

    // getting detailed info of marketTokenPrice and info
       (int marketTokenPrice, MarketPoolValueInfo.Props memory marketPoolValueInfo )= reader.getMarketTokenPrice(dataStore, marketProps, marketPrices.indexTokenPrice, marketPrices.longTokenPrice, marketPrices.shortTokenPrice, Keys.MAX_PNL_FACTOR_FOR_TRADERS, true);

    // getting pnl of long and short
        marketDataState.pnlShort = reader.getPnl(dataStore, marketProps, marketPrices.indexTokenPrice, false, true);
        marketDataState.pnlLong = reader.getPnl(dataStore, marketProps, marketPrices.indexTokenPrice, true, true);
        marketDataState.netPnl = reader.getNetPnl(dataStore,marketProps,marketPrices.indexTokenPrice,true);

    // getting market info from reader
        Market.MarketInfo memory marketInfo = reader.getMarketInfo(dataStore,marketPrices,marketID);

    //getting openInterest
        uint256 divisor = getPoolDivisor(marketProps.longToken, marketProps.shortToken);
        marketDataState.openInterestLong = int256(getOpenInterest(marketProps, true, divisor));
        marketDataState.openInterestShort = int256(getOpenInterest(marketProps, false, divisor));

    //getting maxOpenInterest
        marketDataState.maxOpenInterestUsdLong = IDataStore(dataStore).getUint(Keys.maxOpenInterestKey(marketID, true));
        marketDataState.maxOpenInterestUsdShort = IDataStore(dataStore).getUint(Keys.maxOpenInterestKey(marketID, false));

    //getting reservedUSD
        marketDataState.reservedUsdLong = getReservedUsd(marketProps, marketPrices, true, divisor);
        marketDataState.reservedUsdShort = getReservedUsd(marketProps, marketPrices, false, divisor);

    //aggregating data
        marketDataState.marketToken = marketProps.marketToken;
        marketDataState.indexToken = marketProps.indexToken;
        marketDataState.longToken = marketProps.longToken;
        marketDataState.shortToken = marketProps.shortToken;
        marketDataState.poolValue = marketPoolValueInfo.poolValue;
        marketDataState.longTokenAmount = marketPoolValueInfo.longTokenAmount;
        marketDataState.longTokenUsd = marketPoolValueInfo.longTokenUsd;
        marketDataState.shortTokenAmount = marketPoolValueInfo.shortTokenAmount;
        marketDataState.shortTokenUsd = marketPoolValueInfo.shortTokenUsd;
        marketDataState.borrowingFactorPerSecondForLongs = marketInfo.borrowingFactorPerSecondForLongs;
        marketDataState.borrowingFactorPerSecondForShorts = marketInfo.borrowingFactorPerSecondForShorts;
        marketDataState.longsPayShorts = marketInfo.nextFunding.longsPayShorts;
        marketDataState.fundingFactorPerSecond = marketInfo.nextFunding.fundingFactorPerSecond;
        marketDataState.fundingFactorPerSecondLongs = getNextFundingFactorPerSecond(marketProps,true,divisor);
        marketDataState.fundingFactorPerSecondShorts = getNextFundingFactorPerSecond(marketProps,false,divisor);
  
    }

    function tokenPrice(address _token) internal returns(Price.Props memory){
        IPriceFeed priceFeed = IPriceFeed(IDataStore(dataStore).getAddress(Keys.priceFeedKey(_token)));

        if (address(priceFeed) == address(0)) {
            Price.Props memory primaryPrice = IOracle(oracle).primaryPrices(_token);
            return primaryPrice;
        }

        uint256 multiplier = getPriceFeedMultiplier(_token);

        (, int256 _tokenPrice, , , ) = priceFeed.latestRoundData();

        uint256 price = Precision.mulDiv(SafeCast.toUint256(_tokenPrice),multiplier,Precision.FLOAT_PRECISION);
        return Price.Props(price, price);
    }
    
    /** @dev get the multiplier value to convert the external price feed price to the price of 1 unit of the token
        represented with 30 decimals
        @param token token to get price feed multiplier for
    */
    function getPriceFeedMultiplier(address token) public view returns (uint256) {
        uint256 multiplier = IDataStore(dataStore).getUint(Keys.priceFeedMultiplierKey(token));

        return multiplier;
    }

    // this is used to divide the values of getPoolAmount and getOpenInterest
    // if the longToken and shortToken are the same, then these values have to be divided by two
    // to avoid double counting
    function getPoolDivisor(address longToken, address shortToken) internal pure returns (uint256) {
        return longToken == shortToken ? 2 : 1;
    }

    // @dev the long and short open interest for a market based on the collateral token used
    // @param dataStore DataStore
    // @param market the market to check
    // @param collateralToken the collateral token to check
    // @param isLong whether to check the long or short side
    function _getOpenInterest(
        address market,
        address collateralToken,
        bool isLong,
        uint256 divisor
    ) internal view returns (uint256) {
        return IDataStore(dataStore).getUint(Keys.openInterestKey(market, collateralToken, isLong)) / divisor;
    }

    // @dev get either the long or short open interest for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    // @param isLong whether to get the long or short open interest
    // @return the long or short open interest for a market
    function getOpenInterest(
        Market.Props memory market,
        bool isLong,
        uint256 divisor
    ) internal view returns (uint256) {
        uint256 openInterestUsingLongTokenAsCollateral = _getOpenInterest(market.marketToken, market.longToken, isLong, divisor);
        uint256 openInterestUsingShortTokenAsCollateral = _getOpenInterest(market.marketToken, market.shortToken, isLong, divisor);

        return openInterestUsingLongTokenAsCollateral + openInterestUsingShortTokenAsCollateral;
    }

    // @dev get the max open interest allowed for the market
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether this is for the long or short side
    // @return the max open interest allowed for the market
    function getMaxOpenInterest(address market, bool isLong) internal view returns (uint256) {
        return IDataStore(dataStore).getUint(Keys.maxOpenInterestKey(market, isLong));
    }

    // @dev get the total reserved USD required for positions
    // @param market the market to check
    // @param prices the prices of the market tokens
    // @param isLong whether to get the value for the long or short side
    function getReservedUsd(
        Market.Props memory market,
        Price.MarketPrices memory prices,
        bool isLong,
        uint256 divisor
    ) internal view returns (uint256) {
        uint256 reservedUsd;
        if (isLong) {
            // for longs calculate the reserved USD based on the open interest and current indexTokenPrice
            // this works well for e.g. an ETH / USD market with long collateral token as WETH
            // the available amount to be reserved would scale with the price of ETH
            // this also works for e.g. a SOL / USD market with long collateral token as WETH
            // if the price of SOL increases more than the price of ETH, additional amounts would be
            // automatically reserved
            uint256 openInterestInTokens = _getOpenInterestInTokens(market.marketToken, market.longToken, isLong, divisor);
            reservedUsd = openInterestInTokens * prices.indexTokenPrice.max;
        } else {
            // for shorts use the open interest as the reserved USD value
            // this works well for e.g. an ETH / USD market with short collateral token as USDC
            // the available amount to be reserved would not change with the price of ETH
            reservedUsd = getOpenInterest(market, isLong, divisor);
        }

        return reservedUsd;
    }

    function getNextFundingFactorPerSecond(Market.Props memory market,
        bool isLong,
        uint256 divisor
    ) internal view returns (int256 nextSavedFundingFactorPerSecond) {
        uint256 longOpenInterest;
        uint256 shortOpenInterest;
        if (isLong) {
            longOpenInterest = _getOpenInterest(market.marketToken,market.longToken,true,divisor);
            shortOpenInterest = _getOpenInterest(market.marketToken,market.longToken,false,divisor);
        } else {
            longOpenInterest = _getOpenInterest(market.marketToken,market.shortToken,true,divisor);
            shortOpenInterest = _getOpenInterest(market.marketToken,market.shortToken,false,divisor);
        }

        if (longOpenInterest == 0 || shortOpenInterest == 0) {
            return 0;
        }

        nextSavedFundingFactorPerSecond = _getNextFundingFactorPerSecond(market.marketToken,longOpenInterest,shortOpenInterest);
    }


    /** @dev the long and short open interest in tokens for a market based on the collateral token used
        @param market the market to check
        @param collateralToken the collateral token to check
        @param divisor divisor for market
        @param isLong whether to check the long or short side
    */
    function _getOpenInterestInTokens(
        address market,
        address collateralToken,
        bool isLong,
        uint256 divisor
    ) internal view returns (uint256) {
        return IDataStore(dataStore).getUint(Keys.openInterestInTokensKey(market, collateralToken, isLong)) / divisor;
    }

    function _getNextFundingFactorPerSecond(address market,uint256 longOpenInterest,uint256 shortOpenInterest) internal view returns (int256 nextSavedFundingFactorPerSecond) {
        uint256 diffUsd = Calc.diff(longOpenInterest, shortOpenInterest);
        uint256 totalOpenInterest = longOpenInterest + shortOpenInterest;

        uint256 fundingExponentFactor = IDataStore(dataStore).getUint(Keys.fundingExponentFactorKey(market));
        uint256 diffUsdAfterExponent = Precision.applyExponentFactor(diffUsd,fundingExponentFactor);
        uint256 diffUsdToOpenInterestFactor = Precision.toFactor(diffUsdAfterExponent, totalOpenInterest);

        nextSavedFundingFactorPerSecond = _getNextSavedFundingFactorPerSecond(market, longOpenInterest, shortOpenInterest, diffUsdToOpenInterestFactor);

        uint256 maxFundingFactorPerSecond = IDataStore(dataStore).getUint(Keys.maxFundingFactorPerSecondKey(market));

        nextSavedFundingFactorPerSecond = Calc.boundMagnitude(
            nextSavedFundingFactorPerSecond,
            0,
            maxFundingFactorPerSecond
        );
    }

    function _getFundingIncreaseFactorPerSecond(address market) internal view returns(uint256){
        return IDataStore(dataStore).getUint(Keys.fundingIncreaseFactorPerSecondKey(market));
    }

    function _savedFundingFactorPerSecondKey(address market) internal view returns (int256){
        return IDataStore(dataStore).getInt(Keys.savedFundingFactorPerSecondKey(market));
    }

    function _thresholdForStableFundingKey(address market) internal view returns(uint256){
        return uint(IDataStore(dataStore).getInt(Keys.thresholdForStableFundingKey(market)));
    }

    function _thresholdForDecreaseFunding(address market) internal view returns (uint256){
        return uint(IDataStore(dataStore).getInt(Keys.thresholdForDecreaseFundingKey(market)));
    }

    function _getFundingRateChangeType(bool isSkewTheSameDirectionAsFunding, uint diffUsdToOpenInterestFactor, uint thresholdForStableFunding, uint thresholdForDecreaseFunding ) internal view returns (FundingRateChangeType fundingRateChangeType){
        if (isSkewTheSameDirectionAsFunding) {
            if (diffUsdToOpenInterestFactor > thresholdForStableFunding) {
                fundingRateChangeType = FundingRateChangeType.Increase;
            } else if (diffUsdToOpenInterestFactor < thresholdForDecreaseFunding) {
                fundingRateChangeType = FundingRateChangeType.Decrease;
            }
        } else {
            fundingRateChangeType = FundingRateChangeType.Increase;
        }
    }

    function _getNextSavedFundingFactorPerSecond(address market,uint256 longOpenInterest,uint256 shortOpenInterest,uint256 diffUsdToOpenInterestFactor ) internal view returns (int256 nextSavedFundingFactorPerSecond){
        uint256 fundingIncreaseFactorPerSecond = _getFundingIncreaseFactorPerSecond(market);
        int256 savedFundingFactorPerSecond = _savedFundingFactorPerSecondKey(market);
        uint256 thresholdForStableFunding = _thresholdForStableFundingKey(market);
        uint256 thresholdForDecreaseFunding = _thresholdForDecreaseFunding(market);
        bool isSkewTheSameDirectionAsFunding = (savedFundingFactorPerSecond > 0 && longOpenInterest > shortOpenInterest) || (savedFundingFactorPerSecond < 0 && shortOpenInterest > longOpenInterest);
        FundingRateChangeType fundingRateChangeType = _getFundingRateChangeType(isSkewTheSameDirectionAsFunding, diffUsdToOpenInterestFactor, thresholdForStableFunding, thresholdForDecreaseFunding);
        
        if (fundingRateChangeType == FundingRateChangeType.Increase) {
            // increase funding rate
            int256 increaseValue = int256(Precision.applyFactor(diffUsdToOpenInterestFactor, fundingIncreaseFactorPerSecond) * getDurationInSec(market));

            // if there are more longs than shorts, then the savedFundingFactorPerSecond should increase
            // otherwise the savedFundingFactorPerSecond should increase in the opposite direction / decrease
            if (longOpenInterest < shortOpenInterest) {
                increaseValue = -increaseValue;
            }

            nextSavedFundingFactorPerSecond = savedFundingFactorPerSecond + increaseValue;

        } 
        
        if (fundingRateChangeType == FundingRateChangeType.Decrease && savedFundingFactorPerSecond != 0) {
            uint256 fundingDecreaseFactorPerSecond = IDataStore(dataStore).getUint(Keys.fundingDecreaseFactorPerSecondKey(market));
            uint256 decreaseValue = fundingDecreaseFactorPerSecond * getDurationInSec(market);

            if (uint256(savedFundingFactorPerSecond) <= decreaseValue) {
                nextSavedFundingFactorPerSecond = savedFundingFactorPerSecond / savedFundingFactorPerSecond;
            } else {
                int256 sign = savedFundingFactorPerSecond / savedFundingFactorPerSecond;
                nextSavedFundingFactorPerSecond = int256((uint256(savedFundingFactorPerSecond) - decreaseValue)) * sign;
            }
        }
    }

    function getDurationInSec(address market) internal view returns (uint256) {
        uint256 updatedAt = IDataStore(dataStore).getUint(Keys.fundingUpdatedAtKey(market));
        if (updatedAt == 0) {
            return 0;
        }
        return block.timestamp - updatedAt;
    }

    enum FundingRateChangeType {
        NoChange,
        Increase,
        Decrease
    }

}