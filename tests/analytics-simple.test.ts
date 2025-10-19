import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const contractName = "Event-Ticket-NFTs-with-Anti-Scalping-Logic";

describe("Event Ticket NFTs with Analytics - Core Tests", () => {
  beforeEach(() => {
    simnet.mineEmptyBlocks(1);
  });

  describe("Basic Functionality", () => {
    it("ensures simnet is well initialized", () => {
      expect(simnet.blockHeight).toBeDefined();
      expect(simnet.blockHeight).toBeGreaterThan(0);
    });

    it("can create an event and initialize analytics", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "create-event",
        [Cl.stringAscii("Test Event"), Cl.uint(100), Cl.uint(50), Cl.uint(1000)],
        deployer
      );
      expect(result).toBeOk();
      expect(result.expectOk()).toBeUint(1);
    });

    it("can purchase tickets and track analytics", () => {
      // Create an event
      simnet.callPublicFn(
        contractName,
        "create-event",
        [Cl.stringAscii("Test Event"), Cl.uint(100), Cl.uint(50), Cl.uint(1000)],
        deployer
      );

      // Purchase a ticket
      const { result } = simnet.callPublicFn(
        contractName,
        "purchase-ticket",
        [Cl.uint(1)],
        wallet1
      );
      expect(result).toBeOk();
      expect(result.expectOk()).toBeUint(1);

      // Check analytics were updated
      const analyticsResult = simnet.callReadOnlyFn(
        contractName,
        "get-event-analytics",
        [Cl.uint(1)],
        deployer
      );
      expect(analyticsResult.result).toBeOk();
      const analytics = analyticsResult.result.expectOk().expectTuple();
      expect(analytics["total-revenue"]).toBeUint(1000);
      expect(analytics["tickets-purchased"]).toBeUint(1);
    });
  });

  describe("Analytics Functions", () => {
    beforeEach(() => {
      // Setup: Create event and purchase some tickets
      simnet.callPublicFn(
        contractName,
        "create-event",
        [Cl.stringAscii("Analytics Test"), Cl.uint(200), Cl.uint(10), Cl.uint(1500)],
        deployer
      );
      simnet.callPublicFn(contractName, "purchase-ticket", [Cl.uint(1)], wallet1);
      simnet.callPublicFn(contractName, "purchase-ticket", [Cl.uint(1)], wallet2);
    });

    it("get-event-analytics returns comprehensive metrics", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-event-analytics",
        [Cl.uint(1)],
        deployer
      );
      expect(result).toBeOk();
      const analytics = result.expectOk().expectTuple();
      expect(analytics["total-revenue"]).toBeUint(3000); // 2 tickets * 1500
      expect(analytics["tickets-purchased"]).toBeUint(2);
      expect(analytics["average-sale-price"]).toBeUint(1500);
    });

    it("calculate-attendance-rate works correctly", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "calculate-attendance-rate",
        [Cl.uint(1)],
        deployer
      );
      expect(result).toBeOk();
      const attendance = result.expectOk().expectTuple();
      expect(attendance["total-purchased"]).toBeUint(2);
      expect(attendance["total-checked-in"]).toBeUint(0);
      expect(attendance["no-shows"]).toBeUint(2);
    });

    it("get-revenue-report provides detailed breakdown", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-revenue-report",
        [Cl.uint(1)],
        deployer
      );
      expect(result).toBeOk();
      const report = result.expectOk().expectTuple();
      expect(report["total-revenue"]).toBeUint(3000);
      expect(report["average-price"]).toBeUint(1500);
      expect(report["tickets-sold"]).toBeUint(2);
    });
  });

  describe("Admin Analytics Functions", () => {
    beforeEach(() => {
      simnet.callPublicFn(
        contractName,
        "create-event",
        [Cl.stringAscii("Admin Test"), Cl.uint(300), Cl.uint(20), Cl.uint(2000)],
        deployer
      );
      simnet.callPublicFn(contractName, "purchase-ticket", [Cl.uint(1)], wallet1);
    });

    it("export-event-report requires admin authorization", () => {
      // Unauthorized access should fail
      const { result: unauthorizedResult } = simnet.callPublicFn(
        contractName,
        "export-event-report",
        [Cl.uint(1)],
        wallet1
      );
      expect(unauthorizedResult).toBeErr();
      expect(unauthorizedResult.expectErr()).toBeUint(100); // err-owner-only

      // Authorized access should succeed
      const { result: authorizedResult } = simnet.callPublicFn(
        contractName,
        "export-event-report",
        [Cl.uint(1)],
        deployer
      );
      expect(authorizedResult).toBeOk();
      const report = authorizedResult.expectOk().expectTuple();
      expect(report).toHaveProperty("event-details");
      expect(report).toHaveProperty("analytics");
      expect(report).toHaveProperty("report-generated-at");
    });

    it("update-event-popularity sets popularity metrics", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "update-event-popularity",
        [Cl.uint(1), Cl.uint(85), Cl.uint(150)],
        deployer
      );
      expect(result).toBeOk();
      expect(result.expectOk()).toBeBool(true);

      // Verify popularity was set
      const popularityResult = simnet.callReadOnlyFn(
        contractName,
        "get-event-popularity-ranking",
        [Cl.uint(1)],
        deployer
      );
      const popularity = popularityResult.result.expectOk().expectTuple();
      expect(popularity["popularity-score"]).toBeUint(85);
      expect(popularity["trending-factor"]).toBeUint(3); // High score = factor 3
      expect(popularity["social-engagement"]).toBeUint(150);
    });
  });

  describe("Error Handling", () => {
    it("returns error for non-existent event analytics", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-event-analytics",
        [Cl.uint(999)], // Non-existent event
        deployer
      );
      expect(result).toBeErr();
      expect(result.expectErr()).toBeUint(107); // err-no-analytics-data
    });

    it("handles zero division in calculations gracefully", () => {
      // Create event but don't purchase tickets
      simnet.callPublicFn(
        contractName,
        "create-event",
        [Cl.stringAscii("Empty Event"), Cl.uint(400), Cl.uint(10), Cl.uint(1000)],
        deployer
      );

      const { result } = simnet.callReadOnlyFn(
        contractName,
        "calculate-attendance-rate",
        [Cl.uint(1)],
        deployer
      );
      expect(result).toBeOk();
      const attendance = result.expectOk().expectTuple();
      expect(attendance["attendance-rate"]).toBeUint(0);
      expect(attendance["total-purchased"]).toBeUint(0);
    });
  });
});