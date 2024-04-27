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
        console.log(data.shortToken);
}
}