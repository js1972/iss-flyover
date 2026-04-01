export const HEALTH_SOURCE_KEYS = [
  "location",
  "issNow",
  "tle",
  "forecast",
  "track",
  "weather",
  "reverseGeocode",
  "appVersion"
];

export function createSourceHealth() {
  return {
    status: "idle",
    reason: "",
    usingFallback: false,
    accuracy: "",
    lastSuccessAt: 0,
    lastAttemptAt: 0
  };
}

export function createHealthState() {
  const sources = {};
  HEALTH_SOURCE_KEYS.forEach((key) => {
    sources[key] = createSourceHealth();
  });
  return {
    sources,
    banner: {
      level: "info",
      message: "",
      meta: "",
      action: null,
      hidden: true
    }
  };
}

export function beginSourceAttempt(source, timestamp = Date.now()) {
  source.lastAttemptAt = timestamp;
}

export function markSourceOk(source, details = {}) {
  const now = details.lastSuccessAt || details.lastAttemptAt || Date.now();
  source.status = "ok";
  source.reason = details.reason || "";
  source.usingFallback = Boolean(details.usingFallback);
  source.accuracy = details.accuracy || "";
  source.lastAttemptAt = details.lastAttemptAt || now;
  source.lastSuccessAt = now;
  return source;
}

export function markSourceDegraded(source, details = {}) {
  const now = details.lastAttemptAt || Date.now();
  source.status = "degraded";
  source.reason = details.reason || "";
  source.usingFallback = details.usingFallback !== undefined ? Boolean(details.usingFallback) : source.usingFallback;
  source.accuracy = details.accuracy !== undefined ? details.accuracy : source.accuracy;
  source.lastAttemptAt = now;
  if (details.lastSuccessAt !== undefined) {
    source.lastSuccessAt = details.lastSuccessAt;
  }
  return source;
}

export function markSourceUnavailable(source, details = {}) {
  const now = details.lastAttemptAt || Date.now();
  source.status = "unavailable";
  source.reason = details.reason || "";
  source.usingFallback = Boolean(details.usingFallback);
  source.accuracy = details.accuracy || "";
  source.lastAttemptAt = now;
  if (details.lastSuccessAt !== undefined) {
    source.lastSuccessAt = details.lastSuccessAt;
  }
  return source;
}

export function setHealthBanner(health, banner = {}) {
  health.banner = {
    level: banner.level || "info",
    message: banner.message || "",
    meta: banner.meta || "",
    action: banner.action || null,
    hidden: Boolean(banner.hidden)
  };
  return health.banner;
}

export function hasUsableData(source) {
  return source.lastSuccessAt > 0 && source.status !== "unavailable";
}
