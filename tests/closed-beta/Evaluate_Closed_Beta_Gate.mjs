import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..");
const plan = JSON.parse(await readFile(
  path.join(root, "tests", "closed-beta", "Closed_Beta_Plan.json"),
  "utf8",
));
const evidenceDirectory = path.join(root, "tests", "closed-beta", "evidence");
const evidenceFiles = (await readdir(evidenceDirectory))
  .filter((name) => name.endsWith(".json") && !name.includes("Template"));

if (evidenceFiles.length === 0) {
  console.error("BLOCKED: no real closed-beta evidence bundle is present.");
  console.error("Use Closed_Beta_Evidence_Template.json after the observation window matures.");
  process.exitCode = 2;
} else if (evidenceFiles.length > 1) {
  console.error("BLOCKED: exactly one evidence bundle must identify the release candidate.");
  process.exitCode = 2;
} else {
  const evidence = JSON.parse(await readFile(path.join(evidenceDirectory, evidenceFiles[0]), "utf8"));
  const blockers = [];
  const requireGate = (condition, message) => {
    if (!condition) blockers.push(message);
  };
  const metric = (code) => evidence.metrics?.[code];
  const hasMetricEvidence = (code) => Number.isInteger(metric(code)?.sampleSize)
    && metric(code).sampleSize > 0
    && typeof metric(code)?.source === "string"
    && metric(code).source.length > 0;

  requireGate(
    typeof evidence.evidenceId === "string"
      && !evidence.evidenceId.startsWith("replace-")
      && typeof evidence.releaseCandidate === "string"
      && evidence.releaseCandidate !== "replace-me",
    "evidence ID or release candidate is missing",
  );
  requireGate(evidence.planVersion === plan.planVersion, "plan version mismatch");
  requireGate(
    evidence.observation?.participationPolicyVersion
      === plan.consent.participationPolicyVersion
      && evidence.observation?.telemetryOptional === true,
    "participation consent version or optional telemetry evidence is invalid",
  );
  const observationStart = Date.parse(evidence.observation?.startedAt);
  const observationEnd = Date.parse(evidence.observation?.endedAt);
  requireGate(
    Number.isFinite(observationStart)
      && Number.isFinite(observationEnd)
      && observationEnd - observationStart >= plan.cohort.observationDays * 86_400_000,
    "observation window is shorter than the plan",
  );
  requireGate(
    evidence.observation?.consentedLearners >= plan.cohort.minimumConsentedLearners,
    "cohort is below the minimum consented learner count",
  );
  requireGate(
    evidence.observation?.maturedD7Learners >= plan.cohort.minimumMaturedD7Learners,
    "D7 cohort has not matured",
  );
  const apiLevels = new Set(evidence.devices?.map((device) => device.androidApiLevel));
  const apiBuckets = new Set(evidence.devices?.map((device) => device.apiBucket));
  const physicalModels = new Set(
    evidence.devices?.filter((device) => device.physical).map((device) => device.modelRef),
  );
  const microphonePasses = evidence.devices?.filter(
    (device) => device.physical && device.microphonePass,
  ).length ?? 0;
  const requiredFeedbackAreas = new Set(plan.feedback.structuredInterviewAreas);
  const coveredFeedbackAreas = new Set(evidence.qualitativeFeedback?.areasCovered ?? []);
  requireGate(
    apiLevels.size >= plan.deviceMatrix.minimumDistinctAndroidApiLevels,
    "Android API-level matrix is incomplete",
  );
  requireGate(
    plan.deviceMatrix.requiredApiBuckets.every((bucket) => apiBuckets.has(bucket)),
    "Android API bucket coverage is incomplete",
  );
  requireGate(
    physicalModels.size >= plan.deviceMatrix.minimumPhysicalDeviceModels,
    "physical-device matrix is incomplete",
  );
  requireGate(
    microphonePasses >= plan.deviceMatrix.minimumPhysicalMicrophonePasses,
    "physical microphone evidence is incomplete",
  );
  requireGate(
    evidence.devices?.length > 0 && evidence.devices.every((device) => device.journeyPass === true),
    "one or more Android journeys did not pass",
  );
  requireGate(
    evidence.devices?.some((device) => device.offlineReconnectPass === true),
    "offline/reconnect device evidence is missing",
  );
  requireGate(
    [...requiredFeedbackAreas].every((area) => coveredFeedbackAreas.has(area))
      && evidence.qualitativeFeedback?.aggregateOnly === true
      && Boolean(evidence.qualitativeFeedback?.decisionSummary),
    "qualitative feedback coverage or decision summary is incomplete",
  );
  requireGate(
    hasMetricEvidence("firstLessonCompletion")
      && Number.isFinite(metric("firstLessonCompletion").value)
      && metric("firstLessonCompletion").value
        >= plan.decisionMetrics.firstLessonCompletionMinimum
      && metric("firstLessonCompletion").value <= 1,
    "first-lesson completion is below target or missing",
  );
  requireGate(
    hasMetricEvidence("unitOneCompletion")
      && Number.isFinite(metric("unitOneCompletion").value)
      && metric("unitOneCompletion").value >= 0
      && metric("unitOneCompletion").value <= 1,
    "Unit 1 completion is missing or invalid",
  );
  requireGate(
    hasMetricEvidence("d1Retention")
      && Number.isFinite(metric("d1Retention").value)
      && metric("d1Retention").value >= 0
      && metric("d1Retention").value <= 1,
    "D1 retention is missing or invalid",
  );
  requireGate(
    hasMetricEvidence("d7Retention")
      && metric("d7Retention").sampleSize >= plan.cohort.minimumMaturedD7Learners
      && Number.isFinite(metric("d7Retention").value)
      && metric("d7Retention").value >= 0
      && metric("d7Retention").value <= 1,
    "D7 retention is missing or invalid",
  );
  requireGate(
    hasMetricEvidence("acknowledgedAttemptLoss")
      && Number.isFinite(metric("acknowledgedAttemptLoss").value)
      && metric("acknowledgedAttemptLoss").value
        <= plan.decisionMetrics.acknowledgedAttemptLossMaximum,
    "acknowledged attempt loss exceeds the maximum or is missing",
  );
  requireGate(
    hasMetricEvidence("duplicateAcceptedAttemptRate")
      && Number.isFinite(metric("duplicateAcceptedAttemptRate").value)
      && metric("duplicateAcceptedAttemptRate").value
        < plan.decisionMetrics.duplicateAcceptedAttemptRateMaximum,
    "duplicate accepted-attempt rate exceeds the maximum or is missing",
  );
  requireGate(
    hasMetricEvidence("androidCrashFreeSession")
      && Number.isFinite(metric("androidCrashFreeSession").value)
      && metric("androidCrashFreeSession").value
        >= plan.decisionMetrics.androidCrashFreeSessionMinimum
      && metric("androidCrashFreeSession").value <= 1,
    "Android crash-free session is below target or missing",
  );
  requireGate(evidence.defects?.openP0 === 0, "open P0 findings remain or are unreported");
  requireGate(
    evidence.defects?.p1WithoutOwnerPlanOrDecision === 0,
    "a P1 finding lacks owner, plan or release decision",
  );
  requireGate(
    evidence.defects?.allSeriousContentReportsClosedLoop === true,
    "serious content-report loop is not closed",
  );
  for (const rehearsal of plan.requiredRehearsals) {
    requireGate(evidence.rehearsals?.[rehearsal] === true, `${rehearsal} rehearsal is missing`);
  }
  requireGate(
    plan.requiredProductGates.every((gate) => evidence.productGate?.[gate] === true),
    "one or more product completion gates are open",
  );
  const validSignOff = (entry, role) => entry?.role === role
    && entry?.decision === "approved"
    && Number.isFinite(Date.parse(entry?.signedAt))
    && typeof entry?.evidenceRef === "string"
    && entry.evidenceRef.length > 0;
  requireGate(
    validSignOff(evidence.signOff?.productOwner, "product_owner"),
    "product owner sign-off is missing or invalid",
  );
  requireGate(
    validSignOff(evidence.signOff?.developer, "developer"),
    "developer sign-off is missing or invalid",
  );
  requireGate(
    evidence.signOff?.stage13UnlockedByDeveloper === true,
    "developer has not unlocked Stage 13 in writing",
  );

  if (blockers.length > 0) {
    console.error(`BLOCKED: ${blockers.length} closed-beta completion gate(s) remain:`);
    blockers.forEach((blocker) => console.error(`- ${blocker}`));
    process.exitCode = 2;
  } else {
    console.log(`PASS: ${evidence.evidenceId} satisfies ${plan.planVersion}.`);
  }
}
