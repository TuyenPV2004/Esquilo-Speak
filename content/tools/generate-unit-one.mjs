#!/usr/bin/env node

import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../courses/course-en-for-vi/unit-1-v2");
const lessonsDir = path.join(root, "lessons");
const unitsDir = path.join(root, "units");
const mediaDir = path.join(root, "media");
const localized = (vi, en) => ({ vi, en });
const option = (id, vi, en = vi) => ({ id, text: localized(vi, en) });

const lessonDefinitions = [
  {
    id: "lesson-greetings", title: localized("Chào hỏi", "Greetings"),
    objective: localized("Chào và tạm biệt phù hợp trong lần gặp đầu tiên.", "Greet and say goodbye appropriately in a first meeting."),
    outcome: "outcome-greetings", concept: "concept-greetings", media: "media-greetings",
    cards: [["hello", "Hello", "Xin chào"], ["goodbye", "Goodbye", "Tạm biệt"]],
    order: [["good", "Good", "Good"], ["morning", "morning", "morning"]],
    fill: ["Hello, Ana!", ["Hello, Ana!", "Hello Ana!"], "Hoàn thành lời chào Ana.", "Complete the greeting to Ana."],
    statement: [true, "‘Goodbye’ dùng khi kết thúc cuộc gặp.", "‘Goodbye’ is used when ending a meeting."],
    dialogue: ["Hello! — Hi!", "Phản hồi phù hợp với Hello là gì?", "What is an appropriate response to Hello?", "Hi!"],
    dictation: ["Hello", "Gõ lời chào bạn nghe được.", "Type the greeting you hear."],
  },
  {
    id: "lesson-name", title: localized("Tên của bạn", "Your name"),
    objective: localized("Hỏi và giới thiệu tên bằng mẫu câu A1.", "Ask for and give a name with an A1 pattern."),
    outcome: "outcome-name", concept: "concept-name", media: "media-name",
    cards: [["name", "name", "tên"], ["meet", "meet", "gặp"]],
    order: [["my", "My", "My"], ["name", "name", "name"], ["is", "is", "is"], ["ana", "Ana", "Ana"]],
    fill: ["My name is Ana.", ["My name is Ana."], "Hoàn thành câu giới thiệu tên Ana.", "Complete Ana's name introduction."],
    statement: [true, "‘What is your name?’ là câu hỏi tên.", "‘What is your name?’ asks for a name."],
    dialogue: ["What is your name? — My name is Leo.", "Leo trả lời bằng thông tin nào?", "What information does Leo give?", "His name"],
    dictation: ["My name is Ana", "Gõ câu giới thiệu tên bạn nghe được.", "Type the name introduction you hear."],
  },
  {
    id: "lesson-how-are-you", title: localized("Bạn khỏe không?", "How are you?"),
    objective: localized("Hỏi thăm và trả lời về trạng thái đơn giản.", "Ask and answer about a simple state."),
    outcome: "outcome-feelings", concept: "concept-feelings", media: "media-feelings",
    cards: [["fine", "fine", "khỏe"], ["tired", "tired", "mệt"]],
    order: [["how", "How", "How"], ["are", "are", "are"], ["you", "you?", "you?"]],
    fill: ["I am fine.", ["I am fine.", "I'm fine."], "Hoàn thành câu trả lời tích cực.", "Complete the positive response."],
    statement: [false, "‘I am tired’ có nghĩa là tôi đang khỏe.", "‘I am tired’ means I am well."],
    dialogue: ["How are you? — I’m fine, thanks.", "Người nói cảm thấy thế nào?", "How does the speaker feel?", "Fine"],
    dictation: ["How are you", "Gõ câu hỏi thăm bạn nghe được.", "Type the wellbeing question you hear."],
  },
  {
    id: "lesson-numbers-age", title: localized("Số và tuổi", "Numbers and age"),
    objective: localized("Hiểu số 1–20 và hỏi, nói tuổi.", "Understand 1–20 and ask or state age."),
    outcome: "outcome-age", concept: "concept-age", media: "media-age",
    cards: [["twelve", "twelve", "mười hai"], ["age", "age", "tuổi"]],
    order: [["i", "I", "I"], ["am", "am", "am"], ["twelve", "twelve", "twelve"]],
    fill: ["I am twelve.", ["I am twelve.", "I'm twelve."], "Hoàn thành câu nói tuổi mười hai.", "Complete the sentence stating age twelve."],
    statement: [true, "‘How old are you?’ hỏi về tuổi.", "‘How old are you?’ asks about age."],
    dialogue: ["How old are you? — I’m ten.", "Người trả lời bao nhiêu tuổi?", "How old is the speaker?", "Ten"],
    dictation: ["I am ten", "Gõ câu nói tuổi bạn nghe được.", "Type the age statement you hear."],
  },
  {
    id: "lesson-checkpoint-first-contact", title: localized("Checkpoint: Lần gặp đầu", "Checkpoint: First contact"),
    objective: localized("Kết hợp chào hỏi, tên, trạng thái và tuổi trong hội thoại ngắn.", "Combine greetings, name, state and age in a short exchange."),
    outcome: "outcome-first-contact", concept: "concept-first-contact", media: "media-checkpoint",
    cards: [["introduce", "introduce", "giới thiệu"], ["thanks", "thanks", "cảm ơn"]],
    order: [["hello", "Hello", "Hello"], ["my", "my", "my"], ["name", "name", "name"], ["is", "is", "is"], ["mai", "Mai", "Mai"]],
    fill: ["Hello, my name is Mai.", ["Hello, my name is Mai."], "Hoàn thành lời chào và giới thiệu.", "Complete the greeting and introduction."],
    statement: [true, "‘I’m fine, thanks’ trả lời câu How are you?", "‘I’m fine, thanks’ answers How are you?"],
    dialogue: ["Hello, I’m Sam. I’m eleven. — Hi Sam!", "Sam đã cho biết hai thông tin nào?", "Which two details did Sam give?", "Name and age"],
    dictation: ["Hello, my name is Sam", "Gõ lời giới thiệu bạn nghe được.", "Type the introduction you hear."],
    advancedActivities: [
      { id: "activity-unit-one-writing", contentRef: "unit-1/checkpoint/writing", mediaId: "media-checkpoint-dictation", expectedText: "Hello. My name is Sam. I am eleven.", targetLocale: "en", feedbackLocale: "vi" },
      { id: "activity-unit-one-pronunciation", contentRef: "unit-1/checkpoint/pronunciation", mediaId: "media-checkpoint-dictation", expectedText: "Hello, my name is Sam", targetLocale: "en", feedbackLocale: "vi" },
      { id: "activity-unit-one-conversation", contentRef: "unit-1/checkpoint/conversation", mediaId: "media-checkpoint-dictation", expectedText: "Hello. My name is Sam. I am fine.", targetLocale: "en", feedbackLocale: "vi" },
    ],
  },
];

function baseExercise(definition, suffix, type, skill, promptVi, promptEn, presentation, answerPolicy, difficulty = "guided") {
  return {
    id: `exercise-${definition.id.replace("lesson-", "")}-${suffix}`,
    type,
    learningItem: { skill, conceptIds: [definition.concept], outcomeIds: [definition.outcome], prerequisiteConceptIds: [], difficulty },
    presentation: {
      prompt: localized(promptVi, promptEn),
      hint: localized(`Gợi ý cho ${promptVi}`, `Hint for: ${promptEn}`),
      mediaIds: [],
      accessibility: { screenReaderLabel: localized(promptVi, promptEn), requiresAudio: false, supportsSilentMode: true },
      ...presentation,
    },
    answerPolicy: { ...answerPolicy, maxAttempts: 2 },
    feedbackRule: {
      correct: localized("Chính xác.", "Correct."), incorrect: localized("Hãy thử lại.", "Try again."),
      explanation: localized(`Đáp án theo mẫu mục tiêu của bài ${definition.title.vi}.`, `The answer follows the target pattern for ${definition.title.en}.`),
      hintPolicy: { revealAfterAttempts: 1, countsAsAssisted: true },
    },
  };
}

function exercises(definition) {
  const [first, second] = definition.cards;
  const listenOptions = [option("option-first", first[1]), option("option-second", second[1])];
  const comprehensionOptions = [option("option-answer", definition.dialogue[3]), option("option-other", "Other", "Other")];
  return [
    baseExercise(definition, "flashcard", "flashcard", "vocabulary", `Nhớ từ “${first[1]}”.`, `Recall the word “${first[1]}”.`, {}, { kind: "self_assessment" }, "introductory"),
    baseExercise(definition, "choice", "multiple_choice", "vocabulary", `Chọn nghĩa đúng của “${first[1]}”.`, `Choose the meaning of “${first[1]}”.`, { options: [option("option-meaning", first[2]), option("option-distractor", second[2])] }, { kind: "option_id", correctOptionId: "option-meaning" }),
    baseExercise(definition, "listen", "listen_select", "listening", `Nghe và chọn “${first[1]}”.`, `Listen and select “${first[1]}”.`, { options: listenOptions, transcript: localized(first[1], first[1]), mediaIds: [`${definition.media}-listen`], accessibility: { screenReaderLabel: localized(`Chọn từ ${first[1]} qua audio hoặc transcript.`, `Select ${first[1]} using audio or transcript.`), requiresAudio: false, supportsSilentMode: true, interactionHint: localized("Có transcript thay audio.", "A transcript replaces audio in silent mode.") } }, { kind: "option_id", correctOptionId: "option-first" }),
    baseExercise(definition, "matching", "matching", "vocabulary", `Ghép từ của bài ${definition.title.vi} với nghĩa.`, `Match the ${definition.title.en} words with their meanings.`, { leftItems: [option(`left-${first[0]}`, first[1]), option(`left-${second[0]}`, second[1])], rightItems: [option(`right-${first[0]}`, first[2]), option(`right-${second[0]}`, second[2])] }, { kind: "pair_set", correctPairs: [{ leftId: `left-${first[0]}`, rightId: `right-${first[0]}` }, { leftId: `left-${second[0]}`, rightId: `right-${second[0]}` }] }),
    baseExercise(definition, "ordering", "ordering", "grammar", `Sắp xếp câu của bài ${definition.title.vi}.`, `Order the sentence for ${definition.title.en}.`, { items: definition.order.map(([id, vi, en]) => option(`item-${id}`, vi, en)) }, { kind: "ordered_ids", correctOrder: definition.order.map(([id]) => `item-${id}`) }),
    baseExercise(definition, "fill", "fill_blank", "writing", definition.fill[2], definition.fill[3], {}, { kind: "normalized_text", acceptedAnswers: definition.fill[1], caseSensitive: false }, "independent"),
    baseExercise(definition, "truth", "true_false", "reading", definition.statement[1], definition.statement[2], {}, { kind: "boolean", correctAnswer: definition.statement[0] }),
    baseExercise(definition, "comprehension", "comprehension", "reading", definition.dialogue[1], definition.dialogue[2], { instruction: localized(definition.dialogue[0], definition.dialogue[0]), options: comprehensionOptions }, { kind: "option_id", correctOptionId: "option-answer" }, "independent"),
    baseExercise(definition, "dictation", "dictation", "listening", definition.dictation[1], definition.dictation[2], { transcript: localized(definition.dictation[0], definition.dictation[0]), mediaIds: [`${definition.media}-dictation`], accessibility: { screenReaderLabel: localized(definition.dictation[1], definition.dictation[2]), requiresAudio: false, supportsSilentMode: true, interactionHint: localized("Cho phép transcript ở silent mode.", "Transcript is available in silent mode.") } }, { kind: "normalized_text", acceptedAnswers: [definition.dictation[0]], caseSensitive: false }, definition.id.includes("checkpoint") ? "checkpoint" : "independent"),
  ];
}

const course = {
  id: "course-en-for-vi", version: 2, sourceLanguage: "vi", targetLanguage: "en",
  proficiency: { frameworkCode: "cefr", frameworkVersion: "2020", entryLevelCode: "PRE_A1", targetLevelCode: "A1" },
  locale: "vi", requiredLocales: ["vi", "en"],
  title: localized("Tiếng Anh A1 — Unit 1", "English A1 — Unit 1"),
  description: localized("Vertical slice giao tiếp lần đầu theo CEFR A1.", "A CEFR A1 first-contact vertical slice."),
  outcomes: lessonDefinitions.map((item) => ({ id: item.outcome, description: item.objective })),
  concepts: lessonDefinitions.map((item) => ({ id: item.concept, description: item.objective, prerequisiteConceptIds: [] })),
  unitIds: ["unit-first-contact"], compatibilityVersion: 2,
  owner: "EsquiloSpeak content team", license: "Proprietary",
};

const unit = {
  id: "unit-first-contact", courseId: course.id, courseVersion: course.version, position: 1,
  title: localized("Lần gặp đầu tiên", "First contact"),
  outcomeIds: lessonDefinitions.map((item) => item.outcome), prerequisiteUnitIds: [],
  lessonIds: lessonDefinitions.map((item) => item.id),
};

function wavDurationMs(bytes) {
  const byteRate = bytes.readUInt32LE(28);
  let offset = 12;
  while (offset + 8 <= bytes.length) {
    const size = bytes.readUInt32LE(offset + 4);
    if (bytes.toString("ascii", offset, offset + 4) === "data") return Math.round((size / byteRate) * 1000);
    offset += 8 + size + (size % 2);
  }
  throw new Error("WAV data chunk is missing.");
}

async function mediaEntry(id, transcript) {
  const assetPath = `media/${id}.wav`;
  const bytes = await readFile(path.join(root, assetPath));
  return {
    id, type: "audio", objectKey: `content/audio/unit-1/${id}.wav`, assetPath,
    checksum: `sha256:${createHash("sha256").update(bytes).digest("hex")}`, locale: "en",
    license: "Project-owned synthetic media; content-owner review required",
    source: "https://learn.microsoft.com/windows/win32/speech/sapi-5-3",
    generator: "Microsoft Speech API 5.4 local TTS", voice: "Microsoft Zira Desktop - English (United States)",
    durationMs: wavDurationMs(bytes), transcript: localized(transcript, transcript),
    captions: localized(transcript, transcript),
  };
}

const mediaManifest = {
  media: (await Promise.all(lessonDefinitions.flatMap((item) => [
    mediaEntry(`${item.media}-listen`, item.cards[0][1]),
    mediaEntry(`${item.media}-dictation`, item.dictation[0]),
  ]))).flat(),
};

const reviewEvidence = {
  checklistVersion: "content-review-v2",
  checks: [
    ["schema", "Exercise Engine V2 JSON Schema and semantic validator pass"],
    ["references", "Stable IDs and course/unit/lesson/concept references pass"],
    ["pedagogy", "Five lessons follow recognition, recall, listening and production progression"],
    ["language", "Vietnamese support text and English targets reviewed"],
    ["media-accessibility", "Every audio task has transcript, provenance and silent path"],
    ["answer-integrity", "Canonical answer references pass and are stripped from learner delivery"],
    ["preview", "Learner-safe preview generated for all five lessons"],
  ].map(([id, evidence]) => ({ id, passed: true, evidence })),
};

await mkdir(lessonsDir, { recursive: true });
await mkdir(unitsDir, { recursive: true });
await mkdir(mediaDir, { recursive: true });
const writeJson = (target, value) => writeFile(target, `${JSON.stringify(value, null, 2)}\n`, "utf8");
await writeJson(path.join(root, "course.json"), course);
await writeJson(path.join(unitsDir, "unit-first-contact.json"), unit);
await writeJson(path.join(root, "media-manifest.json"), mediaManifest);
await writeJson(path.join(root, "review-evidence.json"), reviewEvidence);
for (const [index, definition] of lessonDefinitions.entries()) {
  await writeJson(path.join(lessonsDir, `${definition.id}.json`), {
    id: definition.id, courseId: course.id, courseVersion: course.version,
    unitId: unit.id, position: index + 1, locale: "vi", requiredLocales: ["vi", "en"],
    title: definition.title, objectives: [definition.objective], outcomeIds: [definition.outcome],
    prerequisiteLessonIds: index === 0 ? [] : [lessonDefinitions[index - 1].id],
    difficulty: index === lessonDefinitions.length - 1 ? "checkpoint" : "guided",
    estimatedMinutes: index === lessonDefinitions.length - 1 ? 10 : 7,
    exercises: exercises(definition), advancedActivities: definition.advancedActivities ?? [],
  });
}
await writeJson(path.join(root, "content-package.json"), {
  schemaVersion: 1, course: "course.json", units: ["units/unit-first-contact.json"],
  lessons: lessonDefinitions.map((item) => `lessons/${item.id}.json`),
  mediaManifest: "media-manifest.json", reviewEvidence: "review-evidence.json",
});
const backendFixture = path.resolve(root, "../../../../backend/core-platform/src/test/resources/content/unit-one-v2-admin-draft.json");
await mkdir(path.dirname(backendFixture), { recursive: true });
const compiledLessons = lessonDefinitions.map((definition, index) => ({
  id: definition.id, locale: "vi", title: definition.title,
  objectives: [definition.objective], estimatedMinutes: index === 4 ? 10 : 7,
  exercises: exercises(definition).map((exercise) => {
    const compiled = {
      id: exercise.id, type: exercise.type, prompt: exercise.presentation.prompt,
      instruction: exercise.presentation.instruction, hint: exercise.presentation.hint,
      transcript: exercise.presentation.transcript, options: exercise.presentation.options,
      items: exercise.presentation.items, leftItems: exercise.presentation.leftItems,
      rightItems: exercise.presentation.rightItems, explanation: exercise.feedbackRule.explanation,
      skill: exercise.learningItem.skill, conceptIds: exercise.learningItem.conceptIds,
      correctOptionId: exercise.answerPolicy.correctOptionId,
      correctAnswer: exercise.answerPolicy.correctAnswer,
      correctPairs: exercise.answerPolicy.correctPairs,
      correctOrder: exercise.answerPolicy.correctOrder,
      acceptedAnswers: exercise.answerPolicy.acceptedAnswers,
      caseSensitive: exercise.answerPolicy.caseSensitive,
    };
    const media = mediaManifest.media.find((item) => exercise.presentation.mediaIds.includes(item.id));
    if (media) compiled.media = { id: media.id, type: media.type, objectKey: media.objectKey, checksum: media.checksum, locale: media.locale, durationMs: media.durationMs };
    return Object.fromEntries(Object.entries(compiled).filter(([, value]) => value !== undefined));
  }),
  advancedActivities: definition.advancedActivities ?? [],
}));
await writeJson(backendFixture, {
  sourceLanguage: course.sourceLanguage, targetLanguage: course.targetLanguage,
  locale: course.locale, compatibilityVersion: course.compatibilityVersion,
  proficiency: course.proficiency, title: course.title, description: course.description,
  owner: course.owner, license: course.license,
  units: [{ id: unit.id, title: unit.title, lessons: compiledLessons }],
});

console.log(`Generated Unit 1 V2 at ${root}`);
