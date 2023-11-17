import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;

  const { deployer, dev } = await getNamedAccounts();

  await deploy("SpeedswapV2Factory", {
    from: deployer,
    args: [deployer],
    log: true,
    deterministicDeployment: false,
  });
};

func.tags = ["SpeedswapV2Factory", "AMM"];

export default func;
