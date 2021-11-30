const CryptoDicks = artifacts.require("CryptoDicks");
// const LinkToken = require('../node_modules/@chainlink/contracts/src/v0.4/LinkToken')
// const { Oracle } = require('@chainlink/contracts/src/v0.6/Oracle')

module.exports = async (deployer, network, accounts) => {
  console.log("Start deploy CryptoDicks...")


  // Hard coded for Rinkeby
  if (network.startsWith('rinkeby')) {
    console.log("Start deploy CryptoDicks on Rinkeby...")

    const testAccount = accounts[1]
    const RINKEBY_VRF_COORDINATOR = "0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B"
    const RINKEBY_LINK_TOKEN = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709"
    const RINKEBY_KEY_HASH = "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311"

    console.log("Start deploy Link...")
    // LinkToken.setProvider(deployer.provider)
    // CryptoDicks.setProvider(deployer.provider)

    try {
      await deployer.deploy(
        CryptoDicks,
        RINKEBY_VRF_COORDINATOR,
        RINKEBY_LINK_TOKEN,
        RINKEBY_KEY_HASH
      );

      let cryptoDicks = await CryptoDicks.deployed()
      console.log("Deployed!", { cryptoDicks });
    } catch (error) {
      console.log(error);
    }
  } else {
    deployer.deploy(CryptoDicks)
  }
};
