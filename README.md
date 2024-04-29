## GMXLENS 

**Foundry based GMX V2 stats contract**

Added Contracts and Tests for fetching data from GMX V2 on markets according to the given task.

"GMXLens.sol" is the contract which houses the function getMarketData. All the helper functions and stucts are defined in "Lib.sol".

Used data from 29th April with forking block as close as possible to the value calculated by the contract.

## Usage

### ENV
```
ORACLE_ADDRESS = "0xa11B501c2dd83Acd29F6727570f2502FAaa617F2"   
DATA_STORE_ADDRESS = "0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8"  
READER_ADDRESS = "0xdA5A70c885187DaA71E7553ca9F728464af8d2ad" 
RPC_URL= "https://arbitrum.llamarpc.com"
PRIVATE_KEY = ""
```

### Install

```
$ npm i 
$ git submodule init
$ git submodule update
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test -vv
```

### Deploy

```shell
$ forge script script/GMXLens.s.sol:GMXLensScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```



