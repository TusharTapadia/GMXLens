pragma solidity 0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IReader} from "./interfaces/IReader.sol";
import {IDataStore} from "./interfaces/IDataStore.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {IOracle} from "./interfaces/IOracle.sol";

import {Market,Keys,Price,Calc,Precision,MarketPoolValueInfo} from "./Lib.sol";

contract GMXLens is UUPSUpgradeable, OwnableUpgradeable {
    // using Math for int256;

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
    /// @param reader_ address of reader contract
    /// @param dataStore_ address of dataStore contract
    /// @param oracle_ address of oracle contract
    constructor(IReader _reader, address _dataStore, address _oracle) {
        reader = _reader;
        dataStore = _dataStore;
        oracle = _oracle;
        _disableInitializers();
    }

     function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function getMarketData(
        address marketID
    ) external view returns (MarketDataState memory marketDataState) {
        Market.Props memory marketProps = reader.getMarket(dataStore, marketID);

        marketDataState.marketToken = marketProps.marketToken;
        marketDataState.indexToken = marketProps.indexToken;
        marketDataState.longToken = marketProps.longToken;
        marketDataState.shortToken = marketProps.shortToken;

        Price.MarketPrices memory marketPrices = Price.MarketPrices(
            tokenPrice(marketProps.indexToken),
            tokenPrice(marketProps.longToken),
            tokenPrice(marketProps.shortToken)
        );
    }

    function tokenPrice(address _token) external returns(Price.Props memory){
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

   /**
     * @dev performs required checks required to upgrade contract
     * @param newImplementation address to update implementation logic to
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
    
}