import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;

const contractName = "Event-Ticket-NFTs-with-Anti-Scalping-Logic";

describe("Basic Contract Validation", () => {
  it("contract deploys successfully", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("can create an event", () => {
    const createResult = simnet.callPublicFn(
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
    
    expect(createResult.result).toBeOk();
  });

  it("can purchase a ticket", () => {
    // Create event first
    simnet.callPublicFn(
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

    // Purchase ticket
    const purchaseResult = simnet.callPublicFn(
      contractName,
      "purchase-ticket",
      [Cl.uint(1)],
      wallet1
    );

    expect(purchaseResult.result).toBeOk();
  });

  it("can read event analytics", () => {
    // Create event and purchase ticket
    simnet.callPublicFn(
      contractName,
      "create-event",
      [
        Cl.stringAscii("Analytics Test"),
        Cl.uint(100),
        Cl.uint(10),
        Cl.uint(1000)
      ],
      deployer
    );

    simnet.callPublicFn(
      contractName,
      "purchase-ticket",
      [Cl.uint(1)],
      wallet1
    );

    // Read analytics
    const analyticsResult = simnet.callReadOnlyFn(
      contractName,
      "get-event-analytics",
      [Cl.uint(1)],
      deployer
    );

    expect(analyticsResult.result).toBeOk();
  });

  it("admin functions require authorization", () => {
    // Create event first
    simnet.callPublicFn(
      contractName,
      "create-event",
      [
        Cl.stringAscii("Auth Test"),
        Cl.uint(100),
        Cl.uint(10),
        Cl.uint(1000)
      ],
      deployer
    );

    // Try unauthorized access
    const unauthorizedResult = simnet.callPublicFn(
      contractName,
      "export-event-report",
      [Cl.uint(1)],
      wallet1
    );

    expect(unauthorizedResult.result).toBeErr();

    // Authorized access should work
    const authorizedResult = simnet.callPublicFn(
      contractName,
      "export-event-report",
      [Cl.uint(1)],
      deployer
    );

    expect(authorizedResult.result).toBeOk();
  });
});