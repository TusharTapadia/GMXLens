// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {GMXLens} from "src/GMXLens.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GMXLensScript is Script {
    function setUp() public {}

    function run() public {
        GMXLens gmxLens;
        vm.startBroadcast(uint256(vm.envBytes32("PRIVATE_KEY")));
        address READER = vm.envAddress("READER_ADDRESS");
        address DATA_STORE = vm.envAddress("DATA_STORE_ADDRESS");
        address ORACLE = vm.envAddress("ORACLE_ADDRESS");
        // gmxLens = GMXLens(Upgrades.deployUUPSProxy("GMXLens.sol",abi.encodeCall(GMXLens.initialize, (READER, DATA_STORE, ORACLE))));

        address implementation = address(new GMXLens());
        bytes memory data = abi.encodeCall(GMXLens.initialize, (READER, DATA_STORE, ORACLE));

        address proxy = address(new ERC1967Proxy(implementation, data));

        gmxLens = GMXLens(proxy);
        vm.stopBroadcast();
    }
}
