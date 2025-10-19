import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;

const contractName = "Event-Ticket-NFTs-with-Anti-Scalping-Logic";

describe("Minimal Contract Tests", () => {
  it("contract is deployed and simnet works", () => {
    expect(simnet.blockHeight).toBeGreaterThan(0);
  });

  it("can create event successfully", () => {
    const { result } = simnet.callPublicFn(
      contractName,
      "create-event",
      [
        Cl.stringAscii("Test Event"),
        Cl.uint(100),
        Cl.uint(10),
        Cl.uint(1000)
      ],
      deployer
    );
    
    expect(result).toBeOk();
  });

  it("can purchase ticket after creating event", () => {
    // Create event first
    simnet.callPublicFn(
      contractName,
      "create-event",
      [
        Cl.stringAscii("Purchase Test"),
        Cl.uint(200),
        Cl.uint(5),
        Cl.uint(1500)
      ],
      deployer
    );

    // Purchase ticket
    const { result } = simnet.callPublicFn(
      contractName,
      "purchase-ticket",
      [Cl.uint(1)],
      wallet1
    );

    expect(result).toBeOk();
  });

  it("analytics functions return data", () => {
    // Create event and buy ticket
    simnet.callPublicFn(
      contractName,
      "create-event",
      [
        Cl.stringAscii("Analytics Test"),
        Cl.uint(300),
        Cl.uint(3),
        Cl.uint(2000)
      ],
      deployer
    );

    simnet.callPublicFn(
      contractName,
      "purchase-ticket",
      [Cl.uint(1)],
      wallet1
    );

    // Test analytics function works
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "get-event-analytics",
      [Cl.uint(1)],
      deployer
    );

    expect(result).toBeOk();
  });
});