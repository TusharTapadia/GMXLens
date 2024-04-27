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
        uint256 poolValue; // 30 decimals
        uint256 longTokenAmount; // token decimals
        uint256 longTokenUsd; // 30 decimals
        uint256 shortTokenAmount; // token decimals
        uint256 shortTokenUsd; // 30 decimals
        int256 openInterestLong; // 30 decimals
        int256 openInterestShort; // 30 decimals
        int256 pnlLong; // 30 decimals
        int256 pnlShort; // 30 decimals
        int256 netPnl; // 30 decimals
        uint256 borrowingFactorPerSecondForLongs; // 30 decimals
        uint256 borrowingFactorPerSecondForShorts; // 30 decimals
        bool longsPayShorts;
        uint256 fundingFactorPerSecond; // 30 decimals
        int256 fundingFactorPerSecondLongs; // 30 decimals
        int256 fundingFactorPerSecondShorts; // 30 decimals
        uint256 reservedUsdLong; // 30 decimals
        uint256 reservedUsdShort; // 30 decimals
        uint256 maxOpenInterestUsdLong; // 30 decimals
        uint256 maxOpenInterestUsdShort; // 30 decimals
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

    function getMarketData(
        address marketID
    ) external returns (MarketDataState memory marketDataState) {
        Market.Props memory marketProps = reader.getMarket(dataStore, marketID);

        Price.MarketPrices memory marketPrices = Price.MarketPrices(
            tokenPrice(marketProps.indexToken),
            tokenPrice(marketProps.longToken),
            tokenPrice(marketProps.shortToken)
        );


        return marketPrices;
    }

    function tokenPrice(address _token) internal returns(Price.Props memory){
        IPriceFeed priceFeed = IPriceFeed(IDataStore(dataStore).getAddress(Keys.priceFeedKey(_token)));

        if (address(priceFeed) == address(0)) {
            Price.Props memory primaryPrice = IOracle(oracle).primaryPrices(
                _token
            );
            require(
                primaryPrice.min != 0 && primaryPrice.max != 0,
                "Not able to fetch latest price"
            );
            return primaryPrice;
        }

        uint256 multiplier = getPriceFeedMultiplier(_token);

        (, int256 _tokenPrice, , , ) = priceFeed.latestRoundData();

        uint256 price = Precision.mulDiv(
            SafeCast.toUint256(_tokenPrice),
            multiplier,
            Precision.FLOAT_PRECISION
        );
        return Price.Props(price, price);
    }

        function getPriceFeedMultiplier(
        address token
    ) public view returns (uint256) {
        uint256 multiplier = IDataStore(dataStore).getUint(
            Keys.priceFeedMultiplierKey(token)
        );

        return multiplier;
    }

}