pragma solidity 0.8.21;

import "forge-std/Test.sol";

import {GMXLens} from "../src/GMXLens.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {console} from "forge-std/console.sol";

import {Market,Keys,Price,Calc,Precision,MarketPoolValueInfo} from "../src/Lib.sol";

contract GMXLensTest is Test {
    GMXLens aggregator;
function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL"));
        Options memory opts;
        address READER = vm.envAddress("READER_ADDRESS");
        address DATA_STORE = vm.envAddress("DATA_STORE_ADDRESS");
        address ORACLE = vm.envAddress("ORACLE_ADDRESS");
        opts.constructorData = abi.encode(READER, DATA_STORE, ORACLE);
        aggregator = new GMXLens(READER, DATA_STORE, ORACLE);

        // aggregator.initialize();
    }

function testGetData() public {
     address marketID = address(0x47c031236e19d024b42f8AE6780E44A573170703);
        GMXLens.MarketDataState memory data = aggregator.getMarketData(marketID);
        console.log(data.marketToken);
        console.log(data.indexToken);
        console.log(data.longToken);
        console.log(data.shortToken);
        console.logInt(data.poolValue);
        console.log(data.longTokenAmount);
        console.log(data.longTokenUsd);
        console.log(data.shortTokenAmount);
        console.log(data.shortTokenUsd);
        console.logInt(data.pnlLong);
        console.logInt(data.pnlShort);
        console.logInt(data.netPnl);
        console.log(data.borrowingFactorPerSecondForLongs);
        console.log(data.borrowingFactorPerSecondForShorts);
        console.logBool(data.longsPayShorts);
        console.log(data.fundingFactorPerSecond);
        console.logInt(data.openInterestLong);
        console.logInt(data.openInterestShort);
        console.log(data.reservedUsdLong);
        console.log(data.reservedUsdShort);
        console.log(data.maxOpenInterestUsdLong);
        console.log(data.maxOpenInterestUsdShort);
        console.logInt(data.fundingFactorPerSecondLongs);
        console.logInt(data.fundingFactorPerSecondShorts);
}
}