import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..", "..");

async function readJson(relativePath) {
  return JSON.parse(await readFile(path.join(root, relativePath), "utf8"));
}

test("closed-beta plan locks cohort, consent, feedback, SLA and device evidence", async () => {
  const plan = await readJson("tests/closed-beta/Closed_Beta_Plan.json");
  assert.equal(plan.schemaVersion, 1);
  assert.equal(plan.planVersion, "closed-beta-v1");
  assert.ok(plan.cohort.minimumConsentedLearners >= 20);
  assert.ok(plan.cohort.minimumMaturedD7Learners > 0);
  assert.ok(plan.cohort.observationDays >= 8);
  assert.equal(plan.cohort.excludeMinors, true);
  assert.equal(plan.consent.telemetryOptional, true);
  assert.equal(plan.consent.rawVoiceCollection, false);
  assert.equal(plan.consent.repositoryMayStorePersonalData, false);
  assert.equal(plan.feedback.canonicalChannel, "in_app_support");
  assert.deepEqual(
    new Set(plan.feedback.structuredInterviewAreas),
    new Set(["onboarding", "learning_path", "lesson", "daily_loop", "feedback"]),
  );
  assert.ok(plan.supportSla.P0.acknowledgeBusinessHours <= 4);
  assert.ok(plan.supportSla.P1.actionPlanBusinessHours <= 16);
  assert.ok(plan.deviceMatrix.minimumDistinctAndroidApiLevels >= 3);
  assert.ok(plan.deviceMatrix.minimumPhysicalDeviceModels >= 2);
  assert.ok(plan.deviceMatrix.minimumPhysicalMicrophonePasses >= 2);
});

test("completion evidence template is aggregate-only and fails closed by default", async () => {
  const evidence = await readJson(
    "tests/closed-beta/evidence/Closed_Beta_Evidence_Template.json",
  );
  assert.equal(evidence.qualitativeFeedback.aggregateOnly, true);
  assert.equal(evidence.observation.consentedLearners, 0);
  assert.equal(evidence.observation.maturedD7Learners, 0);
  assert.deepEqual(evidence.devices, []);
  assert.ok(Object.values(evidence.rehearsals).every((value) => value === false));
  assert.ok(Object.values(evidence.productGate).every((value) => value === false));
  assert.equal(evidence.signOff.productOwner, null);
  assert.equal(evidence.signOff.developer, null);
  assert.equal(evidence.signOff.stage13UnlockedByDeveloper, false);
  const keys = [];
  const collectKeys = (value) => {
    if (Array.isArray(value)) value.forEach(collectKeys);
    else if (value && typeof value === "object") {
      for (const [key, nested] of Object.entries(value)) {
        keys.push(key.toLowerCase());
        collectKeys(nested);
      }
    }
  };
  collectKeys(evidence);
  assert.ok(
    ["email", "phone", "address", "accesstoken", "refreshtoken"]
      .every((forbidden) => !keys.includes(forbidden)),
  );
});
