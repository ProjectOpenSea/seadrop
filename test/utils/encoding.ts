import { randomBytes as nodeRandomBytes } from "crypto";

const SeededRNG = require("./seeded-rng");

const GAS_REPORT_MODE = process.env.REPORT_GAS;

let randomBytes: (n: number) => string;
if (GAS_REPORT_MODE) {
  const srng = SeededRNG.create("gas-report");
  randomBytes = srng.randomBytes;
} else {
  randomBytes = (n: number) => nodeRandomBytes(n).toString("hex");
}

export const randomHex = (bytes = 32) => `0x${randomBytes(bytes)}`;
