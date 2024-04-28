pragma solidity 0.8.21;

import "forge-std/Test.sol";

import {GMXLens} from "../src/GMXLens.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {console} from "forge-std/console.sol";

import {Market,Keys,Price,Calc,Precision,MarketPoolValueInfo} from "../src/Lib.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GMXLensTest is Test {
    GMXLens gmxLens;
function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL"),205805040);
        address READER = vm.envAddress("READER_ADDRESS");
        address DATA_STORE = vm.envAddress("DATA_STORE_ADDRESS");
        address ORACLE = vm.envAddress("ORACLE_ADDRESS");
        // gmxLens = GMXLens(Upgrades.deployUUPSProxy("GMXLens.sol",abi.encodeCall(GMXLens.initialize, (READER, DATA_STORE, ORACLE))));

        address implementation = address(new GMXLens());
        bytes memory data = abi.encodeCall(GMXLens.initialize, (READER, DATA_STORE, ORACLE));

        address proxy = address(new ERC1967Proxy(implementation, data));

        gmxLens = GMXLens(proxy);
    }

function testGetDataDisplay() public {
     address marketID = address(0x47c031236e19d024b42f8AE6780E44A573170703);
        GMXLens.MarketDataState memory data = gmxLens.getMarketData(marketID);
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

function testGetDataBTC() public {
        address marketID = address(0x47c031236e19d024b42f8AE6780E44A573170703);
        GMXLens.MarketDataState memory data = gmxLens.getMarketData(marketID);
        console.log("Testing with a fork at block 205805040");
        assertEq(data.marketToken,0x47c031236e19d024b42f8AE6780E44A573170703,"Market token should match");
        assertEq(data.indexToken,0x47904963fc8b2340414262125aF798B9655E58Cd,"Index token should match");
        assertEq(data.longToken,0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,"Long token should match");
        assertEq(data.shortToken,0xaf88d065e77c8cC2239327C5EDb3A432268e5831,"Short token address should match dashboard");
        assertApproxEqRel(data.poolValue, 110012275488081691779235608058683271286, 5e16);
        assertApproxEqRel(data.longTokenAmount, 84531999464, 5e16);
        assertApproxEqRel(data.shortTokenAmount, 55392246437986, 5e16);
        assertApproxEqRel(data.pnlLong, -652507725925991336277893463463559985, 5e16);
        assertApproxEqRel(data.pnlShort, -1191744702959576925436093709255976649, 5e16);
        assertApproxEqRel(data.netPnl, -1844252428885568261713987172719536634, 5e16);
        assertApproxEqRel(data.borrowingFactorPerSecondForLongs,5521008302914086301242,5e16);
        assertApproxEqRel(data.borrowingFactorPerSecondForShorts,0,5e16);
        assertEq(data.longsPayShorts, true);
        assertApproxEqRel(data.fundingFactorPerSecond,7550696674752770451008,5e16);
        assertApproxEqRel(data.maxOpenInterestUsdLong, 9e37, 5e16);
        assertApproxEqRel(data.maxOpenInterestUsdShort, 9e37, 5e16);
}

}