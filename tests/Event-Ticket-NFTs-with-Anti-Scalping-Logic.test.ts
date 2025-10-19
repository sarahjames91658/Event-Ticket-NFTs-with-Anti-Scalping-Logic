
import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;

const contractName = "Event-Ticket-NFTs-with-Anti-Scalping-Logic";

describe("Event Ticket NFTs with Analytics", () => {
  beforeEach(() => {
    simnet.mineEmptyBlocks(1);
  });

  describe("Basic Contract Functionality", () => {
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
      expect(result).toBeUint(1);
    });

    it("can purchase tickets and track analytics", () => {
      // First create an event
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
      expect(result).toBeUint(1);

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
        [Cl.stringAscii("Analytics Test Event"), Cl.uint(200), Cl.uint(100), Cl.uint(1500)],
        deployer
      );
      simnet.callPublicFn(contractName, "purchase-ticket", [Cl.uint(1)], wallet1);
      simnet.callPublicFn(contractName, "purchase-ticket", [Cl.uint(1)], wallet2);
      simnet.callPublicFn(contractName, "purchase-ticket", [Cl.uint(1)], wallet3);
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
      expect(analytics["total-revenue"]).toBeUint(4500); // 3 tickets * 1500
      expect(analytics["tickets-purchased"]).toBeUint(3);
      expect(analytics["average-sale-price"]).toBeUint(1500);
    });

    it("calculate-attendance-rate works with zero check-ins", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "calculate-attendance-rate",
        [Cl.uint(1)],
        deployer
      );
      expect(result).toBeOk();
      const attendance = result.expectOk().expectTuple();
      expect(attendance["attendance-rate"]).toBeUint(0); // No check-ins yet
      expect(attendance["total-purchased"]).toBeUint(3);
      expect(attendance["total-checked-in"]).toBeUint(0);
      expect(attendance["no-shows"]).toBeUint(3);
    });

    it("get-revenue-report provides detailed revenue breakdown", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-revenue-report",
        [Cl.uint(1)],
        deployer
      );
      expect(result).toBeOk();
      const report = result.expectOk().expectTuple();
      expect(report["total-revenue"]).toBeUint(4500);
      expect(report["average-price"]).toBeUint(1500);
      expect(report["tickets-sold"]).toBeUint(3);
    });

    it("get-no-show-statistics calculates correctly", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-no-show-statistics",
        ["u1"],
        deployer
      );
      expect(result).toBeOk();
      const stats = result.expectOk().expectTuple();
      expect(stats["no-show-count"]).toBeUint(3);
      expect(stats["no-show-rate"]).toBeUint(100); // 100% no-show rate
      expect(stats["total-tickets"]).toBeUint(3);
      expect(stats["attended"]).toBeUint(0);
    });

    it("get-seasonal-trends returns default values for non-existent data", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-seasonal-trends",
        ["u1", "spring-2024"],
        deployer
      );
      expect(result).toBeOk();
      const trends = result.expectOk().expectTuple();
      expect(trends["period-revenue"]).toBeUint(0);
      expect(trends["seasonal-factor"]).toBeUint(100);
    });

    it("get-ticket-utilization-info returns ticket details", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-ticket-utilization-info",
        ["u1"], // First ticket ID
        deployer
      );
      expect(result).toBeOk();
      const utilization = result.expectOk().expectTuple();
      expect(utilization["final-price"]).toBeUint(1500);
      expect(utilization["transfer-count"]).toBeUint(0);
      expect(utilization["marketplace-listed"]).toBeBool(false);
    });
  });

  describe("Admin Analytics Functions", () => {
    beforeEach(() => {
      // Setup event with tickets
      simnet.callPublicFn(
        contractName,
        "create-event",
        ["Admin Test Event", "u300", "u50", "u2000"],
        deployer
      );
      simnet.callPublicFn(contractName, "purchase-ticket", ["u1"], wallet1);
      simnet.callPublicFn(contractName, "purchase-ticket", ["u1"], wallet2);
    });

    it("export-event-report requires admin authorization", () => {
      const { result: unauthorizedResult } = simnet.callPublicFn(
        contractName,
        "export-event-report",
        ["u1"],
        wallet1
      );
      expect(unauthorizedResult).toBeErr();
      expect(unauthorizedResult).toBeErrUint(100); // err-owner-only

      const { result: authorizedResult } = simnet.callPublicFn(
        contractName,
        "export-event-report",
        ["u1"],
        deployer
      );
      expect(authorizedResult).toBeOk();
      const report = authorizedResult.expectOk().expectTuple();
      expect(report).toHaveProperty("event-details");
      expect(report).toHaveProperty("analytics");
      expect(report).toHaveProperty("report-generated-at");
    });

    it("get-scalping-prevention-metrics calculates prevention rate", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "get-scalping-prevention-metrics",
        ["u1"],
        deployer
      );
      expect(result).toBeOk();
      const metrics = result.expectOk().expectTuple();
      expect(metrics["scalping-attempts"]).toBeUint(0);
      expect(metrics["prevention-rate"]).toBeUint(100); // 100% prevention
      expect(metrics["legitimate-purchases"]).toBeUint(2);
      expect(metrics["total-purchases"]).toBeUint(2);
    });

    it("get-attendee-insights provides engagement metrics", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "get-attendee-insights",
        ["u1"],
        deployer
      );
      expect(result).toBeOk();
      const insights = result.expectOk().expectTuple();
      expect(insights["engagement-score"]).toBeUint(0); // No check-ins yet
      const patterns = insights["purchase-pattern"].expectTuple();
      expect(patterns["first-purchase"]).toBeGreaterThan(0);
      expect(patterns["last-purchase"]).toBeGreaterThan(0);
    });

    it("get-pricing-effectiveness analyzes pricing strategy", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "get-pricing-effectiveness",
        ["u1"],
        deployer
      );
      expect(result).toBeOk();
      const effectiveness = result.expectOk().expectTuple();
      expect(effectiveness["revenue-per-ticket"]).toBeUint(2000);
      expect(effectiveness["total-revenue"]).toBeUint(4000); // 2 tickets * 2000
      expect(effectiveness["demand-indicator"]).toBeUint(4); // 2/50 * 100
    });

    it("update-event-popularity sets popularity metrics", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "update-event-popularity",
        ["u1", "u85", "u150"],
        deployer
      );
      expect(result).toBeOk();
      expect(result).toBeBool(true);

      // Verify popularity was set
      const popularityResult = simnet.callReadOnlyFn(
        contractName,
        "get-event-popularity-ranking",
        ["u1"],
        deployer
      );
      const popularity = popularityResult.result.expectOk().expectTuple();
      expect(popularity["popularity-score"]).toBeUint(85);
      expect(popularity["trending-factor"]).toBeUint(3); // High score = factor 3
      expect(popularity["social-engagement"]).toBeUint(150);
    });

    it("record-seasonal-metrics stores time-based data", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "record-seasonal-metrics",
        ["u1", "summer-2024", "u5000", "u25", "u20"],
        deployer
      );
      expect(result).toBeOk();
      expect(result).toBeBool(true);

      // Verify seasonal data was stored
      const trendsResult = simnet.callReadOnlyFn(
        contractName,
        "get-seasonal-trends",
        ["u1", "summer-2024"],
        deployer
      );
      const trends = trendsResult.result.expectOk().expectTuple();
      expect(trends["period-revenue"]).toBeUint(5000);
      expect(trends["period-sales"]).toBeUint(25);
      expect(trends["period-attendance"]).toBeUint(20);
    });
  });

  describe("Edge Cases and Error Handling", () => {
    it("returns error for non-existent event analytics", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-event-analytics",
        ["u999"], // Non-existent event
        deployer
      );
      expect(result).toBeErr();
      expect(result).toBeErrUint(107); // err-no-analytics-data
    });

    it("handles zero division in attendance calculations", () => {
      // Create event but don't purchase tickets
      simnet.callPublicFn(
        contractName,
        "create-event",
        ["Empty Event", "u400", "u10", "u1000"],
        deployer
      );

      const { result } = simnet.callReadOnlyFn(
        contractName,
        "calculate-attendance-rate",
        ["u1"],
        deployer
      );
      expect(result).toBeOk();
      const attendance = result.expectOk().expectTuple();
      expect(attendance["attendance-rate"]).toBeUint(0);
    });

    it("admin functions reject unauthorized users", () => {
      simnet.callPublicFn(
        contractName,
        "create-event",
        ["Auth Test Event", "u500", "u20", "u1000"],
        deployer
      );

      const unauthorizedFunctions = [
        "export-event-report",
        "get-scalping-prevention-metrics",
        "get-attendee-insights",
        "get-pricing-effectiveness",
      ];

      unauthorizedFunctions.forEach((funcName) => {
        const { result } = simnet.callPublicFn(
          contractName,
          funcName,
          ["u1"],
          wallet1 // Not the contract owner
        );
        expect(result).toBeErr();
        expect(result).toBeErrUint(100); // err-owner-only
      });
    });

    it("get-ticket-utilization-info returns error for non-existent ticket", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-ticket-utilization-info",
        ["u999"],
        deployer
      );
      expect(result).toBeErr();
      expect(result).toBeErrUint(101); // err-not-found
    });
  });
});
