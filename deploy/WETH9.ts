import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function ({ deployments, getNamedAccounts }: HardhatRuntimeEnvironment) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  await deploy('WETH9', {
    from: deployer,
    deterministicDeployment: false,
  })
}

export default func

func.tags = ['WETH9']

func.skip = () =>
  new Promise(async (resolve, reject) => {
    try {
      resolve(!!process.env.WNATIVE_ADDRESS);
    } catch (error) {
      reject(error)
    }
  })
