const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');


module.exports = function (deployer) {

    let firstAirline = '0x40d41f8f2db4ec63ec4c327be791f78d54910201'; // account[0] from mnemonic

    deployer.deploy(FlightSuretyData, firstAirline)
        .then(async () => {
            /*
                The parameter for the data contract is passed
                as an additional parameter to deploy()
             */
            return deployer.deploy(FlightSuretyApp, FlightSuretyData.address)
                .then(async () => {

                    const instances = await Promise.all([
                        FlightSuretyData.deployed(),
                        FlightSuretyApp.deployed()
                    ]);

                    // App Contract needs to be added to map of authorized ones in Data Contract
                    let result = await instances[0].authorizeCaller(FlightSuretyApp.address);

                    let config = {
                        localhost: {
                            url: 'http://localhost:8545',
                            dataAddress: FlightSuretyData.address,
                            appAddress: FlightSuretyApp.address
                        }
                    };
                    fs.writeFileSync(__dirname + '/../src/dapp/src/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
                    fs.writeFileSync(__dirname + '/../src/server/config.json', JSON.stringify(config, null, '\t'), 'utf-8');


                });
        });
};
