import { fsUtil } from "blockapps-rest";

let deploy;

if (!deploy) {
  try {
    const deployFilePath = `${process.env.CONFIG_DIR_PATH || './config'}/${
      process.env.ORACLE_MODE === 'true' ? 'oracle_deploy.yaml' : 'deploy.yaml'
    }`;
    deploy = fsUtil.getYaml(deployFilePath);
  } catch (e) {
    console.log('Loading deploy.yaml failed', JSON.stringify(e))
    deploy = {
      contracts: {
        stripe: {},
        metamask: {},
        redemption: {}
      }
    }
  }
}

export default deploy;