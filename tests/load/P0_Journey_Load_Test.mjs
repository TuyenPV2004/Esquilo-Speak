import { performance } from "node:perf_hooks";
import process from "node:process";
import { randomUUID } from "node:crypto";

const options = parseOptions(process.argv.slice(2));
const samples = [];
let failures = 0;

await request("mutation", "POST", "/internal/dev/token", undefined, false);
const workers = Array.from({ length: options.concurrency }, (_, worker) =>
  runWorker(worker),
);
await Promise.all(workers);

const reads = samples.filter((sample) => sample.kind === "read");
const mutations = samples.filter((sample) => sample.kind === "mutation");
const result = {
  generatedAt: new Date().toISOString(),
  baseUrl: options.baseUrl,
  concurrency: options.concurrency,
  iterationsPerWorker: options.iterations,
  requestCount: samples.length,
  failureCount: failures,
  errorRate: samples.length === 0 ? 1 : failures / samples.length,
  reads: summarize(reads),
  mutations: summarize(mutations),
  targets: {
    availability: 0.995,
    readP95Ms: 500,
    mutationP95Ms: 800,
  },
};
console.log(JSON.stringify(result, null, 2));

const passed =
  result.errorRate <= 0.005 &&
  result.reads.p95Ms <= result.targets.readP95Ms &&
  result.mutations.p95Ms <= result.targets.mutationP95Ms;
if (options.enforce && !passed) {
  process.exitCode = 1;
}

async function runWorker(worker) {
  for (let iteration = 0; iteration < options.iterations; iteration += 1) {
    const tokenResponse = await request(
      "mutation",
      "POST",
      "/internal/dev/token",
      undefined,
      false,
    );
    const token = tokenResponse.accessToken;
    await request("read", "GET", "/api/mobile/v1/languages");
    await request(
      "read",
      "GET",
      "/api/mobile/v1/courses?sourceLanguage=vi&targetLanguage=en",
    );
    await request(
      "read",
      "GET",
      "/api/mobile/v1/courses/course-en-for-vi/lessons",
    );
    await request(
      "read",
      "GET",
      "/api/mobile/v1/lessons/lesson-basic-greetings",
    );
    await request(
      "mutation",
      "POST",
      "/api/mobile/v1/attempts",
      {
        clientAttemptId: randomUUID(),
        courseId: "course-en-for-vi",
        lessonId: "lesson-basic-greetings",
        lessonVersion: 1,
        exerciseId: "exercise-choose-hello",
        selectedOptionId: "option-hello",
        occurredAt: new Date().toISOString(),
        responseTimeMs: 250 + worker,
      },
      true,
      token,
    );
    await request(
      "read",
      "GET",
      "/api/mobile/v1/progress/courses/course-en-for-vi",
      undefined,
      true,
      token,
    );
    await request("read", "GET", "/api/mobile/v1/mastery", undefined, true, token);
    await request("read", "GET", "/api/mobile/v1/reviews", undefined, true, token);
  }
}

async function request(
  kind,
  method,
  path,
  body,
  authenticated = false,
  token,
) {
  const headers = { "X-Correlation-ID": `load-${randomUUID()}` };
  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
  }
  if (authenticated) {
    headers.Authorization = `Bearer ${token}`;
  }
  if (method === "POST" && path.endsWith("/attempts")) {
    headers["Idempotency-Key"] = randomUUID();
  }
  const started = performance.now();
  let response;
  try {
    response = await fetch(`${options.baseUrl}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const elapsedMs = performance.now() - started;
    samples.push({ kind, elapsedMs, status: response.status });
    if (!response.ok) {
      failures += 1;
      throw new Error(`${method} ${path} returned ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    if (response === undefined) {
      samples.push({ kind, elapsedMs: performance.now() - started, status: 0 });
      failures += 1;
    }
    throw error;
  }
}

function summarize(values) {
  const ordered = values.map((value) => value.elapsedMs).sort((a, b) => a - b);
  return {
    count: ordered.length,
    p50Ms: percentile(ordered, 0.5),
    p95Ms: percentile(ordered, 0.95),
    p99Ms: percentile(ordered, 0.99),
    maxMs: ordered.length === 0 ? 0 : round(ordered.at(-1)),
  };
}

function percentile(ordered, ratio) {
  if (ordered.length === 0) {
    return 0;
  }
  return round(ordered[Math.min(ordered.length - 1, Math.ceil(ordered.length * ratio) - 1)]);
}

function round(value) {
  return Math.round(value * 100) / 100;
}

function parseOptions(args) {
  const values = new Map();
  for (let index = 0; index < args.length; index += 2) {
    values.set(args[index], args[index + 1]);
  }
  const baseUrl = values.get("--base-url") ?? "http://localhost:8080";
  const concurrency = Number.parseInt(values.get("--concurrency") ?? "4", 10);
  const iterations = Number.parseInt(values.get("--iterations") ?? "10", 10);
  const enforce = values.get("--enforce") !== "false";
  if (!/^https?:\/\/[^/]+(?::\d+)?$/.test(baseUrl)) {
    throw new Error("--base-url must be an HTTP(S) origin without a path.");
  }
  if (!Number.isInteger(concurrency) || concurrency < 1 || concurrency > 32) {
    throw new Error("--concurrency must be between 1 and 32.");
  }
  if (!Number.isInteger(iterations) || iterations < 1 || iterations > 1000) {
    throw new Error("--iterations must be between 1 and 1000.");
  }
  return { baseUrl, concurrency, iterations, enforce };
}
