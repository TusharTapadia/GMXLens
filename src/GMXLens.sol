pragma solidity 0.8.21;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IReader} from "./interfaces/IReader.sol";
import {IDataStore} from "./interfaces/IDataStore.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {IOracle} from "./interfaces/IOracle.sol";

import {Market,Keys,Price,Calc,Precision,MarketPoolValueInfo} from "./Lib.sol";

contract GMXLens {
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

        int256 pnlShort = reader.getPnl(dataStore, marketProps, marketPrices.indexTokenPrice, false, true);
        int256 pnlLong = reader.getPnl(dataStore, marketProps, marketPrices.indexTokenPrice, true, true);
        int256 netPnl = reader.getNetPnl(dataStore,marketProps,marketPrices.indexTokenPrice,true);

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
        marketDataState.pnlShort = pnlShort;
        marketDataState.pnlLong = pnlLong;
        marketDataState.netPnl = netPnl;
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

    function getPriceFeedMultiplier(address token) public view returns (uint256) {
        uint256 multiplier = IDataStore(dataStore).getUint(Keys.priceFeedMultiplierKey(token));

        return multiplier;
    }

}