import { OAuthConfig } from "./util/oauth.util.js";

import { BigNumber } from "bignumber.js";

interface Options {
  config: Config,
  node?:number,
  headers?:any,
  params?:any,
  getFullResponse?:boolean,
  cacheNonce?:boolean,
  isAsync?: boolean,
  isDetailed?: boolean,
  stateQuery?: any,
  query?: any,
  logger?: typeof console,
  history?:any,
  doNotResolve?:boolean
}

interface Config {
  nodes:Node[],
  apiDebug:boolean,
  VM?:"SolidVM" | "EVM",
  timeout?:number,
  contractsPath?:string
}  

interface Node {
  url:string,
  oauth:OAuthConfig
}

interface Member {
  access?:boolean,
  orgName?:string,
  orgUnit?:string,
  commonName?:string
}

interface Balance {
  address: string,
  balance: number,
}

interface BlockChainUser {
  token:string,
  address:string
}

interface OAuthUser {
  token:string
}

interface ContractDefinition {
  source:string,
  name:string,
  args:any,
  txParams?:any
}

interface Contract {
  name: string,
  address?: string,
  src?:string,
  bin?:any,
  codeHash?:any
}

interface SendTx {
  toAddress:string,
  value:number
}

interface TransactionResultHash {
  hash:any
}

interface CallArgs {
  contract: Contract,
  method: string,
  args: any,
  value?:BigNumber,
  txParams?:any
}

export {
  Options,
  Config,
  OAuthUser,
  BlockChainUser,
  Contract,
  ContractDefinition,
  TransactionResultHash,
  CallArgs,
  Member,
  Balance,
  SendTx
};
