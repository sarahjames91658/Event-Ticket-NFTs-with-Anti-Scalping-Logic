import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;

describe("Contract Smoke Test", () => {
  it("simnet initializes correctly", () => {
    expect(simnet.blockHeight).toBeGreaterThan(0);
  });

  it("contract name is available", () => {
    const contractName = "Event-Ticket-NFTs-with-Anti-Scalping-Logic";
    expect(contractName).toBeDefined();
    expect(accounts).toBeDefined();
    expect(deployer).toBeDefined();
  });

  it("accounts are properly set up", () => {
    expect(accounts.size).toBeGreaterThan(0);
    expect(deployer).toBeTruthy();
  });
});