import { createHash } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "..", "..");
const manifestPath = path.join(scriptDirectory, "P0_Release_Freeze_Manifest.json");
const fixtureDirectory = path.join(scriptDirectory, "fixtures");

const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
const openApiPath = path.resolve(repositoryRoot, manifest.openapi.path);
assert(
  openApiPath.startsWith(`${repositoryRoot}${path.sep}`),
  "OpenAPI manifest path must stay inside the repository.",
);
const openApi = await readFile(openApiPath, "utf8");
const fixtureFiles = (await readdir(fixtureDirectory))
  .filter((file) => file.endsWith(".json"))
  .sort();

assert(manifest.release === "p0-android-0.4.0", "Unexpected release identifier.");
assert(
  openApi.match(/^  version: (.+)$/m)?.[1] === manifest.openapi.version,
  "OpenAPI version does not match the release manifest.",
);
assertHash(openApi, manifest.openapi.sha256, "OpenAPI contract");
assert(
  fixtureFiles.length === Object.keys(manifest.fixtures).length,
  "Fixture count does not match the release manifest.",
);

const operationIds = mobileOperationIds(openApi);
for (const fixtureFile of fixtureFiles) {
  const fixturePath = path.join(fixtureDirectory, fixtureFile);
  const source = await readFile(fixturePath, "utf8");
  const fixture = JSON.parse(source);
  assertHash(source, manifest.fixtures[fixtureFile], fixtureFile);
  assert(
    fixture.release === manifest.release,
    `${fixtureFile} has a different release identifier.`,
  );
  const fixtureOperations = Object.keys(fixture.operations)
    .filter((operation) => operation !== "problemResponse")
    .sort();
  assertSameValues(
    operationIds,
    fixtureOperations,
    `${fixtureFile} does not cover every mobile OpenAPI operation.`,
  );
  rejectSensitiveKeys(fixture);
  rejectLearnerAnswerLeakage(fixture.operations.getLesson.response);
}

console.log(
  `Validated ${operationIds.length} mobile operations and ${fixtureFiles.length} frozen fixture file(s).`,
);

function mobileOperationIds(source) {
  const lines = source.split(/\r?\n/);
  const values = [];
  let mobilePath = false;
  for (const line of lines) {
    if (/^  \//.test(line)) {
      mobilePath = /^  \/api\/mobile\/v1\//.test(line);
    }
    const match = mobilePath ? line.match(/^\s+operationId:\s+(\S+)\s*$/) : null;
    if (match) {
      values.push(match[1]);
    }
  }
  return values.sort();
}

function rejectSensitiveKeys(value, location = "$") {
  if (Array.isArray(value)) {
    value.forEach((item, index) => rejectSensitiveKeys(item, `${location}[${index}]`));
    return;
  }
  if (value === null || typeof value !== "object") {
    return;
  }
  const forbidden = new Set([
    "accessToken",
    "refreshToken",
    "authorization",
    "password",
    "privateKey",
  ]);
  for (const [key, child] of Object.entries(value)) {
    assert(!forbidden.has(key), `Sensitive key found at ${location}.${key}.`);
    rejectSensitiveKeys(child, `${location}.${key}`);
  }
}

function rejectLearnerAnswerLeakage(lesson) {
  const forbidden = new Set([
    "correctOptionId",
    "correctAnswer",
    "explanation",
  ]);
  visit(lesson, "$.operations.getLesson.response");

  function visit(value, location) {
    if (Array.isArray(value)) {
      value.forEach((item, index) => visit(item, `${location}[${index}]`));
      return;
    }
    if (value === null || typeof value !== "object") {
      return;
    }
    for (const [key, child] of Object.entries(value)) {
      assert(!forbidden.has(key), `Learner answer leakage at ${location}.${key}.`);
      visit(child, `${location}.${key}`);
    }
  }
}

function assertHash(source, expected, label) {
  const canonicalSource = source.replace(/\r\n/g, "\n");
  const actual = createHash("sha256").update(canonicalSource).digest("hex");
  assert(actual === expected, `${label} SHA-256 does not match the release manifest.`);
}

function assertSameValues(expected, actual, message) {
  assert(
    expected.length === actual.length &&
      expected.every((value, index) => value === actual[index]),
    `${message}\nExpected: ${expected.join(", ")}\nActual: ${actual.join(", ")}`,
  );
}

function assert(condition, message) {
  if (!condition) {
    console.error(message);
    process.exitCode = 1;
    throw new Error(message);
  }
}
