import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import {
  compileAdminDraft,
  compileLearnerPreview,
  importDraft,
  loadAuthoringPackage,
  renderLearnerPreview,
  transitionPackage,
  validateAuthoringPackage,
} from "../../content/tools/content-pipeline.mjs";

const repositoryRoot = path.resolve(import.meta.dirname, "..", "..");
const manifestPath = path.join(
  repositoryRoot,
  "content",
  "examples",
  "authoring-demo",
  "content-package.json",
);

async function packageFixture() {
  return loadAuthoringPackage(manifestPath);
}

test("all contract JSON documents parse", async () => {
  const schemaDirectory = path.join(repositoryRoot, "contracts", "schema");
  const files = (await readdir(schemaDirectory)).filter((file) => file.endsWith(".json"));
  assert.ok(files.length >= 10);
  for (const file of files) {
    const content = await readFile(path.join(schemaDirectory, file), "utf8");
    assert.doesNotThrow(() => JSON.parse(content));
  }
});

test("authoring demo passes structural and semantic validation", async () => {
  const result = validateAuthoringPackage(await packageFixture());
  assert.equal(result.valid, true, JSON.stringify(result.errors, null, 2));
  assert.deepEqual(result.warnings, []);
});

test("validator returns actionable duplicate, locale, media and answer errors", async () => {
  const pkg = structuredClone(await packageFixture());
  const exercise = pkg.lessons[0].exercises[0];
  exercise.presentation.options[1].id = exercise.presentation.options[0].id;
  delete exercise.presentation.prompt.vi;
  exercise.answerPolicy.correctOptionId = "option-missing";
  pkg.mediaManifest.media[0].checksum = "not-a-checksum";

  const result = validateAuthoringPackage(pkg);
  assert.equal(result.valid, false);
  const codes = new Set(result.errors.map((error) => error.code));
  assert.ok(codes.has("DUPLICATE_ID"));
  assert.ok(codes.has("LOCALE_MISSING"));
  assert.ok(codes.has("MEDIA_CHECKSUM"));
  assert.ok(codes.has("ANSWER_INTEGRITY"));
  assert.ok(result.errors.every((error) => error.location && error.message));
});

test("compiler separates authoring answers from learner preview", async () => {
  const pkg = await packageFixture();
  const admin = compileAdminDraft(pkg);
  const learner = compileLearnerPreview(pkg);
  assert.equal(admin.units[0].lessons[0].exercises[0].correctOptionId, "option-name");
  assert.equal(admin.units[0].lessons[0].exercises[1].correctAnswer, true);
  const learnerJson = JSON.stringify(learner);
  assert.doesNotMatch(learnerJson, /correctOptionId|correctAnswer|explanation/);

  const html = renderLearnerPreview(pkg, "en");
  assert.match(html, /Complete: My ___ is Ana\./);
  assert.doesNotMatch(html, /correctOptionId|correctAnswer|Use name in the pattern/);
});

test("backend integration fixture stays equal to compiler output", async () => {
  const pkg = await packageFixture();
  const fixturePath = path.join(
    repositoryRoot,
    "backend",
    "core-platform",
    "src",
    "test",
    "resources",
    "content",
    "authoring-demo-admin-draft.json",
  );
  const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
  assert.deepEqual(fixture, compileAdminDraft(pkg));
});

test("HTTP adapter imports compiled draft without source-only fields", async () => {
  const pkg = await packageFixture();
  let request;
  const fetchImpl = async (url, options) => {
    request = { url, options };
    return {
      ok: true,
      status: 201,
      text: async () => JSON.stringify({ courseId: pkg.course.id, version: 1, state: "draft" }),
    };
  };
  const result = await importDraft(pkg, { baseUrl: "http://backend.test", token: "test-only" }, fetchImpl);
  assert.equal(result.state, "draft");
  assert.match(request.url, /course-authoring-demo\/versions\/1$/);
  const body = JSON.parse(request.options.body);
  assert.equal(body.units[0].lessons[0].exercises[0].prompt.en, "Complete: My ___ is Ana.");
  assert.equal(body.units[0].lessons[0].exercises[0].learningItem, undefined);
  assert.equal(request.options.headers.authorization, "Bearer test-only");
});

test("review transition sends checklist evidence", async () => {
  const pkg = await packageFixture();
  let body;
  const fetchImpl = async (_url, options) => {
    body = JSON.parse(options.body);
    return { ok: true, status: 200, text: async () => JSON.stringify({ courseId: pkg.course.id, version: 1, state: "review" }) };
  };
  await transitionPackage(pkg, "review", undefined, { baseUrl: "http://backend.test", token: "test-only" }, fetchImpl);
  assert.equal(body.targetState, "review");
  assert.equal(body.reviewEvidence.checklistVersion, "content-review-v1");
  assert.ok(body.reviewEvidence.checks.every((check) => check.passed));
});
