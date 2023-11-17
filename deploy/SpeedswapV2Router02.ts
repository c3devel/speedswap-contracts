import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const chainId = parseInt(await getChainId());

  let wethAddress: string;
  if (!process.env.WNATIVE_ADDRESS) {
    wethAddress = (await deployments.get("WETH9")).address;
    if (!wethAddress) {
      throw Error(`No WNATIVE_ADDRESS for chain #${chainId}!`);
    }
  }

  const factory = await deployments.get("SpeedswapV2Factory");

  await deploy("SpeedswapV2Router02", {
    from: deployer,
    args: [factory.address, wethAddress!],
    log: true,
    deterministicDeployment: false,
  });
};

func.tags = ["SpeedswapV2Router02", "AMM"];

func.dependencies = ["SpeedswapV2Factory", "WETH9"];

export default func;
