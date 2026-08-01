#!/usr/bin/env node

import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const IDENTIFIER = /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/;
const LOCALE = /^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$/;
const SHA256 = /^sha256:[a-fA-F0-9]{64}$/;
const SKILLS = new Set(["reading", "listening", "writing", "speaking", "vocabulary", "grammar"]);
const DIFFICULTIES = new Set(["introductory", "guided", "independent", "checkpoint"]);
const EXERCISE_TYPES = new Set([
  "multiple_choice", "true_false", "flashcard", "matching", "listen_select",
  "ordering", "fill_blank", "dictation", "comprehension",
]);
export const REQUIRED_REVIEW_CHECKS = Object.freeze([
  "schema",
  "references",
  "pedagogy",
  "language",
  "media-accessibility",
  "answer-integrity",
  "preview",
]);

function issue(code, location, message) {
  return { code, location, message };
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

async function readJson(filePath) {
  try {
    return JSON.parse(await readFile(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Không thể đọc JSON ${filePath}: ${error.message}`);
  }
}

function resolvePackageFile(root, relativePath, label) {
  if (typeof relativePath !== "string" || !relativePath.endsWith(".json")) {
    throw new Error(`${label} phải là đường dẫn JSON tương đối.`);
  }
  const resolved = path.resolve(root, relativePath);
  const relative = path.relative(root, resolved);
  if (relative.startsWith("..") || path.isAbsolute(relative)) {
    throw new Error(`${label} không được trỏ ra ngoài content package.`);
  }
  return resolved;
}

export async function loadAuthoringPackage(manifestPath) {
  const absoluteManifest = path.resolve(manifestPath);
  const root = path.dirname(absoluteManifest);
  const manifest = await readJson(absoluteManifest);
  const course = await readJson(resolvePackageFile(root, manifest.course, "course"));
  const units = await Promise.all((manifest.units ?? []).map((entry, index) =>
    readJson(resolvePackageFile(root, entry, `units[${index}]`))));
  const lessons = await Promise.all((manifest.lessons ?? []).map((entry, index) =>
    readJson(resolvePackageFile(root, entry, `lessons[${index}]`))));
  const mediaManifest = await readJson(
    resolvePackageFile(root, manifest.mediaManifest, "mediaManifest"),
  );
  const reviewEvidence = await readJson(
    resolvePackageFile(root, manifest.reviewEvidence, "reviewEvidence"),
  );
  const mediaAssets = new Map();
  for (const media of mediaManifest.media ?? []) {
    if (typeof media.assetPath !== "string") continue;
    try {
      const assetPath = path.resolve(root, media.assetPath);
      const relative = path.relative(root, assetPath);
      if (relative.startsWith("..") || path.isAbsolute(relative)) {
        throw new Error("assetPath points outside the content package");
      }
      const bytes = await readFile(assetPath);
      mediaAssets.set(media.id, {
        checksum: `sha256:${createHash("sha256").update(bytes).digest("hex")}`,
        durationMs: wavDurationMs(bytes),
      });
    } catch (error) {
      mediaAssets.set(media.id, { error: error.message });
    }
  }
  return { root, manifestPath: absoluteManifest, manifest, course, units, lessons, mediaManifest, mediaAssets, reviewEvidence };
}

function wavDurationMs(bytes) {
  if (bytes.length < 44 || bytes.toString("ascii", 0, 4) !== "RIFF" || bytes.toString("ascii", 8, 12) !== "WAVE") return undefined;
  let offset = 12;
  let byteRate;
  let dataSize;
  while (offset + 8 <= bytes.length) {
    const id = bytes.toString("ascii", offset, offset + 4);
    const size = bytes.readUInt32LE(offset + 4);
    if (id === "fmt " && size >= 12) byteRate = bytes.readUInt32LE(offset + 16);
    if (id === "data") dataSize = size;
    offset += 8 + size + (size % 2);
  }
  return byteRate && dataSize ? Math.round((dataSize / byteRate) * 1000) : undefined;
}

function requireObject(value, location, errors) {
  if (!isObject(value)) {
    errors.push(issue("SCHEMA_TYPE", location, "Phải là object."));
    return false;
  }
  return true;
}

function requireIdentifier(value, location, errors) {
  if (typeof value !== "string" || !IDENTIFIER.test(value)) {
    errors.push(issue("SCHEMA_IDENTIFIER", location, "ID phải dùng kebab-case và bắt đầu bằng chữ thường."));
    return false;
  }
  return true;
}

function requirePositiveInteger(value, location, errors) {
  if (!Number.isInteger(value) || value < 1) {
    errors.push(issue("SCHEMA_NUMBER", location, "Phải là số nguyên lớn hơn hoặc bằng 1."));
    return false;
  }
  return true;
}

function requireLocalized(value, requiredLocales, location, errors) {
  if (!requireObject(value, location, errors)) return;
  for (const locale of requiredLocales) {
    if (typeof value[locale] !== "string" || value[locale].trim() === "") {
      errors.push(issue("LOCALE_MISSING", `${location}.${locale}`, `Thiếu nội dung cho locale ${locale}.`));
    }
  }
}

function validateUnique(items, getId, location, errors) {
  const seen = new Set();
  items.forEach((item, index) => {
    const id = getId(item);
    if (typeof id === "string" && seen.has(id)) {
      errors.push(issue("DUPLICATE_ID", `${location}[${index}].id`, `ID ${id} bị trùng.`));
    }
    seen.add(id);
  });
  return seen;
}

function normalizeText(value) {
  return value.normalize("NFKC").trim().toLocaleLowerCase().replace(/\s+/g, " ");
}

function validateCourse(course, errors) {
  if (!requireObject(course, "course", errors)) return [];
  requireIdentifier(course.id, "course.id", errors);
  requirePositiveInteger(course.version, "course.version", errors);
  for (const [field, value] of [["sourceLanguage", course.sourceLanguage], ["targetLanguage", course.targetLanguage], ["locale", course.locale]]) {
    if (typeof value !== "string" || !LOCALE.test(value)) {
      errors.push(issue("SCHEMA_LOCALE", `course.${field}`, "Locale phải là BCP 47 tag hợp lệ."));
    }
  }
  const requiredLocales = Array.isArray(course.requiredLocales) ? course.requiredLocales : [];
  if (requiredLocales.length === 0 || requiredLocales.some((locale) => !LOCALE.test(locale))) {
    errors.push(issue("SCHEMA_LOCALE", "course.requiredLocales", "Phải có ít nhất một locale hợp lệ."));
  }
  if (!requiredLocales.includes(course.sourceLanguage) || !requiredLocales.includes(course.targetLanguage)) {
    errors.push(issue("LOCALE_COVERAGE", "course.requiredLocales", "Phải chứa cả sourceLanguage và targetLanguage."));
  }
  requireLocalized(course.title, requiredLocales, "course.title", errors);
  requireLocalized(course.description, requiredLocales, "course.description", errors);
  requirePositiveInteger(course.compatibilityVersion, "course.compatibilityVersion", errors);
  if (!isObject(course.proficiency)) {
    errors.push(issue("SCHEMA_REQUIRED", "course.proficiency", "Thiếu proficiency reference."));
  }
  if (typeof course.owner !== "string" || course.owner.trim() === "" || typeof course.license !== "string" || course.license.trim() === "") {
    errors.push(issue("SCHEMA_REQUIRED", "course.owner/license", "Owner và license là bắt buộc."));
  }
  if (!Array.isArray(course.outcomes) || course.outcomes.length === 0) {
    errors.push(issue("SCHEMA_REQUIRED", "course.outcomes", "Course phải khai báo outcome."));
  } else {
    validateUnique(course.outcomes, (item) => item?.id, "course.outcomes", errors);
    course.outcomes.forEach((outcome, index) => {
      requireIdentifier(outcome?.id, `course.outcomes[${index}].id`, errors);
      requireLocalized(outcome?.description, requiredLocales, `course.outcomes[${index}].description`, errors);
    });
  }
  if (!Array.isArray(course.concepts) || course.concepts.length === 0) {
    errors.push(issue("SCHEMA_REQUIRED", "course.concepts", "Course phải khai báo concept catalog."));
  } else {
    validateUnique(course.concepts, (item) => item?.id, "course.concepts", errors);
    course.concepts.forEach((concept, index) => {
      requireIdentifier(concept?.id, `course.concepts[${index}].id`, errors);
      requireLocalized(concept?.description, requiredLocales, `course.concepts[${index}].description`, errors);
    });
  }
  if (!Array.isArray(course.unitIds) || course.unitIds.length === 0) {
    errors.push(issue("SCHEMA_REQUIRED", "course.unitIds", "Course phải tham chiếu ít nhất một unit."));
  }
  return requiredLocales;
}

function validateMedia(mediaManifest, mediaAssets, requiredLocales, errors) {
  const media = Array.isArray(mediaManifest?.media) ? mediaManifest.media : [];
  if (!isObject(mediaManifest) || !Array.isArray(mediaManifest.media)) {
    errors.push(issue("SCHEMA_REQUIRED", "mediaManifest.media", "Media manifest phải chứa mảng media."));
    return new Map();
  }
  validateUnique(media, (item) => item?.id, "mediaManifest.media", errors);
  const byId = new Map();
  media.forEach((item, index) => {
    const location = `mediaManifest.media[${index}]`;
    requireIdentifier(item?.id, `${location}.id`, errors);
    byId.set(item?.id, item);
    if (!new Set(["audio", "image"]).has(item?.type)) {
      errors.push(issue("MEDIA_TYPE", `${location}.type`, "Media type phải là audio hoặc image."));
    }
    if (typeof item?.objectKey !== "string" || item.objectKey.trim() === "") {
      errors.push(issue("MEDIA_METADATA", `${location}.objectKey`, "Thiếu objectKey."));
    }
    if (typeof item?.checksum !== "string" || !SHA256.test(item.checksum)) {
      errors.push(issue("MEDIA_CHECKSUM", `${location}.checksum`, "Checksum phải có dạng sha256:<64 hex>."));
    }
    if (item?.assetPath !== undefined) {
      const asset = mediaAssets?.get(item.id);
      if (!asset || asset.error) {
        errors.push(issue("MEDIA_ASSET_MISSING", `${location}.assetPath`, `Không thể đọc media asset: ${asset?.error ?? "missing"}.`));
      } else {
        if (asset.checksum !== item.checksum) errors.push(issue("MEDIA_ASSET_CHECKSUM", `${location}.checksum`, "Checksum không khớp media asset."));
        if (item.type === "audio" && asset.durationMs !== item.durationMs) errors.push(issue("MEDIA_ASSET_DURATION", `${location}.durationMs`, "durationMs không khớp WAV asset."));
      }
    }
    if (typeof item?.license !== "string" || item.license.trim() === "" || typeof item?.source !== "string" || item.source.trim() === "") {
      errors.push(issue("MEDIA_PROVENANCE", location, "Media phải có license và source."));
    }
    if (item?.type === "audio") {
      if (!Number.isInteger(item.durationMs) || item.durationMs < 1) {
        errors.push(issue("MEDIA_METADATA", `${location}.durationMs`, "Audio phải có durationMs dương."));
      }
      requireLocalized(item.transcript, requiredLocales, `${location}.transcript`, errors);
    }
    if (item?.type === "image" && item.decorative !== true) {
      requireLocalized(item.altText, requiredLocales, `${location}.altText`, errors);
      if (!Number.isInteger(item.width) || !Number.isInteger(item.height)) {
        errors.push(issue("MEDIA_METADATA", location, "Image không decorative phải có width và height."));
      }
    }
  });
  return byId;
}

function validateReview(reviewEvidence, errors) {
  if (!requireObject(reviewEvidence, "reviewEvidence", errors)) return;
  if (typeof reviewEvidence.checklistVersion !== "string" || reviewEvidence.checklistVersion.trim() === "") {
    errors.push(issue("REVIEW_EVIDENCE", "reviewEvidence.checklistVersion", "Thiếu checklistVersion."));
  }
  const checks = Array.isArray(reviewEvidence.checks) ? reviewEvidence.checks : [];
  const seen = validateUnique(checks, (check) => check?.id, "reviewEvidence.checks", errors);
  for (const required of REQUIRED_REVIEW_CHECKS) {
    if (!seen.has(required)) {
      errors.push(issue("REVIEW_EVIDENCE", "reviewEvidence.checks", `Thiếu review check ${required}.`));
    }
  }
  checks.forEach((check, index) => {
    if (check?.passed !== true || typeof check?.evidence !== "string" || check.evidence.trim() === "") {
      errors.push(issue("REVIEW_EVIDENCE", `reviewEvidence.checks[${index}]`, "Review check phải pass và có evidence có thể truy vết."));
    }
  });
}

export function validateAuthoringPackage(pkg) {
  const errors = [];
  const warnings = [];
  if (pkg.manifest?.schemaVersion !== 1) {
    errors.push(issue("SCHEMA_VERSION", "content-package.json.schemaVersion", "Chỉ hỗ trợ schemaVersion 1."));
  }
  const requiredLocales = validateCourse(pkg.course, errors);
  const units = Array.isArray(pkg.units) ? pkg.units : [];
  const lessons = Array.isArray(pkg.lessons) ? pkg.lessons : [];
  const unitIds = validateUnique(units, (unit) => unit?.id, "units", errors);
  const lessonIds = validateUnique(lessons, (lesson) => lesson?.id, "lessons", errors);
  const courseOutcomeIds = new Set((pkg.course?.outcomes ?? []).map((outcome) => outcome.id));
  const courseConceptIds = new Set((pkg.course?.concepts ?? []).map((concept) => concept.id));
  const coveredOutcomes = new Set();
  const usedConcepts = new Set();
  const mediaById = validateMedia(pkg.mediaManifest, pkg.mediaAssets, requiredLocales, errors);

  const declaredUnitIds = pkg.course?.unitIds ?? [];
  declaredUnitIds.forEach((id, index) => {
    if (!unitIds.has(id)) errors.push(issue("REFERENCE_MISSING", `course.unitIds[${index}]`, `Không tìm thấy unit ${id}.`));
  });
  units.forEach((unit, unitIndex) => {
    const location = `units[${unitIndex}]`;
    requireIdentifier(unit?.id, `${location}.id`, errors);
    if (unit?.courseId !== pkg.course?.id || unit?.courseVersion !== pkg.course?.version) {
      errors.push(issue("REFERENCE_VERSION", location, "Unit phải thuộc đúng course ID/version."));
    }
    requirePositiveInteger(unit?.position, `${location}.position`, errors);
    requireLocalized(unit?.title, requiredLocales, `${location}.title`, errors);
    for (const prerequisiteId of unit?.prerequisiteUnitIds ?? []) {
      if (!unitIds.has(prerequisiteId) || prerequisiteId === unit.id) {
        errors.push(issue("REFERENCE_MISSING", `${location}.prerequisiteUnitIds`, `Prerequisite unit ${prerequisiteId} không hợp lệ.`));
      }
    }
    for (const outcomeId of unit?.outcomeIds ?? []) {
      if (!courseOutcomeIds.has(outcomeId)) errors.push(issue("REFERENCE_MISSING", `${location}.outcomeIds`, `Outcome ${outcomeId} chưa khai báo ở course.`));
    }
    for (const lessonId of unit?.lessonIds ?? []) {
      if (!lessonIds.has(lessonId)) errors.push(issue("REFERENCE_MISSING", `${location}.lessonIds`, `Không tìm thấy lesson ${lessonId}.`));
    }
  });

  const exerciseIds = new Set();
  const promptOwners = new Map();
  lessons.forEach((lesson, lessonIndex) => {
    const location = `lessons[${lessonIndex}]`;
    requireIdentifier(lesson?.id, `${location}.id`, errors);
    if (lesson?.courseId !== pkg.course?.id || lesson?.courseVersion !== pkg.course?.version || !unitIds.has(lesson?.unitId)) {
      errors.push(issue("REFERENCE_VERSION", location, "Lesson phải tham chiếu đúng course version và unit."));
    }
    const owningUnit = units.find((unit) => unit.id === lesson?.unitId);
    if (owningUnit && !(owningUnit.lessonIds ?? []).includes(lesson.id)) {
      errors.push(issue("REFERENCE_MISSING", location, `Unit ${owningUnit.id} chưa tham chiếu lesson ${lesson.id}.`));
    }
    requirePositiveInteger(lesson?.position, `${location}.position`, errors);
    requirePositiveInteger(lesson?.estimatedMinutes, `${location}.estimatedMinutes`, errors);
    if (!DIFFICULTIES.has(lesson?.difficulty)) errors.push(issue("DIFFICULTY", `${location}.difficulty`, "Difficulty không hợp lệ."));
    requireLocalized(lesson?.title, requiredLocales, `${location}.title`, errors);
    for (const [objectiveIndex, objective] of (lesson?.objectives ?? []).entries()) {
      requireLocalized(objective, requiredLocales, `${location}.objectives[${objectiveIndex}]`, errors);
    }
    for (const prerequisiteId of lesson?.prerequisiteLessonIds ?? []) {
      if (!lessonIds.has(prerequisiteId) || prerequisiteId === lesson.id) errors.push(issue("REFERENCE_MISSING", `${location}.prerequisiteLessonIds`, `Prerequisite lesson ${prerequisiteId} không hợp lệ.`));
    }
    for (const outcomeId of lesson?.outcomeIds ?? []) {
      if (!courseOutcomeIds.has(outcomeId)) errors.push(issue("REFERENCE_MISSING", `${location}.outcomeIds`, `Outcome ${outcomeId} chưa khai báo ở course.`));
      coveredOutcomes.add(outcomeId);
    }
    if (!Array.isArray(lesson?.exercises) || lesson.exercises.length === 0) {
      errors.push(issue("SCHEMA_REQUIRED", `${location}.exercises`, "Lesson phải có exercise."));
      return;
    }
    lesson.exercises.forEach((exercise, exerciseIndex) => {
      const exerciseLocation = `${location}.exercises[${exerciseIndex}]`;
      requireIdentifier(exercise?.id, `${exerciseLocation}.id`, errors);
      if (exerciseIds.has(exercise?.id)) errors.push(issue("DUPLICATE_ID", `${exerciseLocation}.id`, `Exercise ID ${exercise.id} bị trùng trong course version.`));
      exerciseIds.add(exercise?.id);
      if (!EXERCISE_TYPES.has(exercise?.type)) errors.push(issue("EXERCISE_TYPE", `${exerciseLocation}.type`, "Exercise type chưa được Exercise Engine V2 hỗ trợ."));
      const learningItem = exercise?.learningItem;
      if (!isObject(learningItem) || !SKILLS.has(learningItem.skill) || !DIFFICULTIES.has(learningItem.difficulty)) {
        errors.push(issue("LEARNING_ITEM", `${exerciseLocation}.learningItem`, "Learning item phải có skill và difficulty hợp lệ."));
      }
      for (const conceptId of learningItem?.conceptIds ?? []) {
        if (!courseConceptIds.has(conceptId)) errors.push(issue("REFERENCE_MISSING", `${exerciseLocation}.learningItem.conceptIds`, `Concept ${conceptId} chưa khai báo ở course.`));
        usedConcepts.add(conceptId);
      }
      for (const outcomeId of learningItem?.outcomeIds ?? []) {
        if (!courseOutcomeIds.has(outcomeId) || !(lesson?.outcomeIds ?? []).includes(outcomeId)) errors.push(issue("REFERENCE_MISSING", `${exerciseLocation}.learningItem.outcomeIds`, `Outcome ${outcomeId} không thuộc lesson/course.`));
        coveredOutcomes.add(outcomeId);
      }
      for (const conceptId of learningItem?.prerequisiteConceptIds ?? []) {
        if (!courseConceptIds.has(conceptId)) errors.push(issue("REFERENCE_MISSING", `${exerciseLocation}.learningItem.prerequisiteConceptIds`, `Prerequisite concept ${conceptId} chưa khai báo.`));
      }
      const presentation = exercise?.presentation;
      requireLocalized(presentation?.prompt, requiredLocales, `${exerciseLocation}.presentation.prompt`, errors);
      requireLocalized(presentation?.hint, requiredLocales, `${exerciseLocation}.presentation.hint`, errors);
      requireLocalized(presentation?.accessibility?.screenReaderLabel, requiredLocales, `${exerciseLocation}.presentation.accessibility.screenReaderLabel`, errors);
      const targetPrompt = presentation?.prompt?.[pkg.course?.targetLanguage];
      if (typeof targetPrompt === "string") {
        const normalized = normalizeText(targetPrompt);
        if (promptOwners.has(normalized)) errors.push(issue("CONTENT_REPETITION", `${exerciseLocation}.presentation.prompt`, `Prompt trùng với ${promptOwners.get(normalized)}.`));
        promptOwners.set(normalized, exercise.id);
      }
      const mediaIds = presentation?.mediaIds ?? [];
      if (mediaIds.length > 1) errors.push(issue("MEDIA_LIMIT", `${exerciseLocation}.presentation.mediaIds`, "Runtime hiện chỉ hỗ trợ tối đa một media cho mỗi exercise."));
      for (const mediaId of mediaIds) if (!mediaById.has(mediaId)) errors.push(issue("REFERENCE_MISSING", `${exerciseLocation}.presentation.mediaIds`, `Không tìm thấy media ${mediaId}.`));
      const feedback = exercise?.feedbackRule;
      requireLocalized(feedback?.correct, requiredLocales, `${exerciseLocation}.feedbackRule.correct`, errors);
      requireLocalized(feedback?.incorrect, requiredLocales, `${exerciseLocation}.feedbackRule.incorrect`, errors);
      requireLocalized(feedback?.explanation, requiredLocales, `${exerciseLocation}.feedbackRule.explanation`, errors);
      if (!Number.isInteger(feedback?.hintPolicy?.revealAfterAttempts) || feedback.hintPolicy.revealAfterAttempts < 1) errors.push(issue("HINT_POLICY", `${exerciseLocation}.feedbackRule.hintPolicy`, "Hint policy phải khai báo revealAfterAttempts dương."));
      if (["multiple_choice", "listen_select", "comprehension"].includes(exercise?.type)) {
        const options = Array.isArray(presentation?.options) ? presentation.options : [];
        if (options.length < 2) errors.push(issue("ANSWER_INTEGRITY", `${exerciseLocation}.presentation.options`, "Dạng chọn đáp án cần ít nhất hai option."));
        const optionIds = validateUnique(options, (option) => option?.id, `${exerciseLocation}.presentation.options`, errors);
        options.forEach((option, optionIndex) => requireLocalized(option?.text, requiredLocales, `${exerciseLocation}.presentation.options[${optionIndex}].text`, errors));
        if (exercise?.answerPolicy?.kind !== "option_id" || !optionIds.has(exercise?.answerPolicy?.correctOptionId)) errors.push(issue("ANSWER_INTEGRITY", `${exerciseLocation}.answerPolicy`, "correctOptionId phải tham chiếu đúng một option."));
      }
      if (exercise?.type === "true_false" && (exercise?.answerPolicy?.kind !== "boolean" || typeof exercise?.answerPolicy?.correctAnswer !== "boolean")) errors.push(issue("ANSWER_INTEGRITY", `${exerciseLocation}.answerPolicy`, "True/false cần boolean correctAnswer."));
      if (exercise?.type === "flashcard" && exercise?.answerPolicy?.kind !== "self_assessment") errors.push(issue("ANSWER_INTEGRITY", `${exerciseLocation}.answerPolicy`, "Flashcard cần self_assessment policy."));
      if (exercise?.type === "matching") {
        const left = Array.isArray(presentation?.leftItems) ? presentation.leftItems : [];
        const right = Array.isArray(presentation?.rightItems) ? presentation.rightItems : [];
        const leftIds = validateUnique(left, (item) => item?.id, `${exerciseLocation}.presentation.leftItems`, errors);
        const rightIds = validateUnique(right, (item) => item?.id, `${exerciseLocation}.presentation.rightItems`, errors);
        [...left, ...right].forEach((item, itemIndex) => requireLocalized(item?.text, requiredLocales, `${exerciseLocation}.presentation.matchItems[${itemIndex}].text`, errors));
        const pairs = exercise?.answerPolicy?.correctPairs ?? [];
        if (left.length < 2 || right.length < 2 || exercise?.answerPolicy?.kind !== "pair_set" || pairs.length !== left.length || pairs.some((pair) => !leftIds.has(pair?.leftId) || !rightIds.has(pair?.rightId))) errors.push(issue("ANSWER_INTEGRITY", `${exerciseLocation}.answerPolicy`, "Matching cần hai tập item và một cặp hợp lệ cho mỗi item bên trái."));
      }
      if (exercise?.type === "ordering") {
        const items = Array.isArray(presentation?.items) ? presentation.items : [];
        const itemIds = validateUnique(items, (item) => item?.id, `${exerciseLocation}.presentation.items`, errors);
        items.forEach((item, itemIndex) => requireLocalized(item?.text, requiredLocales, `${exerciseLocation}.presentation.items[${itemIndex}].text`, errors));
        const order = exercise?.answerPolicy?.correctOrder ?? [];
        if (items.length < 2 || exercise?.answerPolicy?.kind !== "ordered_ids" || order.length !== items.length || order.some((id) => !itemIds.has(id))) errors.push(issue("ANSWER_INTEGRITY", `${exerciseLocation}.answerPolicy`, "Ordering cần correctOrder chứa đúng toàn bộ item."));
      }
      if (["fill_blank", "dictation"].includes(exercise?.type)) {
        const accepted = exercise?.answerPolicy?.acceptedAnswers ?? [];
        if (exercise?.answerPolicy?.kind !== "normalized_text" || accepted.length === 0 || accepted.some((value) => typeof value !== "string" || value.trim() === "")) errors.push(issue("ANSWER_INTEGRITY", `${exerciseLocation}.answerPolicy`, "Dạng text cần ít nhất một accepted answer."));
      }
      if (["listen_select", "dictation"].includes(exercise?.type)) requireLocalized(presentation?.transcript, requiredLocales, `${exerciseLocation}.presentation.transcript`, errors);
    });
    const activityIds = new Set();
    for (const [activityIndex, activity] of (lesson.advancedActivities ?? []).entries()) {
      const activityLocation = `${location}.advancedActivities[${activityIndex}]`;
      requireIdentifier(activity?.id, `${activityLocation}.id`, errors);
      if (activityIds.has(activity?.id)) errors.push(issue("DUPLICATE_ID", `${activityLocation}.id`, "Advanced activity ID bị trùng trong lesson."));
      activityIds.add(activity?.id);
      if (typeof activity?.contentRef !== "string" || activity.contentRef.trim() === "" || typeof activity?.expectedText !== "string" || activity.expectedText.trim() === "") errors.push(issue("ADVANCED_ACTIVITY", activityLocation, "Advanced activity cần contentRef và expectedText."));
      if (!mediaById.has(activity?.mediaId)) errors.push(issue("REFERENCE_MISSING", `${activityLocation}.mediaId`, `Không tìm thấy media ${activity?.mediaId}.`));
      if (!LOCALE.test(activity?.targetLocale ?? "") || !LOCALE.test(activity?.feedbackLocale ?? "")) errors.push(issue("LOCALE_FORMAT", activityLocation, "Advanced activity locale không hợp lệ."));
    }
  });
  for (const outcomeId of courseOutcomeIds) if (!coveredOutcomes.has(outcomeId)) errors.push(issue("CONCEPT_COVERAGE", "course.outcomes", `Outcome ${outcomeId} chưa có lesson/exercise evidence.`));
  for (const conceptId of courseConceptIds) if (!usedConcepts.has(conceptId)) warnings.push(issue("CONCEPT_COVERAGE", "course.concepts", `Concept ${conceptId} chưa được exercise sử dụng.`));
  validateReview(pkg.reviewEvidence, errors);
  return { valid: errors.length === 0, errors, warnings };
}

function compactMedia(media) {
  if (!media) return undefined;
  const result = { id: media.id, type: media.type, objectKey: media.objectKey, checksum: media.checksum, locale: media.locale };
  if (media.durationMs !== undefined) result.durationMs = media.durationMs;
  if (media.altText !== undefined) result.altText = media.altText;
  return result;
}

function compileExercise(exercise, mediaById) {
  const result = {
    id: exercise.id,
    type: exercise.type,
    prompt: exercise.presentation.prompt,
    explanation: exercise.feedbackRule.explanation,
    skill: exercise.learningItem.skill,
    conceptIds: exercise.learningItem.conceptIds,
  };
  for (const key of ["instruction", "hint", "transcript", "options", "items", "leftItems", "rightItems"]) {
    if (exercise.presentation[key] !== undefined) result[key] = exercise.presentation[key];
  }
  const mediaId = exercise.presentation.mediaIds?.[0];
  if (mediaId) result.media = compactMedia(mediaById.get(mediaId));
  if (["multiple_choice", "listen_select", "comprehension"].includes(exercise.type)) {
    result.correctOptionId = exercise.answerPolicy.correctOptionId;
  } else if (exercise.type === "true_false") {
    result.correctAnswer = exercise.answerPolicy.correctAnswer;
  } else if (exercise.type === "matching") {
    result.correctPairs = exercise.answerPolicy.correctPairs;
  } else if (exercise.type === "ordering") {
    result.correctOrder = exercise.answerPolicy.correctOrder;
  } else if (["fill_blank", "dictation"].includes(exercise.type)) {
    result.acceptedAnswers = exercise.answerPolicy.acceptedAnswers;
    result.caseSensitive = exercise.answerPolicy.caseSensitive ?? false;
  }
  return result;
}

export function compileAdminDraft(pkg) {
  const mediaById = new Map((pkg.mediaManifest?.media ?? []).map((media) => [media.id, media]));
  const lessonsByUnit = new Map();
  for (const lesson of pkg.lessons) {
    if (!lessonsByUnit.has(lesson.unitId)) lessonsByUnit.set(lesson.unitId, []);
    lessonsByUnit.get(lesson.unitId).push(lesson);
  }
  const units = [...pkg.units].sort((a, b) => a.position - b.position).map((unit) => ({
    id: unit.id,
    title: unit.title,
    lessons: (lessonsByUnit.get(unit.id) ?? []).sort((a, b) => a.position - b.position).map((lesson) => ({
      id: lesson.id,
      locale: lesson.locale,
      title: lesson.title,
      objectives: lesson.objectives,
      estimatedMinutes: lesson.estimatedMinutes,
      exercises: lesson.exercises.map((exercise) => compileExercise(exercise, mediaById)),
      advancedActivities: lesson.advancedActivities ?? [],
    })),
  }));
  const course = pkg.course;
  return {
    sourceLanguage: course.sourceLanguage,
    targetLanguage: course.targetLanguage,
    locale: course.locale,
    compatibilityVersion: course.compatibilityVersion,
    proficiency: course.proficiency,
    title: course.title,
    description: course.description,
    owner: course.owner,
    license: course.license,
    units,
  };
}

export function compileLearnerPreview(pkg) {
  const draft = structuredClone(compileAdminDraft(pkg));
  for (const unit of draft.units) for (const lesson of unit.lessons) for (const exercise of lesson.exercises) {
    delete exercise.correctOptionId;
    delete exercise.correctAnswer;
    delete exercise.correctPairs;
    delete exercise.correctOrder;
    delete exercise.acceptedAnswers;
    delete exercise.caseSensitive;
    delete exercise.explanation;
    if (exercise.type === "true_false") {
      exercise.options = [
        { id: "true", text: { en: "True", vi: "Đúng" } },
        { id: "false", text: { en: "False", vi: "Sai" } },
      ];
    }
  }
  return { courseId: pkg.course.id, courseVersion: pkg.course.version, ...draft };
}

function escapeHtml(value) {
  return String(value).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");
}

export function renderLearnerPreview(pkg, locale = pkg.course.targetLanguage) {
  const preview = compileLearnerPreview(pkg);
  const lessonHtml = preview.units.flatMap((unit) => unit.lessons.map((lesson) => {
    const exercises = lesson.exercises.map((exercise) => {
      const options = (exercise.options ?? []).map((option) => `<li>${escapeHtml(option.text[locale] ?? option.text[pkg.course.locale] ?? option.id)}</li>`).join("");
      return `<article><h3>${escapeHtml(exercise.prompt[locale] ?? exercise.prompt[pkg.course.locale])}</h3><p><code>${escapeHtml(exercise.type)}</code></p><ol>${options}</ol></article>`;
    }).join("");
    return `<section><h2>${escapeHtml(lesson.title[locale] ?? lesson.title[pkg.course.locale])}</h2>${exercises}</section>`;
  })).join("");
  const checksum = createHash("sha256").update(JSON.stringify(preview)).digest("hex");
  return `<!doctype html><html lang="${escapeHtml(locale)}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(preview.title[locale] ?? preview.title[pkg.course.locale])}</title><style>body{font:16px system-ui;max-width:760px;margin:2rem auto;padding:0 1rem;color:#17202a}article{border:1px solid #ccd6dd;border-radius:12px;padding:1rem;margin:1rem 0}code{background:#eef2f5;padding:.2rem .4rem;border-radius:4px}</style></head><body><header><h1>${escapeHtml(preview.title[locale] ?? preview.title[pkg.course.locale])}</h1><p>Course ${escapeHtml(preview.courseId)} · version ${preview.courseVersion} · learner-safe preview · sha256:${checksum}</p></header>${lessonHtml}</body></html>`;
}

function assertValid(result) {
  if (!result.valid) {
    const details = result.errors.map((item) => `${item.code} ${item.location}: ${item.message}`).join("\n");
    throw new Error(`Content package không hợp lệ:\n${details}`);
  }
}

async function requestJson(url, options, fetchImpl = fetch) {
  const response = await fetchImpl(url, options);
  const body = await response.text();
  const parsed = body ? JSON.parse(body) : {};
  if (!response.ok) throw new Error(`Backend ${response.status}: ${parsed.detail ?? parsed.message ?? body}`);
  return parsed;
}

function backendConfig(options) {
  const baseUrl = options["base-url"] ?? process.env.ESQUILO_API_URL;
  const token = process.env.ESQUILO_CONTENT_TOKEN;
  if (!baseUrl) throw new Error("Thiếu --base-url hoặc ESQUILO_API_URL.");
  if (!token) throw new Error("Thiếu ESQUILO_CONTENT_TOKEN. CLI không nhận token qua command line.");
  return { baseUrl: baseUrl.replace(/\/$/, ""), token };
}

export async function importDraft(pkg, config, fetchImpl = fetch) {
  const validation = validateAuthoringPackage(pkg);
  assertValid(validation);
  return requestJson(`${config.baseUrl}/api/admin/v1/content/courses/${pkg.course.id}/versions/${pkg.course.version}`, {
    method: "PUT",
    headers: { authorization: `Bearer ${config.token}`, "content-type": "application/json" },
    body: JSON.stringify(compileAdminDraft(pkg)),
  }, fetchImpl);
}

export async function transitionPackage(pkg, state, effectiveAt, config, fetchImpl = fetch) {
  const body = { targetState: state };
  if (effectiveAt) body.effectiveAt = effectiveAt;
  if (state === "review") body.reviewEvidence = pkg.reviewEvidence;
  return requestJson(`${config.baseUrl}/api/admin/v1/content/courses/${pkg.course.id}/versions/${pkg.course.version}/transitions`, {
    method: "POST",
    headers: { authorization: `Bearer ${config.token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  }, fetchImpl);
}

function parseOptions(args) {
  const positional = [];
  const options = {};
  for (let index = 0; index < args.length; index += 1) {
    const value = args[index];
    if (value.startsWith("--")) {
      const name = value.slice(2);
      options[name] = args[index + 1];
      index += 1;
    } else positional.push(value);
  }
  return { positional, options };
}

async function main() {
  const [command, ...rest] = process.argv.slice(2);
  const { positional, options } = parseOptions(rest);
  const manifestPath = positional[0];
  if (!command || !manifestPath) {
    throw new Error("Dùng: content-pipeline.mjs <validate|compile|preview|import-draft|transition|rollback> <content-package.json> [options]");
  }
  const pkg = await loadAuthoringPackage(manifestPath);
  const validation = validateAuthoringPackage(pkg);
  if (command !== "rollback") assertValid(validation);
  for (const warning of validation.warnings) console.warn(`WARNING ${warning.code} ${warning.location}: ${warning.message}`);
  if (command === "validate") {
    console.log(`VALID ${pkg.course.id}@${pkg.course.version}: ${pkg.units.length} unit, ${pkg.lessons.length} lesson, ${pkg.lessons.reduce((total, lesson) => total + lesson.exercises.length, 0)} exercise.`);
    return;
  }
  if (command === "compile") {
    if (!options.out) throw new Error("compile cần --out <file.json>.");
    await writeFile(path.resolve(options.out), `${JSON.stringify(compileAdminDraft(pkg), null, 2)}\n`, "utf8");
    console.log(`Đã ghi admin draft: ${path.resolve(options.out)}`);
    return;
  }
  if (command === "preview") {
    if (!options.out) throw new Error("preview cần --out <file.html>.");
    await writeFile(path.resolve(options.out), renderLearnerPreview(pkg, options.locale), "utf8");
    console.log(`Đã ghi learner-safe preview: ${path.resolve(options.out)}`);
    return;
  }
  const config = backendConfig(options);
  if (command === "import-draft") {
    const result = await importDraft(pkg, config);
    console.log(`Draft ${result.courseId}@${result.version}: ${result.state}`);
    return;
  }
  if (command === "transition") {
    const state = positional[1];
    if (!state) throw new Error("transition cần state.");
    const result = await transitionPackage(pkg, state, options["effective-at"], config);
    console.log(`Content ${result.courseId}@${result.version}: ${result.state}`);
    return;
  }
  if (command === "rollback") {
    const targetVersion = Number(positional[1]);
    if (!Number.isInteger(targetVersion) || targetVersion < 1) throw new Error("rollback cần target version dương.");
    const result = await requestJson(`${config.baseUrl}/api/admin/v1/content/courses/${pkg.course.id}/rollbacks`, {
      method: "POST",
      headers: { authorization: `Bearer ${config.token}`, "content-type": "application/json" },
      body: JSON.stringify({ targetVersion }),
    });
    console.log(`Rollback ${result.courseId}@${result.version}: ${result.state}`);
    return;
  }
  throw new Error(`Command không hỗ trợ: ${command}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
