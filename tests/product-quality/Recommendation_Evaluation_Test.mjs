import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

const datasetPath = fileURLToPath(
  new URL('./Recommendation_Evaluation_Dataset.json', import.meta.url),
);
const dataset = JSON.parse(readFileSync(datasetPath, 'utf8'));

function recommend(testCase) {
  const due = [...testCase.dueConcepts].sort();
  if (due.length > 0) {
    return {
      kind: 'review_due',
      conceptId: due[0],
      explanationCode: 'REVIEW_DUE_FIRST',
    };
  }
  const mastery = Object.entries(testCase.mastery).sort(
    ([leftId, leftScore], [rightId, rightScore]) =>
      leftScore - rightScore || leftId.localeCompare(rightId),
  );
  if (mastery.length === 0) {
    return {
      kind: 'start_learning',
      conceptId: null,
      explanationCode: 'NO_LEARNING_EVIDENCE',
    };
  }
  if (mastery[0][1] < dataset.weakMasteryThreshold) {
    return {
      kind: 'strengthen_weak_concept',
      conceptId: mastery[0][0],
      explanationCode: 'LOWEST_MASTERY_FIRST',
    };
  }
  return {
    kind: 'continue_learning',
    conceptId: null,
    explanationCode: 'NO_DUE_OR_WEAK_CONCEPT',
  };
}

assert.equal(dataset.policyKey, 'daily_next_learning');
assert.ok(dataset.guardrails.primaryMetric);
assert.equal(dataset.guardrails.acknowledgedAttemptLossMaximum, 0);
assert.equal(dataset.guardrails.privacyViolationMaximum, 0);
assert.equal(dataset.guardrails.safetyIncidentMaximum, 0);
if (dataset.candidateVersion > 1 && dataset.promotionRule.requiresRollbackVersionAfterV1) {
  assert.ok(dataset.rollbackVersion, 'A post-V1 candidate requires a rollback version.');
}

let passed = 0;
for (const testCase of dataset.cases) {
  const first = recommend(testCase);
  const replay = recommend(testCase);
  assert.deepEqual(replay, first, `${testCase.id} must replay deterministically`);
  assert.equal(first.kind, testCase.expectedKind, `${testCase.id}: kind`);
  assert.equal(first.conceptId, testCase.expectedConceptId, `${testCase.id}: concept`);
  assert.equal(
    first.explanationCode,
    testCase.expectedExplanationCode,
    `${testCase.id}: explanation`,
  );
  passed += 1;
}

const accuracy = passed / dataset.cases.length;
assert.ok(accuracy >= dataset.promotionRule.minimumCaseAccuracy);
console.log(`Recommendation evaluation ${passed}/${dataset.cases.length} passed.`);
