import CollectionConfig from "./CollectionConfig";

//FIXME remove this class and use CollectionConfig
export const tokenName = CollectionConfig.tokenName;
export const tokenSymbol = CollectionConfig.tokenSymbol;
export const seadropAddress = process.env.SEADROP_ADDRESS || "0x00005EA00Ac477B1030CE78506496e8C2dE24bf5";
export const creatorAddress = "0x13B057C69151aaa156811dC8607c699714cd9DDF"

export const MAX_SUPPLY = CollectionConfig.maxSupply;
