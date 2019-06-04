# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install:
```shell
git clone https://github.com/stevenhankin/FlightSurety.git
cd FlightSurety
npm install
truffle compile
```

## Run Tests
This requires running two components in two shells
The first is a local Ethereum node (using Ganache) whilst running the tests

**In shell #1 start Ganache:**
```
ganache-cli -a 50 -e 1000 -m "quote ensure arrive vote dinosaur illegal wood equal disagree teach tray planet" 
```
The flag `-a 50` will create 50 funded test addresses on your local node

The specific -m mnemonic is needed since the address of first airline is 
passed for migration of Data Contract.

**In shell #2 launch the Contract and Oracle tests:**
```shell
truffle test ./test/flightSurety.js
truffle test ./test/oracles.js
```

## Run Application

**In shell #1 start Ganache (as was done for tests above):**
```
ganache-cli -a 50
```

**In shell #2 compile/migrate the contracts AND launch the Oracles Service**
```
rm -r build/
truffle migrate --reset && npm run server
```
Note that this will need to be done **3 times** due to some bizarre issue with Ganache / Truffle

i.e. CTRL+C and rerun 3 times

**In shell #3 start the Web App Server**
```
cd src/dapp
yarn install
yarn start
```

**Finally access the application in a browser**

`http://localhost:8000`


## Deploy

To build dapp for prod:

`npm run dapp:prod`

Deploy the contents of the ./dapp folder


## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)

