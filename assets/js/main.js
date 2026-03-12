
import { state } from "./state.js";
import { ISS_NOW_URL, ISS_POS_URL, ISS_TLE_URL, WEATHER_URL, REVERSE_GEOCODE_URL, STORAGE_KEY, FORECAST_DAYS, GLOBE_VISUALS, MAP_VISUALS, PLANET_VISUALS } from "./config.js";
import { appEl, bootOverlay, bootStageEl, bootMetaEl, mapEl, globeViewEl, globeEl, skyViewEl, skyCanvas, tonightGridEl, passList, skyEventsList, actionStatusEl, locateButton, locationLabelEl, locationCoordsEl, locationMetaEl, forecastPanelEl, skyPanelEl, conditionsPanelEl, previewBanner, previewText, previewExitButton, shareToast, refreshButton, timelinePanel, timelineToggle, timelineContent, timelineList, conditionsList } from "./dom.js";
import { formatCoord, formatTime, formatDateTime, formatCompactBestTime, formatTonightMoment, isCompactMobileLayout, isNarrowMobileLayout } from "./utils.js";
import { METEOR_SHOWERS, DEEP_SKY_TARGETS, BRIGHT_STARS, CONSTELLATIONS } from "./data/catalogs.js";

const AUTO_REFRESH_STALE_MS = 15 * 60 * 1000;
const AU_STATE_CODES = {
  "Western Australia": "WA",
  "New South Wales": "NSW",
  Victoria: "VIC",
  Queensland: "QLD",
  Tasmania: "TAS",
  "South Australia": "SA",
  "Northern Territory": "NT",
  "Australian Capital Territory": "ACT"
};

const BOOT_STAGE_COPY = {
  iss: {
    title: "Fetching live orbital data",
    meta: "Pulling the latest ISS position, orbit path, and forecast samples."
  },
  weather: {
    title: "Checking weather and moonlight",
    meta: "Estimating cloud cover, wind, and moonlight conditions for tonight."
  },
  sky: {
    title: "Scoring tonight's best targets",
    meta: "Ranking visible passes, sky highlights, and dark-sky quality."
  },
  finalizing: {
    title: "Preparing the night plan",
    meta: "Rendering tonight cards, schedules, and forecast lists."
  }
};

function getCoordsLine(lat, lon) {
  return `${formatCoord(lat)}, ${formatCoord(lon)}`;
}

function getUserSourceMeta(source = "") {
  if (!source) return "Saved location";
  return source
    .replace(/ \(saved\)$/u, "")
    .replace(" (saved)", "")
    .replace("IP location (approximate)", "Approximate location")
    .replace("Device location", "Device location")
    .replace("Manual coordinates", "Manual coordinates");
}

function getStoredLocationSource(source = "") {
  return source.replace(/ \(saved\)$/u, "");
}

function getReverseGeocodeLanguage() {
  const preferred = navigator.languages?.find(Boolean) || navigator.language || "en";
  return preferred.toLowerCase().replace("_", "-");
}

function toRegionCode(countryCode, regionName) {
  if (!regionName) return "";
  if (countryCode === "AU") return AU_STATE_CODES[regionName] || regionName;
  return regionName;
}

function normalizeLocalityName(value = "") {
  return value
    .replace(/^City of /iu, "")
    .replace(/^Shire of /iu, "")
    .trim();
}

function parseReverseGeocode(data) {
  const address = data?.address || {};
  const countryCode = (address.country_code || "").toUpperCase();
  const locality = normalizeLocalityName(
    address.city
    || address.town
    || address.suburb
    || address.village
    || address.municipality
    || address.city_district
    || address.hamlet
    || address.county
    || ""
  );
  const regionName = address.state || address.region || address.province || address.state_district || address.county || "";
  const regionCode = toRegionCode(countryCode, regionName);
  let label = "";

  if (locality && regionCode && locality.toLowerCase() !== regionCode.toLowerCase()) {
    label = `${locality}, ${regionCode}`;
  } else if (locality && regionName && locality.toLowerCase() !== regionName.toLowerCase()) {
    label = `${locality}, ${regionName}`;
  } else {
    label = locality || regionCode || regionName || "";
  }

  if (!label && typeof data?.display_name === "string") {
    label = data.display_name.split(",").slice(0, 2).map((part) => part.trim()).filter(Boolean).join(", ");
  }

  return {
    label: label || "",
    regionCode: regionCode || ""
  };
}

async function reverseGeocodeLocation(lat, lon) {
  const url = new URL(REVERSE_GEOCODE_URL);
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("lat", lat.toFixed(5));
  url.searchParams.set("lon", lon.toFixed(5));
  url.searchParams.set("zoom", "12");
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("accept-language", getReverseGeocodeLanguage());

  const response = await fetch(url.toString(), {
    cache: "no-store",
    headers: { Accept: "application/json" }
  });
  if (!response.ok) {
    throw new Error(`Reverse geocode failed (${response.status})`);
  }
  return parseReverseGeocode(await response.json());
}

function pickVisibleBadges(descriptors) {
  const ordered = [...descriptors].sort((a, b) => a.priority - b.priority);
  if (!isNarrowMobileLayout()) return ordered;
  return ordered.slice(0, 2);
}

function renderBadgeSpans(descriptors, compact = false) {
  if (!descriptors.length) return "";
  const visible = compact ? pickVisibleBadges(descriptors) : descriptors;
  if (!visible.length) return "";
  return visible.map((badge) => `<span class="badge ${badge.className}">${badge.label}</span>`).join("");
}

function describePassQuality(pass) {
  let elevationDescriptor = "Low-angle pass";
  if (pass.maxEl >= 70) elevationDescriptor = "Exceptional overhead pass";
  else if (pass.maxEl >= 55) elevationDescriptor = "High-elevation pass";
  else if (pass.maxEl >= 35) elevationDescriptor = "Good-elevation pass";

  const moonDescriptor = pass.moonlightSummary
    ? pass.moonlightSummary.replace(/^Moonlight:\s*/i, "")
    : "Balanced moonlight";
  return `${elevationDescriptor} • ${moonDescriptor}`;
}

function updateForecastNoteCopy() {
  const note = document.getElementById("forecast-note");
  if (!note) return;
  note.textContent = isCompactMobileLayout()
    ? "Tap a pass to preview it in User View. BEST remains ISS-first."
    : "Tap any pass to preview it. BEST is ranked by elevation then duration (sky context only breaks ties).";
}

function showToast(message, duration = 2200) {
  if (!shareToast) return;
  shareToast.textContent = message;
  shareToast.classList.add("show");
  window.clearTimeout(showToast.timerId);
  showToast.timerId = window.setTimeout(() => {
    shareToast.classList.remove("show");
  }, duration);
}
showToast.timerId = null;

function triggerHaptic(type) {
  if (typeof navigator.vibrate !== "function") return;
  if (type === "start") navigator.vibrate(10);
  else if (type === "success") navigator.vibrate([16, 28, 16]);
  else if (type === "error") navigator.vibrate([24, 40, 24]);
  else navigator.vibrate(8);
}

function setRefreshingUI(active) {
  state.ui.refreshing = active;
  const showSectionVeil = active && state.ui.hasCompletedInitialLoad;
  if (refreshButton) {
    refreshButton.classList.toggle("is-loading", active);
    refreshButton.disabled = active;
    refreshButton.textContent = active ? "Refreshing..." : "Refresh Now";
  }
  if (tonightGridEl) {
    tonightGridEl.classList.toggle("loading", showSectionVeil);
    tonightGridEl.setAttribute("aria-busy", String(active));
  }
  if (forecastPanelEl) {
    forecastPanelEl.classList.toggle("loading", showSectionVeil);
    forecastPanelEl.setAttribute("aria-busy", String(active));
  }
  if (skyPanelEl) {
    skyPanelEl.classList.toggle("loading", showSectionVeil);
    skyPanelEl.setAttribute("aria-busy", String(active));
  }
  if (conditionsPanelEl) {
    conditionsPanelEl.classList.toggle("loading", showSectionVeil);
    conditionsPanelEl.setAttribute("aria-busy", String(active));
  }
  if (actionStatusEl && active) {
    actionStatusEl.textContent = "Updating forecasts...";
  }
}

function setActionStatus(text) {
  if (!actionStatusEl) return;
  actionStatusEl.textContent = text;
}

function getLocalDateKey(date = new Date()) {
  return new Date(date).toLocaleDateString("en-CA");
}

function shouldAutoRefresh() {
  if (!state.ui.hasCompletedInitialLoad || state.ui.refreshing) return false;
  const now = Date.now();
  const dateChanged = state.ui.lastRefreshLocalDate && state.ui.lastRefreshLocalDate !== getLocalDateKey(now);
  if (dateChanged) return true;
  if (!state.ui.lastSuccessfulRefreshAt) return true;
  return (now - state.ui.lastSuccessfulRefreshAt) >= AUTO_REFRESH_STALE_MS;
}

function maybeAutoRefresh() {
  if (!shouldAutoRefresh()) return;
  refreshAll({ interactive: false });
}

function setTimelineExpanded(expanded) {
  state.ui.timelineExpanded = expanded;
  if (timelinePanel) timelinePanel.classList.toggle("is-collapsed", !expanded);
  if (timelineContent) timelineContent.hidden = !expanded;
  if (timelineToggle) {
    timelineToggle.textContent = expanded ? "Hide" : "Show";
    timelineToggle.setAttribute("aria-expanded", String(expanded));
  }
}

function setBootStage(stage) {
  state.ui.bootStage = stage;
  const copy = BOOT_STAGE_COPY[stage] || BOOT_STAGE_COPY.iss;
  if (bootStageEl) bootStageEl.textContent = copy.title;
  if (bootMetaEl) bootMetaEl.textContent = copy.meta;
}

function setBooting(active) {
  state.ui.booting = active;
  if (appEl) {
    appEl.classList.toggle("is-booting", active);
    if (active) {
      appEl.classList.remove("is-boot-revealing");
    }
    appEl.inert = active;
    appEl.setAttribute("aria-busy", String(active));
  }
  if (bootOverlay) {
    bootOverlay.hidden = false;
    bootOverlay.classList.toggle("is-ready", !active);
  }
}

function finishInitialBoot() {
  if (state.ui.hasCompletedInitialLoad) return;
  state.ui.booting = false;
  state.ui.bootReady = true;
  state.ui.hasCompletedInitialLoad = true;
  setBootStage("finalizing");
  if (appEl) {
    appEl.classList.remove("is-booting");
    appEl.classList.add("is-boot-revealing");
    appEl.setAttribute("aria-busy", "false");
    window.setTimeout(() => appEl.classList.remove("is-boot-revealing"), 720);
  }
  if (bootOverlay) {
    bootOverlay.classList.add("is-ready");
    window.setTimeout(() => {
      if (bootOverlay) bootOverlay.hidden = true;
    }, window.matchMedia("(prefers-reduced-motion: reduce)").matches ? 0 : 280);
  }
  if (appEl) appEl.inert = false;
}

function getSkyQualityHint(event) {
  const bodiesCount = event.bodies?.length || 1;
  const score = Math.round(event.darkSkyScore || 0);
  const focusTs = event.focusTs || event.start;
  return `${bodiesCount} bodies • dark-sky ${score}/100 • ${formatTime(new Date(focusTs * 1000))} local`;
}

function getTopSkyBadgeSpans(descriptors) {
  const topDescriptors = [...descriptors]
    .sort((a, b) => a.priority - b.priority)
    .slice(0, 2);
  return renderBadgeSpans(topDescriptors, false);
}

function getSecondarySkyBadgeSpans(descriptors) {
  const secondaryDescriptors = descriptors
    .filter((badge) => !["best", "dark-sky", "bright-moon"].includes(badge.className))
    .slice(0, 1);
  return renderBadgeSpans(secondaryDescriptors, false);
}

function getSecondarySkyDetailLine(event) {
  return event.details || "";
}

function getSkyEventWindowLabel(event) {
  if (event.type === "alignment") return "Alignment peak";
  if (event.type === "lunar-eclipse") return "Eclipse peak";
  if (event.type === "solar-eclipse") return "Eclipse peak";
  if (event.type === "meteor-shower") return "Meteor peak";
  if (event.skyWindow === "dawn") return "Morning peak";
  if (event.skyWindow === "evening") return "Evening peak";
  return "Viewing peak";
}

function getSkyEventDisplayLabel(event) {
  if (!event) return "";
  if (event.type === "group" && event.bodies?.length) {
    return event.bodies.join(" + ");
  }
  return event.title;
}

function getEventFocusTs(event) {
  return event?.focusTs || event?.start || 0;
}

function isPassActive(pass, nowTs) {
  return Boolean(pass) && pass.start <= nowTs && pass.end >= nowTs;
}

function isSkyEventActive(event, nowTs) {
  return Boolean(event) && event.start <= nowTs && event.end >= nowTs;
}

function formatPreviewMoment(timestampSec) {
  return `${formatDateTime(new Date(timestampSec * 1000))} local`;
}

function buildPassShareMessage(pass) {
  const dateLabel = formatDateTime(new Date(pass.start * 1000));
  const details = [
    `Max elevation ${pass.maxEl.toFixed(0)}°`,
    `Visible ${pass.duration} min`
  ];
  if (pass.skySummary) details.push(pass.skySummary);
  if (pass.moonPhase) details.push(`Moon ${pass.moonPhase.icon} ${pass.moonPhase.name} (${pass.moonPhase.illuminationPct}%)`);
  return `ISS Flyover Explorer\n${dateLabel}\n${details.join(" • ")}`;
}

function buildSkyEventShareMessage(event) {
  const focusTs = event.focusTs || event.start;
  const focusLabel = formatDateTime(new Date(focusTs * 1000));
  const moonSummary = event.moonPhase
    ? `Moon ${event.moonPhase.icon} ${event.moonPhase.name} (${event.moonPhase.illuminationPct}%)`
    : "Moon phase unavailable";
  return `ISS Flyover Explorer\n${event.title}\n${event.details}\nBest around ${focusLabel}\n${moonSummary}`;
}

async function shareTextPayload(title, text) {
  const url = window.location.href;
  if (navigator.share) {
    try {
      await navigator.share({ title, text, url });
      return;
    } catch (error) {
      if (error?.name === "AbortError") return;
      console.warn("Web Share failed, falling back to clipboard.", error);
    }
  }

  const fallback = `${title}\n${text}\n${url}`;
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(fallback);
      showToast("Share text copied to clipboard.");
      return;
    } catch (error) {
      console.warn("Clipboard fallback failed.", error);
    }
  }

  window.prompt("Copy this share text:", fallback);
}

async function sharePass(pass) {
  if (!pass) {
    showToast("No pass available to share.");
    return;
  }
  const title = `ISS pass ${formatDateTime(new Date(pass.start * 1000))}`;
  await shareTextPayload(title, buildPassShareMessage(pass));
}

async function shareSkyEvent(event) {
  if (!event) {
    showToast("No sky event available to share.");
    return;
  }
  await shareTextPayload(event.title, buildSkyEventShareMessage(event));
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function geolocationErrorMessage(error) {
  if (!window.isSecureContext) {
    return "Location needs HTTPS (or localhost) in this browser.";
  }
  const code = error?.code;
  if (code === 1) return "Location permission denied.";
  if (code === 2) return "Location temporarily unavailable from your device provider.";
  if (code === 3) return "Location request timed out.";
  return "Unable to access your location right now.";
}

function getCurrentPositionOnce(options) {
  return new Promise((resolve, reject) => {
    navigator.geolocation.getCurrentPosition(resolve, reject, options);
  });
}

async function requestDeviceLocationWithRetry() {
  const attempts = [
    { enableHighAccuracy: true, timeout: 12000, maximumAge: 0 },
    { enableHighAccuracy: false, timeout: 18000, maximumAge: 120000 },
    { enableHighAccuracy: false, timeout: 22000, maximumAge: 600000 }
  ];

  let lastError = null;
  for (let i = 0; i < attempts.length; i++) {
    try {
      return await getCurrentPositionOnce(attempts[i]);
    } catch (error) {
      lastError = error;
      // Permission denied should not be retried.
      if (error?.code === 1) break;
      if (i < attempts.length - 1) await sleep(700);
    }
  }
  throw lastError || new Error("Location unavailable");
}

async function requestApproxLocationFromIp() {
  const providers = [
    {
      url: "https://ipapi.co/json/",
      label: "IP location",
      parse: (data) => ({ lat: Number(data?.latitude), lon: Number(data?.longitude) })
    },
    {
      url: "https://ipwho.is/",
      label: "IP location",
      parse: (data) => {
        if (data?.success === false) return null;
        return { lat: Number(data?.latitude), lon: Number(data?.longitude) };
      }
    }
  ];

  for (const provider of providers) {
    try {
      const response = await fetch(provider.url, { cache: "no-store" });
      if (!response.ok) continue;
      const data = await response.json();
      const point = provider.parse(data);
      if (Number.isFinite(point?.lat) && Number.isFinite(point?.lon)) {
        return { ...point, source: provider.label };
      }
    } catch (error) {
      console.warn(`Approx location lookup failed for ${provider.url}`, error);
    }
  }
  return null;
}

function getMoonPhaseInfo(date) {
  const illumination = SunCalc.getMoonIllumination(date);
  const phaseValue = ((illumination?.phase ?? 0) + 1) % 1;
  const illuminationPct = Math.round((illumination?.fraction ?? 0) * 100);
  const band = PLANET_VISUALS.moonPhaseBands.find((entry) => phaseValue <= entry.max) || PLANET_VISUALS.moonPhaseBands[0];
  return {
    phaseValue,
    illuminationPct,
    name: band.name,
    icon: band.icon
  };
}

function getMoonlightQuality({ illuminationPct, moonVisible }) {
  let quality = "balanced";
  if (!moonVisible || illuminationPct <= PLANET_VISUALS.darkSkyIlluminationPctMax) {
    quality = "dark";
  } else if (moonVisible && illuminationPct >= PLANET_VISUALS.brightMoonIlluminationPctMin) {
    quality = "bright";
  }

  // Informational score only; this does not influence ISS best-pass selection.
  let darkSkyScore = 100 - illuminationPct;
  if (!moonVisible) darkSkyScore = Math.min(100, darkSkyScore + 25);
  darkSkyScore = Math.min(100, Math.max(0, darkSkyScore));
  return { quality, darkSkyScore };
}

function moonlightQualityLabel(quality) {
  if (quality === "dark") return "Dark sky";
  if (quality === "bright") return "Bright moon";
  return "Balanced";
}

function moonlightBadgeValue(quality) {
  if (quality === "dark") return "dark";
  if (quality === "bright") return "bright";
  return "";
}

function formatMoonPhaseLine(moonPhase, prefix) {
  if (!moonPhase) return "";
  return `${prefix}: ${moonPhase.icon} ${moonPhase.name} (${moonPhase.illuminationPct}%)`;
}

function stripMoonContextPrefix(value, pattern) {
  if (!value) return "";
  return value.replace(pattern, "").trim();
}

function formatCombinedMoonContext({ moonSummary = "", moonPhaseSummary = "", moonlightSummary = "" }) {
  const parts = [
    stripMoonContextPrefix(moonSummary, /^Moon:\s*/i),
    stripMoonContextPrefix(moonPhaseSummary, /^Moon(?:\s*phase)?:\s*/i),
    stripMoonContextPrefix(moonlightSummary, /^Moonlight:\s*/i)
  ].filter(Boolean);
  if (!parts.length) return "";
  return `Moon: ${parts.join(" • ")}`;
}

function wrapLongitude(lon) {
  return ((lon + 540) % 360) - 180;
}

function computeNoWrapFitZoom(width) {
  const safeWidth = Math.max(320, width || window.innerWidth || 1024);
  const zoom = Math.log2(safeWidth / 256);
  return Math.min(3.0, Math.max(1.5, zoom));
}

function syncMapNoWrapZoomConstraints(force = false) {
  if (!state.map) return;
  const width = mapEl.clientWidth || state.map.getSize().x || window.innerWidth;
  const fitZoom = computeNoWrapFitZoom(width);
  if (!force && Math.abs(fitZoom - state.mapFitZoom) < 0.01) return;

  state.mapFitZoom = fitZoom;
  state.map.setMinZoom(fitZoom);
  if (state.map.getZoom() < fitZoom) {
    state.map.setZoom(fitZoom, { animate: false });
  }
}

function setMapTheme(theme) {
  const nextTheme = theme === "fallback" ? "fallback" : "primary";
  state.mapTheme = nextTheme;
  mapEl.classList.remove("map-theme-primary", "map-theme-fallback");
  mapEl.classList.add(nextTheme === "fallback" ? "map-theme-fallback" : "map-theme-primary");
}

function passKey(pass) {
  return `${pass.start}-${pass.end}`;
}

function azimuthToCompass(azimuth) {
  const directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
  const normalized = ((azimuth % 360) + 360) % 360;
  const index = Math.round(normalized / 22.5) % directions.length;
  return directions[index];
}

function averageAzimuth(azA, azB) {
  const a = toRadians(azA);
  const b = toRadians(azB);
  const x = Math.cos(a) + Math.cos(b);
  const y = Math.sin(a) + Math.sin(b);
  return (toDegrees(Math.atan2(y, x)) + 360) % 360;
}

function angularSeparation(raDegA, decDegA, raDegB, decDegB) {
  const raA = toRadians(raDegA);
  const decA = toRadians(decDegA);
  const raB = toRadians(raDegB);
  const decB = toRadians(decDegB);
  const cosSep = Math.sin(decA) * Math.sin(decB) + Math.cos(decA) * Math.cos(decB) * Math.cos(raA - raB);
  return toDegrees(Math.acos(Math.max(-1, Math.min(1, cosSep))));
}

function getPlanetVisibilityLimits(body, magnitude) {
  const preset = PLANET_VISUALS.planetVisibility?.[body] || {};
  let maxSunAltitudeDeg = Number.isFinite(preset.maxSunAltitudeDeg)
    ? preset.maxSunAltitudeDeg
    : PLANET_VISUALS.maxSunAltitudeDeg;
  const minElevationDeg = Math.max(
    PLANET_VISUALS.minElevationDeg,
    Number.isFinite(preset.minElevationDeg) ? preset.minElevationDeg : PLANET_VISUALS.minElevationDeg
  );

  // Very bright Venus can still be obvious in bright twilight.
  if (body === "Venus" && Number.isFinite(magnitude) && magnitude <= -4.0) {
    maxSunAltitudeDeg = Math.max(maxSunAltitudeDeg, -0.8);
  }

  return { maxSunAltitudeDeg, minElevationDeg };
}

function getPlanetObservation(body, date, observer, sunAltitude) {
  if (!window.Astronomy || !observer) return null;
  try {
    const equatorial = window.Astronomy.Equator(body, date, observer, true, true);
    const horizontal = window.Astronomy.Horizon(date, observer, equatorial.ra, equatorial.dec, "normal");
    const illumination = window.Astronomy.Illumination(body, date);
    const elevation = horizontal.altitude;
    const azimuth = (horizontal.azimuth + 360) % 360;
    const magnitude = Number.isFinite(illumination?.mag) ? illumination.mag : null;
    const visibility = getPlanetVisibilityLimits(body, magnitude);
    return {
      body,
      azimuth,
      elevation,
      magnitude,
      bright: magnitude !== null && magnitude <= PLANET_VISUALS.brightMagnitude,
      visible: sunAltitude < visibility.maxSunAltitudeDeg && elevation >= visibility.minElevationDeg,
      raDeg: equatorial.ra * 15,
      decDeg: equatorial.dec
    };
  } catch (error) {
    console.warn(`Planet observation failed for ${body}.`, error);
    return null;
  }
}

function getSkyContextAt(date, lat, lon) {
  const minute = Math.floor(date.getTime() / 60000);
  const cacheKey = `${lat.toFixed(3)}|${lon.toFixed(3)}|${minute}`;
  const cached = state.planetCache.get(cacheKey);
  if (cached) return cached;

  const sunAltitude = SunCalc.getPosition(date, lat, lon).altitude * 180 / Math.PI;
  const darkEnough = sunAltitude < PLANET_VISUALS.maxSunAltitudeDeg;
  const moonPhase = getMoonPhaseInfo(date);
  const moonAltitudeFallback = SunCalc.getMoonPosition(date, lat, lon).altitude * 180 / Math.PI;
  const moonAboveHorizonFallback = sunAltitude < 0 && moonAltitudeFallback >= PLANET_VISUALS.moonlightElevationDeg;

  if (!window.Astronomy || !window.Astronomy.Observer) {
    const moonlight = getMoonlightQuality({
      illuminationPct: moonPhase.illuminationPct,
      moonVisible: moonAboveHorizonFallback
    });
    const fallbackContext = {
      darkEnough,
      sunAltitude,
      visiblePlanets: [],
      moon: null,
      moonAboveHorizon: moonAboveHorizonFallback,
      observations: [],
      moonPhase,
      moonlightQuality: moonlight.quality,
      darkSkyScore: moonlight.darkSkyScore
    };
    state.planetCache.set(cacheKey, fallbackContext);
    return fallbackContext;
  }

  const observer = new window.Astronomy.Observer(lat, lon, 0);
  const observations = [];
  PLANET_VISUALS.planets.forEach((planet) => {
    const observation = getPlanetObservation(planet.body, date, observer, sunAltitude);
    if (!observation) return;
    observations.push({ ...observation, color: planet.color });
  });

  const visiblePlanets = observations
    .filter((observation) => observation.visible)
    .sort((a, b) => {
      const magA = Number.isFinite(a.magnitude) ? a.magnitude : 99;
      const magB = Number.isFinite(b.magnitude) ? b.magnitude : 99;
      if (magA !== magB) return magA - magB;
      return b.elevation - a.elevation;
    });

  const moonObs = getPlanetObservation(PLANET_VISUALS.moon.body, date, observer, sunAltitude);
  const moonAboveHorizon = Boolean(moonObs && sunAltitude < 0 && moonObs.elevation >= PLANET_VISUALS.moonlightElevationDeg);
  const moonVisible = moonObs && moonObs.elevation >= PLANET_VISUALS.minElevationDeg && darkEnough
    ? { ...moonObs, color: PLANET_VISUALS.moon.color }
    : null;
  const moonlight = getMoonlightQuality({
    illuminationPct: moonPhase.illuminationPct,
    moonVisible: moonAboveHorizon
  });

  const context = {
    darkEnough,
    sunAltitude,
    visiblePlanets,
    moon: moonVisible,
    moonAboveHorizon,
    observations,
    moonPhase,
    moonlightQuality: moonlight.quality,
    darkSkyScore: moonlight.darkSkyScore
  };

  state.planetCache.set(cacheKey, context);
  return context;
}

function getTonightWindow(lat, lon, now = new Date()) {
  const todayTimes = SunCalc.getTimes(now, lat, lon);
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayTimes = SunCalc.getTimes(yesterday, lat, lon);
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowTimes = SunCalc.getTimes(tomorrow, lat, lon);

  let start = todayTimes.sunset;
  let end = tomorrowTimes.sunrise;
  let phase = "upcoming";
  let duskTimes = todayTimes;
  let dawnTimes = tomorrowTimes;

  if (now < todayTimes.sunrise) {
    start = yesterdayTimes.sunset;
    end = todayTimes.sunrise;
    phase = "pre-dawn";
    duskTimes = yesterdayTimes;
    dawnTimes = todayTimes;
  } else if (now >= todayTimes.sunset) {
    start = todayTimes.sunset;
    end = tomorrowTimes.sunrise;
    phase = "night";
  }

  return {
    startTs: Math.floor(start.getTime() / 1000),
    endTs: Math.floor(end.getTime() / 1000),
    phase,
    sunset: duskTimes.sunset,
    civilDusk: duskTimes.dusk,
    nauticalDusk: duskTimes.nauticalDusk,
    astronomicalDusk: duskTimes.night,
    civilDawn: dawnTimes.dawn,
    nauticalDawn: dawnTimes.nauticalDawn,
    astronomicalDawn: dawnTimes.nightEnd,
    sunrise: dawnTimes.sunrise
  };
}

async function fetchWeatherForecast(lat, lon) {
  const params = new URLSearchParams({
    latitude: lat.toFixed(4),
    longitude: lon.toFixed(4),
    hourly: "cloud_cover,cloud_cover_low,precipitation_probability,visibility,wind_speed_10m",
    forecast_days: String(FORECAST_DAYS),
    timezone: "auto"
  });
  const response = await fetch(`${WEATHER_URL}?${params.toString()}`, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Weather API failed (${response.status})`);
  }
  const data = await response.json();
  const times = data?.hourly?.time || [];
  const cloudCover = data?.hourly?.cloud_cover || [];
  const cloudLow = data?.hourly?.cloud_cover_low || [];
  const precip = data?.hourly?.precipitation_probability || [];
  const visibility = data?.hourly?.visibility || [];
  const wind = data?.hourly?.wind_speed_10m || [];

  state.weather.hourly = times.map((time, index) => ({
    timestamp: Math.floor(new Date(time).getTime() / 1000),
    cloudCover: Number(cloudCover[index] ?? 100),
    lowCloudCover: Number(cloudLow[index] ?? cloudCover[index] ?? 100),
    precipitationProbability: Number(precip[index] ?? 0),
    visibility: Number(visibility[index] ?? 0),
    windSpeed: Number(wind[index] ?? 0)
  }));
  state.weather.fetchedAt = Date.now();
  state.weather.error = null;
  return state.weather.hourly;
}

function getWeatherAt(timestampSec) {
  if (!state.weather.hourly.length) return null;
  let nearest = state.weather.hourly[0];
  let nearestDelta = Math.abs(nearest.timestamp - timestampSec);
  for (let index = 1; index < state.weather.hourly.length; index++) {
    const sample = state.weather.hourly[index];
    const delta = Math.abs(sample.timestamp - timestampSec);
    if (delta < nearestDelta) {
      nearest = sample;
      nearestDelta = delta;
    }
  }
  return nearest;
}

function weatherScore(sample) {
  if (!sample) return 50;
  const cloudPenalty = Math.min(70, sample.cloudCover * 0.65);
  const precipPenalty = Math.min(20, sample.precipitationProbability * 0.25);
  const windPenalty = Math.min(15, sample.windSpeed * 0.28);
  const visibilityKm = sample.visibility ? sample.visibility / 1000 : 0;
  const visibilityBonus = Math.min(18, visibilityKm * 0.8);
  return Math.max(0, Math.min(100, 78 - cloudPenalty - precipPenalty - windPenalty + visibilityBonus));
}

function weatherQualityLabel(sample) {
  if (!sample) return "Weather unavailable";
  const score = weatherScore(sample);
  if (sample.cloudCover >= 80) return "Overcast risk";
  if (score >= 72) return "Clear";
  if (score >= 52) return "Mostly clear";
  if (score >= 35) return "Mixed cloud";
  return "Cloud risk";
}

function weatherBadgeValue(sample) {
  const label = weatherQualityLabel(sample);
  if (label === "Clear" || label === "Mostly clear") return "clear";
  if (label === "Weather unavailable") return "";
  return "risk";
}

function summarizeWeatherWindow(startTs, endTs) {
  const samples = state.weather.hourly.filter((sample) => sample.timestamp >= startTs && sample.timestamp <= endTs);
  if (!samples.length) return null;
  const average = samples.reduce((acc, sample) => ({
    cloudCover: acc.cloudCover + sample.cloudCover,
    precipitationProbability: acc.precipitationProbability + sample.precipitationProbability,
    windSpeed: acc.windSpeed + sample.windSpeed,
    visibility: acc.visibility + sample.visibility
  }), { cloudCover: 0, precipitationProbability: 0, windSpeed: 0, visibility: 0 });
  const count = samples.length;
  const summary = {
    cloudCover: average.cloudCover / count,
    precipitationProbability: average.precipitationProbability / count,
    windSpeed: average.windSpeed / count,
    visibility: average.visibility / count
  };
  return {
    ...summary,
    score: weatherScore(summary),
    label: weatherQualityLabel(summary)
  };
}

function findClearestWindow(startTs, endTs) {
  const samples = state.weather.hourly.filter((sample) => sample.timestamp >= startTs && sample.timestamp <= endTs);
  if (!samples.length) return null;
  return samples
    .map((sample) => ({ ...sample, score: weatherScore(sample) }))
    .sort((left, right) => right.score - left.score || left.timestamp - right.timestamp)[0];
}

function getEquatorialObservation(entry, date, observer) {
  if (!window.Astronomy?.Horizon || !observer) return null;
  try {
    const horizontal = window.Astronomy.Horizon(date, observer, entry.raHours, entry.decDeg, "normal");
    return {
      azimuth: (horizontal.azimuth + 360) % 360,
      elevation: horizontal.altitude
    };
  } catch (error) {
    console.warn(`Equatorial observation failed for ${entry.name || entry.id}.`, error);
    return null;
  }
}

function getVisibleConstellationGuides(date, lat, lon, skyContext = null) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) return [];
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return [];

  const context = skyContext || getSkyContextAt(date, lat, lon);
  if (!context.darkEnough || !window.Astronomy?.Observer) return [];

  const observer = new window.Astronomy.Observer(lat, lon, 0);
  const month = date.getMonth() + 1;

  return CONSTELLATIONS
    .map((constellation) => {
      if (!Array.isArray(constellation.guideStars) || !Array.isArray(constellation.segments)) return null;

      const projectedStars = new Map();
      const visibleStars = [];

      constellation.guideStars.forEach((star) => {
        const observation = getEquatorialObservation(star, date, observer);
        if (!observation) return;
        const projected = {
          ...star,
          azimuth: observation.azimuth,
          elevation: observation.elevation
        };
        projectedStars.set(star.id, projected);
        if (projected.elevation >= 5) visibleStars.push(projected);
      });

      if (visibleStars.length < 3) return null;

      const labelStar = projectedStars.get(constellation.labelStarId);
      if (!labelStar || labelStar.elevation < 12) return null;

      const visibleSegments = constellation.segments
        .map(([fromId, toId]) => {
          const from = projectedStars.get(fromId);
          const to = projectedStars.get(toId);
          if (!from || !to || from.elevation < 0 || to.elevation < 0) return null;
          return { from, to };
        })
        .filter(Boolean);

      if (visibleSegments.length < 2) return null;

      const averageVisibleGuideStarElevation = visibleStars.reduce((sum, star) => sum + star.elevation, 0) / visibleStars.length;
      const anchorGuideStarId = constellation.guideStars.find((star) => star.anchor)?.id || constellation.labelStarId;

      return {
        ...constellation,
        labelStar,
        projectedStars: Array.from(projectedStars.values()),
        visibleStars,
        visibleSegments,
        score: labelStar.elevation
          + averageVisibleGuideStarElevation * 0.35
          + (constellation.bestMonths.includes(month) ? 8 : 0),
        anchorGuideStarId
      };
    })
    .filter(Boolean)
    .sort((left, right) => (
      right.score - left.score
      || right.visibleSegments.length - left.visibleSegments.length
      || right.visibleStars.length - left.visibleStars.length
      || left.name.localeCompare(right.name)
    ))
    .slice(0, 2);
}

function isCatalogDateInRange(monthDay, year) {
  const [month, day] = monthDay.split("-").map(Number);
  return new Date(year, month - 1, day);
}

function isMeteorActiveOnDate(shower, date) {
  const year = date.getFullYear();
  const currentYearDate = new Date(year, date.getMonth(), date.getDate());
  let activeStart = isCatalogDateInRange(shower.activeStart, year);
  let activeEnd = isCatalogDateInRange(shower.activeEnd, year);
  if (activeEnd < activeStart) {
    if (currentYearDate < activeEnd) {
      activeStart = isCatalogDateInRange(shower.activeStart, year - 1);
    } else {
      activeEnd = isCatalogDateInRange(shower.activeEnd, year + 1);
    }
  }
  return currentYearDate >= activeStart && currentYearDate <= activeEnd;
}

function meteorPeakDate(shower, date) {
  const year = date.getFullYear();
  const [month, day] = shower.peakMonthDay.split("-").map(Number);
  let peak = new Date(year, month - 1, day, 2, 0, 0, 0);
  if (Math.abs(peak - date) > 180 * 24 * 3600 * 1000) {
    peak = new Date(year + (peak < date ? 1 : -1), month - 1, day, 2, 0, 0, 0);
  }
  return peak;
}

function buildMeteorEvents(startTs, endTs, lat, lon) {
  if (!window.Astronomy?.Observer) return [];
  const observer = new window.Astronomy.Observer(lat, lon, 0);
  const events = [];
  for (let ts = startTs; ts <= endTs; ts += 24 * 3600) {
    const date = new Date(ts * 1000);
    const darkWindow = getTonightWindow(lat, lon, date);
    const focusTs = Math.min(darkWindow.endTs - 3600, Math.max(darkWindow.startTs + 4 * 3600, ts + 6 * 3600));
    const focusDate = new Date(focusTs * 1000);
    METEOR_SHOWERS.forEach((shower) => {
      if (!isMeteorActiveOnDate(shower, focusDate)) return;
      const obs = getEquatorialObservation({ name: shower.name, raHours: shower.radiantRaHours, decDeg: shower.radiantDecDeg }, focusDate, observer);
      if (!obs || obs.elevation < 18) return;
      const context = getSkyContextAt(focusDate, lat, lon);
      const peakDate = meteorPeakDate(shower, focusDate);
      const peakDeltaDays = Math.abs((peakDate.getTime() - focusDate.getTime()) / 86400000);
      const strength = Math.max(0, shower.zhr - peakDeltaDays * 12);
      const score = strength + obs.elevation + context.darkSkyScore * 0.55;
      if (strength < 10) return;
      events.push({
        id: `meteor-${shower.id}-${focusTs}`,
        type: "meteor-shower",
        focusTs,
        start: focusTs - 5400,
        end: focusTs + 5400,
        skyWindow: focusDate.getHours() < 12 ? "dawn" : "evening",
        emphasis: shower.zhr >= 80 || peakDeltaDays <= 1,
        bodies: [shower.name],
        visibilityTier: shower.tier || "naked-eye",
        title: `${shower.name} meteor shower`,
        meta: formatDateTime(focusDate),
        details: `Radiant ${Math.round(obs.elevation)}° ${azimuthToCompass(obs.azimuth)} • Peak rate ${Math.round(strength)}/hr`,
        moonPhase: context.moonPhase || null,
        moonPhaseSummary: formatMoonPhaseLine(context.moonPhase, "Moon"),
        moonlightSummary: `Moonlight: ${moonlightQualityLabel(context.moonlightQuality)}`,
        moonlightBadge: moonlightBadgeValue(context.moonlightQuality),
        darkSkyScore: context.darkSkyScore,
        qualityScore: score,
        notableReason: shower.zhr >= 80 ? "meteor" : "",
        hint: `Best after ${formatTime(focusDate)} when the radiant climbs higher.`
      });
    });
  }
  return events;
}

function solarEclipseKindLabel(kind) {
  const kinds = window.Astronomy?.EclipseKind || {};
  if (kind === kinds.Total) return "Total solar eclipse";
  if (kind === kinds.Annular) return "Annular solar eclipse";
  if (kind === kinds.Partial) return "Partial solar eclipse";
  return "Solar eclipse";
}

function buildSolarEclipseEvents(startTs, endTs, lat, lon) {
  if (!window.Astronomy?.SearchLocalSolarEclipse || !window.Astronomy?.NextLocalSolarEclipse) return [];
  const observer = new window.Astronomy.Observer(lat, lon, 0);
  const events = [];
  let eclipse;
  try {
    eclipse = window.Astronomy.SearchLocalSolarEclipse(new Date(startTs * 1000), observer);
  } catch (error) {
    console.warn("Solar eclipse search failed.", error);
    return events;
  }

  let guard = 0;
  while (eclipse && guard < 10) {
    guard += 1;
    const peakDate = eclipse.peak?.time?.date instanceof Date ? eclipse.peak.time.date : null;
    const peakTs = peakDate ? Math.floor(peakDate.getTime() / 1000) : null;
    if (!peakTs || peakTs > endTs) break;
    if (peakTs >= startTs && (eclipse.peak?.altitude ?? -90) > 0) {
      const context = getSkyContextAt(peakDate, lat, lon);
      events.push({
        id: `solar-eclipse-${peakTs}`,
        type: "solar-eclipse",
        focusTs: peakTs,
        start: peakTs - 3600,
        end: peakTs + 3600,
        skyWindow: peakDate.getHours() < 12 ? "dawn" : "evening",
        emphasis: true,
        bodies: ["Sun", "Moon"],
        visibilityTier: "naked-eye",
        title: solarEclipseKindLabel(eclipse.kind),
        meta: formatDateTime(peakDate),
        details: `Coverage ${Math.round((eclipse.obscuration || 0) * 100)}% • Sun ${Math.round(eclipse.peak.altitude)}°`,
        moonPhase: context.moonPhase || null,
        moonPhaseSummary: formatMoonPhaseLine(context.moonPhase, "Moon"),
        moonlightSummary: "Use certified eclipse viewing protection.",
        moonlightBadge: "",
        darkSkyScore: context.darkSkyScore,
        qualityScore: 900
      });
    }
    try {
      eclipse = window.Astronomy.NextLocalSolarEclipse(eclipse.peak.time, observer);
    } catch (error) {
      break;
    }
  }

  return events;
}

function computeAlignmentEvents(startTimestamp, endTimestamp, lat, lon) {
  if (!window.Astronomy || !window.Astronomy.Observer) return [];
  const stepSeconds = PLANET_VISUALS.alignmentStepMinutes * 60;
  const active = new Map();
  const events = [];

  for (let ts = startTimestamp; ts <= endTimestamp; ts += stepSeconds) {
    const context = getSkyContextAt(new Date(ts * 1000), lat, lon);
    const planets = context.visiblePlanets;
    const seenPairs = new Set();

    for (let i = 0; i < planets.length; i++) {
      for (let j = i + 1; j < planets.length; j++) {
        const a = planets[i];
        const b = planets[j];
        const separation = angularSeparation(a.raDeg, a.decDeg, b.raDeg, b.decDeg);
        if (separation > PLANET_VISUALS.alignmentSeparationDeg) continue;

        const bodies = [a.body, b.body].sort((left, right) => left.localeCompare(right));
        const pairId = bodies.join("|");
        seenPairs.add(pairId);
        const azimuth = averageAzimuth(a.azimuth, b.azimuth);
        const elevation = (a.elevation + b.elevation) / 2;

        if (!active.has(pairId)) {
          active.set(pairId, {
            pairId,
            bodies,
            start: ts,
            end: ts,
            peakTs: ts,
            minSeparation: separation,
            azimuth,
            elevation
          });
        } else {
          const event = active.get(pairId);
          event.end = ts;
          if (separation < event.minSeparation) {
            event.minSeparation = separation;
            event.peakTs = ts;
            event.azimuth = azimuth;
            event.elevation = elevation;
          }
        }
      }
    }

    for (const [pairId, event] of active.entries()) {
      if (seenPairs.has(pairId)) continue;
      events.push({
        ...event,
        label: `${event.bodies[0]} + ${event.bodies[1]}`,
        direction: azimuthToCompass(event.azimuth)
      });
      active.delete(pairId);
    }
  }

  for (const event of active.values()) {
    events.push({
      ...event,
      label: `${event.bodies[0]} + ${event.bodies[1]}`,
      direction: azimuthToCompass(event.azimuth)
    });
  }

  return events.sort((a, b) => a.peakTs - b.peakTs);
}

function findNearbyAlignment(peakTimestamp, alignmentEvents) {
  let nearest = null;
  alignmentEvents.forEach((event) => {
    const delta = Math.abs(event.peakTs - peakTimestamp);
    if (delta > PLANET_VISUALS.alignmentWindowSeconds) return;
    if (!nearest || delta < nearest.delta) {
      nearest = { event, delta };
    }
  });
  return nearest ? nearest.event : null;
}

function formatSkyTarget(target) {
  const direction = azimuthToCompass(target.azimuth);
  return `${target.body} ${Math.round(target.elevation)}° ${direction}`;
}

function lunarEclipseKindLabel(kind) {
  const kinds = window.Astronomy?.EclipseKind || {};
  if (kind === kinds.Total) return "Total lunar eclipse";
  if (kind === kinds.Partial) return "Partial lunar eclipse";
  if (kind === kinds.Penumbral) return "Penumbral lunar eclipse";
  return "Lunar eclipse";
}

function buildLunarEclipseEvents(startTs, endTs, lat, lon) {
  if (!window.Astronomy?.SearchLunarEclipse || !window.Astronomy?.NextLunarEclipse) return [];

  const events = [];
  let eclipse;
  try {
    eclipse = window.Astronomy.SearchLunarEclipse(new Date(startTs * 1000));
  } catch (error) {
    console.warn("Lunar eclipse search failed.", error);
    return events;
  }

  let guard = 0;
  while (eclipse && guard < 16) {
    guard += 1;
    const peakDate = eclipse.peak?.date instanceof Date ? eclipse.peak.date : null;
    const peakTs = peakDate ? Math.floor(peakDate.getTime() / 1000) : null;
    if (!peakTs) break;
    if (peakTs > endTs) break;

    const kinds = window.Astronomy?.EclipseKind || {};
    const isPenumbral = eclipse.kind === kinds.Penumbral;
    const obscurationPct = Math.round((eclipse.obscuration || 0) * 100);

    // Ignore weak penumbral eclipses because they are usually imperceptible.
    if (!(isPenumbral && obscurationPct < 65) && peakTs >= startTs) {
      const sunAlt = SunCalc.getPosition(peakDate, lat, lon).altitude * 180 / Math.PI;
      const moonPos = SunCalc.getMoonPosition(peakDate, lat, lon);
      const moonAlt = moonPos.altitude * 180 / Math.PI;
      const moonAz = (moonPos.azimuth * 180 / Math.PI + 180) % 360;
      const moonVisible = moonAlt > 0 && sunAlt < 0;
      if (moonVisible) {
        const context = getSkyContextAt(peakDate, lat, lon);
        const moonPhase = context.moonPhase || getMoonPhaseInfo(peakDate);
        const moonlight = getMoonlightQuality({
          illuminationPct: moonPhase.illuminationPct,
          moonVisible: true
        });
        const durationMin = Math.max(
          1,
          Math.round(Math.max(eclipse.sd_penum || 0, eclipse.sd_partial || 0, eclipse.sd_total || 0) * 2)
        );

        events.push({
          id: `lunar-eclipse-${peakTs}`,
          type: "lunar-eclipse",
          focusTs: peakTs,
          start: peakTs - durationMin * 30,
          end: peakTs + durationMin * 30,
          emphasis: eclipse.kind === kinds.Total || eclipse.kind === kinds.Partial,
          bodies: ["Moon"],
          title: lunarEclipseKindLabel(eclipse.kind),
          meta: formatDateTime(peakDate),
          details: `Coverage ${obscurationPct}% • Moon ${Math.round(moonAlt)}° ${azimuthToCompass(moonAz)}`,
          moonPhase,
          moonPhaseSummary: formatMoonPhaseLine(moonPhase, "Moon"),
          moonlightSummary: `Moonlight: ${moonlightQualityLabel(moonlight.quality)}`,
          moonlightBadge: moonlightBadgeValue(moonlight.quality),
          darkSkyScore: moonlight.darkSkyScore
        });
      }
    }

    try {
      eclipse = window.Astronomy.NextLunarEclipse(eclipse.peak);
    } catch (error) {
      break;
    }
  }

  return events;
}

function buildMoonPhaseEvents(startTs, endTs, lat, lon) {
  if (!window.Astronomy?.SearchMoonPhase) return [];
  const phaseDefs = [
    { lon: 0, title: "New Moon" },
    { lon: 90, title: "First Quarter" },
    { lon: 180, title: "Full Moon" },
    { lon: 270, title: "Last Quarter" }
  ];

  const events = [];
  phaseDefs.forEach((phase) => {
    try {
      const found = window.Astronomy.SearchMoonPhase(phase.lon, new Date(startTs * 1000), FORECAST_DAYS + 1);
      if (!found?.date) return;
      const ts = Math.floor(found.date.getTime() / 1000);
      if (ts < startTs || ts > endTs) return;

      const context = getSkyContextAt(found.date, lat, lon);
      const moonPhase = context.moonPhase || getMoonPhaseInfo(found.date);
      events.push({
        id: `moon-phase-${phase.lon}-${ts}`,
        type: "moon-phase",
        focusTs: ts,
        start: ts - 1800,
        end: ts + 1800,
        emphasis: phase.lon === 180 || phase.lon === 0,
        bodies: ["Moon"],
        title: phase.title,
        meta: formatDateTime(found.date),
        details: `Moon illumination ${moonPhase.illuminationPct}%`,
        moonPhase,
        moonPhaseSummary: formatMoonPhaseLine(moonPhase, "Moon"),
        moonlightSummary: `Moonlight: ${moonlightQualityLabel(context.moonlightQuality)}`,
        moonlightBadge: moonlightBadgeValue(context.moonlightQuality),
        darkSkyScore: context.darkSkyScore
      });
    } catch (error) {
      console.warn("Moon phase search failed.", error);
    }
  });

  return events;
}

function buildSkyEvents(lat, lon, alignmentEvents) {
  const now = Math.floor(Date.now() / 1000);
  const end = now + FORECAST_DAYS * 24 * 3600;
  const groupingStepSeconds = PLANET_VISUALS.alignmentStepMinutes * 60;
  const windowBest = new Map();

  for (let ts = now; ts <= end; ts += groupingStepSeconds) {
    const sampleDate = new Date(ts * 1000);
    const context = getSkyContextAt(sampleDate, lat, lon);
    if (context.visiblePlanets.length < 1) continue;
    const topTargets = context.visiblePlanets.slice(0, 5);
    const score = topTargets.reduce((sum, target) => {
      const brightBonus = target.bright ? 18 : 0;
      const venusBonus = target.body === "Venus" ? 8 : 0;
      return sum + target.elevation + brightBonus + venusBonus;
    }, topTargets.length * 80);
    const localHour = sampleDate.getHours();
    const skyWindow = localHour < 12 ? "dawn" : "evening";
    const windowKey = `${sampleDate.toLocaleDateString("en-CA")}|${skyWindow}`;
    const existing = windowBest.get(windowKey);
    if (!existing || score > existing.score) {
      windowBest.set(windowKey, {
        timestamp: ts,
        score,
        topTargets,
        skyWindow
      });
    }
  }

  const groupingEventsRaw = Array.from(windowBest.values()).map((entry) => {
    const topTargets = entry.topTargets;
    const names = topTargets.map((target) => target.body);
    const summary = topTargets.map((target) => formatSkyTarget(target)).join(" • ");
    const context = getSkyContextAt(new Date(entry.timestamp * 1000), lat, lon);
    const eventType = names.length === 1 ? "planet" : "group";
    let title = "";
    if (names.length === 1) {
      title = `${names[0]} visible`;
    } else if (names.length === 2) {
      title = `${names[0]} + ${names[1]}`;
    } else {
      title = `${names[0]}, ${names[1]} +${names.length - 2} planets`;
    }

    return {
      id: `group-${entry.skyWindow}-${entry.timestamp}-${names.join("-")}`,
      type: eventType,
      focusTs: entry.timestamp,
      start: entry.timestamp - 45 * 60,
      end: entry.timestamp + 45 * 60,
      skyWindow: entry.skyWindow,
      emphasis: topTargets.length >= 3,
      bodies: names,
      title,
      meta: formatDateTime(new Date(entry.timestamp * 1000)),
      details: summary,
      moonPhase: context.moonPhase || null,
      moonPhaseSummary: formatMoonPhaseLine(context.moonPhase, "Moon"),
      moonlightSummary: `Moonlight: ${moonlightQualityLabel(context.moonlightQuality)}`,
      moonlightBadge: moonlightBadgeValue(context.moonlightQuality),
      darkSkyScore: context.darkSkyScore,
      qualityScore: entry.score,
      visibilityTier: "naked-eye"
    };
  });

  const groupingEvents = groupingEventsRaw
    .sort((left, right) => left.start - right.start);

  const alignmentHighlights = alignmentEvents
    .filter((event) => event.end > now)
    .map((event) => {
      const context = getSkyContextAt(new Date(event.peakTs * 1000), lat, lon);
      return {
        id: `align-${event.pairId}-${event.peakTs}`,
        type: "alignment",
        focusTs: event.peakTs,
        start: event.start,
        end: event.end,
        skyWindow: new Date(event.peakTs * 1000).getHours() < 12 ? "dawn" : "evening",
        emphasis: event.minSeparation <= 2.5,
        bodies: event.bodies,
        title: `${event.label} alignment`,
        meta: formatDateTime(new Date(event.peakTs * 1000)),
        details: `Closest ${event.minSeparation.toFixed(1)}° • ${event.direction} • Altitude ${Math.round(event.elevation)}°`,
        separationDeg: event.minSeparation,
        moonPhase: context.moonPhase || null,
        moonPhaseSummary: formatMoonPhaseLine(context.moonPhase, "Moon"),
        moonlightSummary: `Moonlight: ${moonlightQualityLabel(context.moonlightQuality)}`,
        moonlightBadge: moonlightBadgeValue(context.moonlightQuality),
        darkSkyScore: context.darkSkyScore,
        visibilityTier: "naked-eye"
      };
    });

  const lunarEclipseEvents = buildLunarEclipseEvents(now, end, lat, lon);
  const solarEclipseEvents = buildSolarEclipseEvents(now, end, lat, lon);
  const guideEvents = buildGuideEvents(lat, lon, now, end);
  const meteorEvents = state.meteorEvents || [];
  const allEvents = [...solarEclipseEvents, ...lunarEclipseEvents, ...alignmentHighlights, ...meteorEvents, ...groupingEvents, ...guideEvents]
    .sort((left, right) => left.start - right.start);

  function eventScore(event) {
    let score = 0;
    const weather = getWeatherAt(event.focusTs || event.start);
    const wxScore = weatherScore(weather);
    if (event.type === "solar-eclipse") {
      score += 840;
    } else if (event.type === "lunar-eclipse") {
      score += 640;
    } else if (event.type === "meteor-shower") {
      score += 560;
      score += Math.min(220, (event.qualityScore || 0) * 0.5);
    } else if (event.type === "alignment") {
      score += 520;
      if (Number.isFinite(event.separationDeg)) {
        score += Math.max(0, (6 - event.separationDeg) * 18);
      }
    } else if (event.type === "group" || event.type === "planet") {
      const bodiesCount = event.bodies?.length || 1;
      score += 320;
      score += bodiesCount * 180;
      score += Math.min(260, (event.qualityScore || 0) * 0.45);
      if (event.type === "planet") score -= 70;
    }
    if (event.emphasis) score += 36;
    score += (event.darkSkyScore || 0) * 0.7;
    score += wxScore * 0.45;
    if (wxScore < 32) score -= 55;
    return score;
  }

  const byDay = new Map();
  allEvents.forEach((event) => {
    const focus = event.focusTs || event.start;
    const dayKey = new Date(focus * 1000).toLocaleDateString("en-CA");
    const ranked = { ...event, _score: eventScore(event) };
    if (!byDay.has(dayKey)) byDay.set(dayKey, []);
    byDay.get(dayKey).push(ranked);
  });

  const dayEntries = Array.from(byDay.entries())
    .sort((left, right) => new Date(left[0]) - new Date(right[0]))
    .slice(0, FORECAST_DAYS)
    .map(([dayKey, events]) => {
      const typeChosen = new Set();
      const chosen = events
        .sort((left, right) => right._score - left._score || (left.focusTs || left.start) - (right.focusTs || right.start))
        .filter((event) => {
          const typeKey = event.type === "planet" ? event.bodies?.[0] || event.type : event.type;
          if (typeChosen.has(typeKey)) return false;
          typeChosen.add(typeKey);
          return true;
        })
        .slice(0, 3);
      const top = chosen[0];
      const dayScore = chosen.reduce((sum, event, index) => sum + event._score * (index === 0 ? 1 : 0.35), 0);
      return {
        dayKey,
        dayLabel: new Date(`${dayKey}T12:00:00`).toLocaleDateString([], { weekday: "short", month: "short", day: "numeric" }),
        events: chosen,
        dayScore,
        top
      };
    })
    .filter((entry) => entry.events.length);

  let bestDayIdx = -1;
  dayEntries.forEach((entry, index) => {
    if (bestDayIdx < 0 || entry.dayScore > dayEntries[bestDayIdx].dayScore) {
      bestDayIdx = index;
    }
  });

  return dayEntries.flatMap((entry, dayIndex) => entry.events.map((event, eventIndex) => {
    const { _score, ...clean } = event;
    let notableReason = "";
    if (clean.type === "alignment") notableReason = "alignment";
    else if (clean.type === "lunar-eclipse" || clean.type === "solar-eclipse") notableReason = "eclipse";
    else if ((clean.bodies?.length || 0) >= 3) notableReason = "multi-body";
    else if (clean.type === "meteor-shower") notableReason = "meteor";
    return {
      ...clean,
      rankScore: _score,
      dayKey: entry.dayKey,
      dayLabel: entry.dayLabel,
      isTopOfDay: eventIndex === 0,
      isBestNight: dayIndex === bestDayIdx,
      isBestOfWeek: dayIndex === bestDayIdx && eventIndex === 0,
      isNotable: Boolean(notableReason),
      notableReason,
      emphasis: dayIndex === bestDayIdx && eventIndex === 0
    };
  }));
}

function getSkyBadgeDescriptors(event) {
  const badgeDescriptors = [];
  if (event.type === "lunar-eclipse") badgeDescriptors.push({ className: "eclipse", label: "Eclipse", priority: 1 });
  if (event.type === "solar-eclipse") badgeDescriptors.push({ className: "eclipse", label: "Solar", priority: 1 });
  if (event.type === "meteor-shower") badgeDescriptors.push({ className: "meteor", label: "Meteor", priority: 1 });
  if (event.guideKind === "deep-sky") badgeDescriptors.push({ className: "tier-binoculars", label: "Deep Sky", priority: 2 });
  if (event.guideKind === "constellation") badgeDescriptors.push({ className: "weather-clear", label: "Constellation", priority: 2 });
  if (event.guideKind === "star") badgeDescriptors.push({ className: "weather-clear", label: "Bright Star", priority: 2 });
  if (event.notableReason === "alignment") badgeDescriptors.push({ className: "alignment", label: "Alignment", priority: 1 });
  if (event.notableReason === "multi-body") badgeDescriptors.push({ className: "multi", label: "3 Bodies", priority: 2 });
  if (event.isBestOfWeek) badgeDescriptors.push({ className: "best", label: "Best", priority: 1 });
  if (event.visibilityTier === "binoculars") badgeDescriptors.push({ className: "tier-binoculars", label: "Binoculars", priority: 3 });
  return badgeDescriptors;
}

function createSkyTopPick(event, selectedEventId) {
  const item = document.createElement("div");
  const isSelected = selectedEventId === event.id;
  item.className = `sky-top-pick clickable${event.isBestOfWeek ? " best-of-week" : ""}${isSelected ? " selected" : ""}`;
  const badgeDescriptors = getSkyBadgeDescriptors(event);
  const badgeSpans = getTopSkyBadgeSpans(badgeDescriptors);
  const focusLabel = formatDateTime(new Date((event.focusTs || event.start) * 1000));
  const moonContextLine = formatCombinedMoonContext({
    moonPhaseSummary: event.moonPhaseSummary,
    moonlightSummary: event.moonlightSummary
  });
  const qualityHint = event.isBestOfWeek ? getSkyQualityHint(event) : "";
  item.innerHTML = `
    <div class="sky-top-head">
      <div class="sky-top-copy">
        <div class="sky-top-kicker">Top pick</div>
        <p class="pass-title sky-top-title">${event.title}</p>
        <div class="pass-meta event-time">${focusLabel}</div>
      </div>
      <div class="sky-top-actions">
        <button class="share-chip" type="button">Share</button>
        ${badgeSpans ? `<div class="sky-top-badges">${badgeSpans}</div>` : ""}
      </div>
    </div>
    <div class="sky-top-meta">${getSkyEventWindowLabel(event)} • ${event.details}</div>
    ${event.hint ? `<div class="sky-top-detail">${event.hint}</div>` : ""}
    ${moonContextLine ? `<div class="pass-meta moon-phase">${moonContextLine}</div>` : ""}
    ${qualityHint ? `<div class="pass-meta quality-hint">${qualityHint}</div>` : ""}
  `;

  const shareButton = item.querySelector(".share-chip");
  if (shareButton) {
    shareButton.addEventListener("click", (clickEvent) => {
      clickEvent.stopPropagation();
      shareSkyEvent(event);
    });
  }
  item.addEventListener("click", () => setSkyEventPreview(event));
  return item;
}

function createSkySecondaryRow(event, selectedEventId) {
  const item = document.createElement("button");
  item.type = "button";
  item.className = `sky-secondary-row clickable${selectedEventId === event.id ? " selected" : ""}`;
  const badgeDescriptors = getSkyBadgeDescriptors(event);
  const badgeSpansSecondary = getSecondarySkyBadgeSpans(badgeDescriptors);
  const focusLabel = formatDateTime(new Date((event.focusTs || event.start) * 1000));
  const detailLine = getSecondarySkyDetailLine(event);
  item.innerHTML = `
    <div class="sky-secondary-main">
      <div class="sky-secondary-head">
        <p class="pass-title sky-secondary-title">${event.title}</p>
        ${badgeSpansSecondary ? `<div class="sky-row-badges">${badgeSpansSecondary}</div>` : ""}
      </div>
      <div class="pass-meta event-time">${focusLabel} • ${getSkyEventWindowLabel(event)}</div>
      <div class="pass-meta sky-highlight">${detailLine}</div>
    </div>
  `;
  item.addEventListener("click", () => setSkyEventPreview(event));
  return item;
}

function renderSkyEventsList() {
  if (!skyEventsList) return;
  skyEventsList.innerHTML = "";

  if (!state.user) {
    skyEventsList.innerHTML = `
      <div class="sky-event-item">
        <div>
          <p class="pass-title">Waiting for location…</p>
          <div class="pass-meta">Enable geolocation to calculate sky highlights</div>
        </div>
        <span class="badge daylight">Standby</span>
      </div>
    `;
    return;
  }

  if (!window.Astronomy || !window.Astronomy.Observer) {
    skyEventsList.innerHTML = `
      <div class="sky-event-item">
        <div>
          <p class="pass-title">Sky engine unavailable</p>
          <div class="pass-meta">Could not load planetary calculations</div>
        </div>
        <span class="badge low">Unavailable</span>
      </div>
    `;
    return;
  }

  if (!state.skyEvents.length) {
    skyEventsList.innerHTML = `
      <div class="sky-event-item">
        <div>
          <p class="pass-title">No standout naked-eye events in the next ${FORECAST_DAYS} days</p>
          <div class="pass-meta">Try another location, or check weather and moonlight for a better night.</div>
        </div>
        <span class="badge daylight">Quiet</span>
      </div>
    `;
    return;
  }

  const selectedEventId = state.preview.active && state.preview.mode === "event" ? state.preview.skyEvent?.id : null;
  const groups = new Map();
  state.skyEvents.forEach((event) => {
    if (!groups.has(event.dayKey)) {
      groups.set(event.dayKey, {
        dayKey: event.dayKey,
        dayLabel: event.dayLabel,
        events: [],
        isBestNight: event.isBestNight
      });
    }
    const group = groups.get(event.dayKey);
    group.events.push(event);
    group.isBestNight = group.isBestNight || event.isBestNight;
  });

  Array.from(groups.values()).forEach((group) => {
    const topEvent = group.events.find((event) => event.isTopOfDay) || group.events[0];
    const weather = getWeatherAt(topEvent.focusTs || topEvent.start);
    const weatherLabel = weatherQualityLabel(weather);
    const moonPct = Number.isFinite(topEvent.moonPhase?.illuminationPct) ? `${topEvent.moonPhase.illuminationPct}% moon` : "Moon unknown";
    const extraCount = Math.max(0, group.events.length - 1);
    const hasSecondaryItems = extraCount > 0;
    const expanded = hasSecondaryItems && (
      state.ui.expandedSkyDayKeys.has(group.dayKey) ||
      group.events.some((event) => !event.isTopOfDay && event.id === selectedEventId)
    );
    const wrapper = document.createElement("div");
    wrapper.className = `sky-day-group${group.isBestNight ? " best-night" : ""}`;
    wrapper.innerHTML = `
      <div class="sky-day-header">
        <div class="sky-day-heading">
          <div class="sky-day-label">${group.dayLabel}</div>
          <div class="sky-day-meta">${group.events.length} highlight${group.events.length === 1 ? "" : "s"} • ${moonPct} • ${weatherLabel}</div>
        </div>
        <div class="sky-day-badges">
          ${group.isBestNight ? `<span class="badge best">Best Night</span>` : ""}
        </div>
      </div>
    `;

    wrapper.appendChild(createSkyTopPick(topEvent, selectedEventId));

    if (hasSecondaryItems) {
      const toggle = document.createElement("button");
      toggle.type = "button";
      toggle.className = "sky-day-toggle";
      toggle.setAttribute("aria-expanded", String(expanded));
      toggle.innerHTML = `
        <span>${expanded ? "Hide extra highlights" : `Show ${extraCount} more tonight`}</span>
        <span class="sky-day-toggle-icon">${expanded ? "−" : "+"}</span>
      `;
      toggle.addEventListener("click", () => {
        if (state.ui.expandedSkyDayKeys.has(group.dayKey)) {
          state.ui.expandedSkyDayKeys.delete(group.dayKey);
        } else {
          state.ui.expandedSkyDayKeys.add(group.dayKey);
        }
        renderSkyEventsList();
      });
      wrapper.appendChild(toggle);

      if (expanded) {
        const list = document.createElement("div");
        list.className = "sky-day-secondary";
        group.events
          .filter((event) => !event.isTopOfDay)
          .forEach((event) => {
            list.appendChild(createSkySecondaryRow(event, selectedEventId));
          });
        wrapper.appendChild(list);
      }
    }

    skyEventsList.appendChild(wrapper);
  });
}

function buildGuideCandidatesForWindow(lat, lon, tonightWindow) {
  if (!window.Astronomy?.Observer) return [];
  const observer = new window.Astronomy.Observer(lat, lon, 0);
  const startTs = Math.max(Math.floor(Date.now() / 1000), tonightWindow.startTs);
  const endTs = tonightWindow.endTs;
  const samples = [];
  for (let ts = startTs; ts <= endTs; ts += 45 * 60) {
    samples.push(ts);
  }
  if (!samples.length) samples.push(startTs);

  const candidates = [];
  const evaluateCatalogItem = (entry, kind, options = {}) => {
    let best = null;
    samples.forEach((ts) => {
      const date = new Date(ts * 1000);
      const context = getSkyContextAt(date, lat, lon);
      if (context.sunAltitude >= (options.maxSunAltitudeDeg ?? -6)) return;
      const obs = getEquatorialObservation(entry, date, observer);
      if (!obs) return;
      const minElevation = options.minElevation ?? 20;
      if (obs.elevation < minElevation) return;
      const weather = getWeatherAt(ts);
      const score = obs.elevation + context.darkSkyScore * 0.4 + weatherScore(weather) * 0.25;
      if (!best || score > best.score) {
        best = { ts, obs, context, weather, score };
      }
    });
    if (!best) return;
    candidates.push({
      id: `${kind}-${entry.id}`,
      kind,
      title: entry.name,
      kicker: kind === "deep-sky" ? entry.type : kind === "constellation" ? "Constellation" : "Bright star",
      raHours: entry.raHours,
      decDeg: entry.decDeg,
      when: best.ts,
      detail: `Best ${formatTime(new Date(best.ts * 1000))} • ${Math.round(best.obs.elevation)}° ${azimuthToCompass(best.obs.azimuth)}`,
      note: entry.hint || entry.tip || `Look ${azimuthToCompass(best.obs.azimuth)} once it climbs above ${Math.round(best.obs.elevation)}°.`,
      tier: entry.tier || "naked-eye",
      weather: best.weather,
      darkSkyScore: best.context.darkSkyScore,
      score: best.score
    });
  };

  const currentMonth = new Date(startTs * 1000).getMonth() + 1;
  DEEP_SKY_TARGETS.forEach((target) => {
    evaluateCatalogItem(target, "deep-sky", {
      minElevation: target.tier === "binoculars" ? 22 : 18
    });
  });
  CONSTELLATIONS
    .filter((item) => item.bestMonths.includes(currentMonth))
    .forEach((item) => evaluateCatalogItem(item, "constellation", { minElevation: 24, maxSunAltitudeDeg: -5 }));
  BRIGHT_STARS
    .filter((star) => star.mag <= 1.2)
    .forEach((star) => evaluateCatalogItem(star, "star", { minElevation: 25, maxSunAltitudeDeg: -4.5 }));

  const tonightMeteor = (state.meteorEvents || []).find((event) => {
    const focusTs = event.focusTs || event.start;
    return focusTs >= tonightWindow.startTs && focusTs <= tonightWindow.endTs;
  });
  if (tonightMeteor) {
    candidates.push({
      id: `guide-${tonightMeteor.id}`,
      kind: "meteor",
      title: tonightMeteor.title,
      kicker: "Meteor shower",
      raHours: METEOR_SHOWERS.find((shower) => tonightMeteor.id.includes(shower.id))?.radiantRaHours,
      decDeg: METEOR_SHOWERS.find((shower) => tonightMeteor.id.includes(shower.id))?.radiantDecDeg,
      when: tonightMeteor.focusTs,
      detail: `Best ${formatTime(new Date(tonightMeteor.focusTs * 1000))} • ${tonightMeteor.details}`,
      note: tonightMeteor.hint,
      tier: tonightMeteor.visibilityTier || "naked-eye",
      weather: getWeatherAt(tonightMeteor.focusTs),
      darkSkyScore: tonightMeteor.darkSkyScore || 0,
      score: (tonightMeteor.qualityScore || 0) + 90
    });
  }

  const selected = [];
  const perKindLimit = new Map([
    ["meteor", 1],
    ["deep-sky", 2],
    ["constellation", 2],
    ["star", 2]
  ]);
  candidates.sort((left, right) => right.score - left.score);
  candidates.forEach((candidate) => {
    const current = selected.filter((item) => item.kind === candidate.kind).length;
    if (current >= (perKindLimit.get(candidate.kind) || 1)) return;
    selected.push(candidate);
  });
  return selected;
}

function buildSkyGuide(lat, lon, tonightWindow) {
  return buildGuideCandidatesForWindow(lat, lon, tonightWindow).slice(0, 6);
}

function buildGuideEvents(lat, lon, startTs, endTs) {
  const events = [];
  for (let dayOffset = 0; dayOffset < FORECAST_DAYS; dayOffset++) {
    const refDate = new Date((startTs + dayOffset * 24 * 3600) * 1000);
    const window = getTonightWindow(lat, lon, refDate);
    const candidates = buildGuideCandidatesForWindow(lat, lon, window)
      .sort((left, right) => right.score - left.score)
      .slice(0, 2);
    candidates.forEach((item) => {
      events.push({
        id: `guide-${item.id}-${window.startTs}`,
        type: "guide-target",
        focusTs: item.when,
        start: item.when - 1800,
        end: item.when + 1800,
        skyWindow: new Date(item.when * 1000).getHours() < 12 ? "dawn" : "evening",
        emphasis: false,
        bodies: [item.title],
        visibilityTier: item.tier,
        title: item.title,
        meta: formatDateTime(new Date(item.when * 1000)),
        details: item.detail.replace(/^Best\s+/i, ""),
        moonPhase: getSkyContextAt(new Date(item.when * 1000), lat, lon).moonPhase || null,
        moonPhaseSummary: formatMoonPhaseLine(getSkyContextAt(new Date(item.when * 1000), lat, lon).moonPhase, "Moon"),
        moonlightSummary: `Moonlight: ${moonlightQualityLabel(getSkyContextAt(new Date(item.when * 1000), lat, lon).moonlightQuality)}`,
        moonlightBadge: moonlightBadgeValue(getSkyContextAt(new Date(item.when * 1000), lat, lon).moonlightQuality),
        darkSkyScore: item.darkSkyScore,
        qualityScore: item.score,
        guideKind: item.kind,
        hint: item.note
      });
    });
  }
  return events;
}

function selectTonightPass(passes, tonightWindow, nowTs) {
  const tonightPasses = passes.filter((pass) => pass.start >= tonightWindow.startTs && pass.start <= tonightWindow.endTs);
  const activePass = tonightPasses.find((pass) => isPassActive(pass, nowTs)) || null;
  if (activePass) {
    return { pass: activePass, status: "active" };
  }

  const upcomingPass = tonightPasses.find((pass) => pass.end >= nowTs) || null;
  if (upcomingPass) {
    return { pass: upcomingPass, status: "upcoming" };
  }

  return { pass: null, status: "none" };
}

function selectTonightSkyEvent(events, tonightWindow, nowTs) {
  const tonightEvents = events.filter((event) => {
    const focusTs = getEventFocusTs(event);
    return focusTs >= tonightWindow.startTs && focusTs <= tonightWindow.endTs && (event.end || focusTs) >= tonightWindow.startTs;
  });

  const activeEvent = tonightEvents
    .filter((event) => isSkyEventActive(event, nowTs))
    .sort((left, right) => (right.rankScore || 0) - (left.rankScore || 0) || (left.end || getEventFocusTs(left)) - (right.end || getEventFocusTs(right)))[0] || null;
  if (activeEvent) {
    return { event: activeEvent, status: "active" };
  }

  const upcomingEvent = tonightEvents
    .filter((event) => (event.end || getEventFocusTs(event)) >= nowTs)
    .sort((left, right) => (right.rankScore || 0) - (left.rankScore || 0) || getEventFocusTs(left) - getEventFocusTs(right))[0] || null;
  if (upcomingEvent) {
    return { event: upcomingEvent, status: "upcoming" };
  }

  return { event: null, status: "none" };
}

function buildTonightScheduleEntries(lat, lon, tonightWindow, snapshot, nowTs = Math.floor(Date.now() / 1000)) {
  const entries = [];
  const timelineStartTs = Math.max(nowTs, tonightWindow.startTs);
  const pushEntry = (timestamp, label, sub, tone = "default") => {
    if (!timestamp) return;
    if (timestamp < timelineStartTs || timestamp > tonightWindow.endTs) return;
    entries.push({ timestamp, label, sub, tone });
  };

  const maybePush = (date, label, sub, tone) => {
    if (!(date instanceof Date)) return;
    const ts = Math.floor(date.getTime() / 1000);
    if (ts >= timelineStartTs && ts <= tonightWindow.endTs) pushEntry(ts, label, sub, tone);
  };

  maybePush(tonightWindow.sunset, "Sunset", "Golden hour ends", "sun");
  maybePush(tonightWindow.civilDusk, "Civil dusk", "Bright planets begin to pop", "twilight");
  maybePush(tonightWindow.astronomicalDusk, "Astronomical dark", "Deep-sky viewing improves", "dark");

  const moonTimes = SunCalc.getMoonTimes(new Date(), lat, lon, true);
  if (moonTimes?.rise instanceof Date) maybePush(moonTimes.rise, "Moonrise", "Moonlight increases", "moon");
  if (moonTimes?.set instanceof Date) maybePush(moonTimes.set, "Moonset", "Skies darken", "moon");

  if (snapshot.issTonight?.pass) {
    if (snapshot.issTonight.status === "active") {
      pushEntry(nowTs, "ISS pass in progress", `Started ${formatTime(new Date(snapshot.issTonight.pass.start * 1000))} • Max ${snapshot.issTonight.pass.maxEl.toFixed(0)}° • ${snapshot.issTonight.pass.duration} min`, "iss");
    } else {
      pushEntry(snapshot.issTonight.pass.start, "ISS pass begins", `Max ${snapshot.issTonight.pass.maxEl.toFixed(0)}° • ${snapshot.issTonight.pass.duration} min`, "iss");
    }
  }
  if (snapshot.skyTonight?.event) {
    const focusTs = snapshot.skyTonight.event.focusTs || snapshot.skyTonight.event.start;
    if (snapshot.skyTonight.status === "active") {
      pushEntry(nowTs, `${getSkyEventDisplayLabel(snapshot.skyTonight.event)} now`, `Started ${formatTime(new Date(snapshot.skyTonight.event.start * 1000))} • ${snapshot.skyTonight.event.details}`, "event");
    } else {
      pushEntry(focusTs, snapshot.skyTonight.event.title, `${getSkyEventWindowLabel(snapshot.skyTonight.event)} • ${snapshot.skyTonight.event.details}`, "event");
    }
  }

  const clearWindow = findClearestWindow(timelineStartTs, tonightWindow.endTs);
  if (clearWindow && weatherScore(clearWindow) >= 48) {
    pushEntry(clearWindow.timestamp, "Clearest weather", `${weatherQualityLabel(clearWindow)} • Cloud ${Math.round(clearWindow.cloudCover)}%`, "weather");
  }

  maybePush(tonightWindow.astronomicalDawn, "Astronomical dawn", "Deep-sky contrast fades", "twilight");
  maybePush(tonightWindow.sunrise, "Sunrise", "Night observing ends", "sun");

  return entries
    .sort((left, right) => left.timestamp - right.timestamp)
    .slice(0, 9);
}

function buildTonightSnapshot(referenceDate = new Date()) {
  if (!state.user) {
    return {
      issTonight: { pass: null, nextPass: null, status: "none" },
      skyTonight: { event: null, nextEvent: null, status: "none" },
      moonTonight: null,
      weatherTonight: { summary: null, clearestWindow: null, error: null },
      scheduleEntries: [],
      window: null
    };
  }

  const nowTs = Math.floor(referenceDate.getTime() / 1000);
  const windowInfo = getTonightWindow(state.user.lat, state.user.lon, referenceDate);
  const tonightStartTs = Math.max(nowTs, windowInfo.startTs);
  const tonightEndTs = windowInfo.endTs;
  const tonightPassSelection = selectTonightPass(state.goodPasses, windowInfo, nowTs);
  const tonightEventSelection = selectTonightSkyEvent(state.skyEvents, windowInfo, nowTs);

  const tonightPass = tonightPassSelection.pass;
  const nextPass = state.goodPasses.find((pass) => pass.start > tonightEndTs) || state.goodPasses[0] || null;
  const tonightEvent = tonightEventSelection.event;
  const nextEvent = state.skyEvents.find((event) => getEventFocusTs(event) > tonightEndTs) || state.skyEvents[0] || null;
  const hasActiveSelection = tonightPassSelection.status === "active" || tonightEventSelection.status === "active";
  const moonFocusTs = hasActiveSelection
    ? nowTs
    : tonightPass?.peakPoint?.timestamp || getEventFocusTs(tonightEvent) || tonightStartTs;
  const moonContext = getSkyContextAt(new Date(moonFocusTs * 1000), state.user.lat, state.user.lon);
  const weatherSummary = summarizeWeatherWindow(tonightStartTs, tonightEndTs);
  const clearestWindow = findClearestWindow(tonightStartTs, tonightEndTs);

  const snapshot = {
    issTonight: { pass: tonightPass, nextPass, status: tonightPassSelection.status },
    skyTonight: { event: tonightEvent, nextEvent, status: tonightEventSelection.status },
    moonTonight: { context: moonContext, focusTs: moonFocusTs },
    weatherTonight: { summary: weatherSummary, clearestWindow, error: state.weather.error },
    scheduleEntries: [],
    window: windowInfo
  };

  snapshot.scheduleEntries = buildTonightScheduleEntries(state.user.lat, state.user.lon, windowInfo, snapshot, nowTs);
  return snapshot;
}

function renderTimeline() {
  if (!timelineList) return;
  if (!state.user) {
    timelineList.innerHTML = `
      <div class="timeline-item">
        <div class="timeline-dot"></div>
        <div class="timeline-time">--:--</div>
        <div class="timeline-label">Waiting for location</div>
        <div class="timeline-sub">Sunset, sky windows, and weather appear here.</div>
      </div>
    `;
    return;
  }
  const scheduleEntries = state.tonightSnapshot?.scheduleEntries || [];
  if (!scheduleEntries.length) {
    timelineList.innerHTML = `
      <div class="timeline-item">
        <div class="timeline-dot"></div>
        <div class="timeline-time">--:--</div>
        <div class="timeline-label">Quiet night</div>
        <div class="timeline-sub">No notable observing windows were found tonight.</div>
      </div>
    `;
    return;
  }
  timelineList.innerHTML = scheduleEntries.map((entry) => `
    <div class="timeline-item ${entry.tone === "event" || entry.tone === "meteor" ? "sky" : entry.tone === "weather" ? "weather" : entry.tone === "iss" ? "iss" : entry.tone === "moon" || entry.tone === "dark" ? "moon" : entry.tone === "sun" || entry.tone === "twilight" ? "rare" : ""}">
      <div class="timeline-dot"></div>
      <div class="timeline-time">${formatTime(new Date(entry.timestamp * 1000))}</div>
      <div class="timeline-label">${entry.label}</div>
      <div class="timeline-sub">${entry.sub}</div>
    </div>
  `).join("");
}

function renderConditionsList() {
  if (!conditionsList) return;
  if (!state.user) {
    conditionsList.innerHTML = `
      <div class="condition-item">
        <p class="pass-title">Waiting for forecast…</p>
        <div class="pass-meta">Weather and moonlight conditions appear here.</div>
      </div>
    `;
    return;
  }

  const items = [];
  if (state.tonightWindow) {
    const summary = summarizeWeatherWindow(Math.max(Math.floor(Date.now() / 1000), state.tonightWindow.startTs), state.tonightWindow.endTs);
    if (summary) {
      items.push({
        title: "Weather tonight",
        meta: `${summary.label} • Cloud ${Math.round(summary.cloudCover)}% • Wind ${Math.round(summary.windSpeed)} km/h`,
        note: `Visibility ${Math.round((summary.visibility || 0) / 1000)} km • Rain chance ${Math.round(summary.precipitationProbability)}%`,
        badge: summary.label === "Clear" || summary.label === "Mostly clear" ? "weather-clear" : "weather-risk",
        badgeLabel: summary.label
      });
      const clearest = findClearestWindow(Math.max(Math.floor(Date.now() / 1000), state.tonightWindow.startTs), state.tonightWindow.endTs);
      if (clearest) {
        items.push({
          title: "Clearest window",
          meta: `${formatTime(new Date(clearest.timestamp * 1000))} • Cloud ${Math.round(clearest.cloudCover)}% • Wind ${Math.round(clearest.windSpeed)} km/h`,
          note: `${weatherQualityLabel(clearest)} • Visibility ${Math.round((clearest.visibility || 0) / 1000)} km`,
          badge: weatherBadgeValue(clearest) === "clear" ? "weather-clear" : "weather-risk",
          badgeLabel: weatherQualityLabel(clearest)
        });
      }
    }
  }

  if (state.tonightWindow) {
    const moonContext = getSkyContextAt(new Date(Math.max(Math.floor(Date.now() / 1000), state.tonightWindow.startTs) * 1000), state.user.lat, state.user.lon);
    items.push({
      title: "Moonlight tonight",
      meta: `${moonContext.moonPhase.icon} ${moonContext.moonPhase.name} • ${moonlightQualityLabel(moonContext.moonlightQuality)}`,
      note: `Dark-sky score ${Math.round(moonContext.darkSkyScore)}/100${moonContext.moonAboveHorizon ? "" : " • Moon below horizon for part of the night"}`,
      badge: moonContext.moonlightQuality === "dark" ? "weather-clear" : moonContext.moonlightQuality === "bright" ? "weather-risk" : "",
      badgeLabel: moonContext.moonlightQuality === "dark" ? "Dark sky" : moonContext.moonlightQuality === "bright" ? "Bright moon" : ""
    });
  }

  if (!items.length) {
    items.push({
      title: "Conditions unavailable",
      meta: "Weather or moonlight forecast is not available yet",
      note: "Try refreshing once location has been set.",
      badge: "",
      badgeLabel: ""
    });
  }

  conditionsList.innerHTML = items.map((item) => `
    <div class="condition-item">
      <div class="condition-head">
        <div class="guide-title">${item.title}</div>
        ${item.badge ? `<span class="badge ${item.badge}">${item.badgeLabel}</span>` : ""}
      </div>
      <div class="condition-meta">${item.meta}</div>
      <div class="condition-hint">${item.note}</div>
    </div>
  `).join("");
}

function enrichPassesWithSkyContext(passes) {
  state.passSkyHighlights = {};
  if (!state.user || !window.Astronomy || !window.Astronomy.Observer) {
    state.alignmentEvents = [];
    state.skyEvents = [];
    return passes;
  }

  const now = Math.floor(Date.now() / 1000);
  const end = now + FORECAST_DAYS * 24 * 3600;
  state.alignmentEvents = computeAlignmentEvents(now, end, state.user.lat, state.user.lon);
  state.skyEvents = buildSkyEvents(state.user.lat, state.user.lon, state.alignmentEvents);

  return passes.map((pass) => {
    if (!pass.visible) {
      const quiet = {
        skySummary: "",
        moonSummary: "",
        moonPhase: null,
        moonPhaseSummary: "",
        moonlightSummary: "",
        moonlightBadge: "",
        darkSkyScore: 0,
        alignmentSummary: "",
        topTargets: [],
        alignmentEvent: null
      };
      state.passSkyHighlights[passKey(pass)] = quiet;
      return { ...pass, ...quiet };
    }

    const peakTimestamp = pass.peakPoint?.timestamp || Math.round((pass.start + pass.end) / 2);
    const sampleTimes = [pass.start, peakTimestamp, pass.end];
    const sampleContexts = sampleTimes.map((timestamp) => ({
      timestamp,
      context: getSkyContextAt(new Date(timestamp * 1000), state.user.lat, state.user.lon)
    }));
    const bestTargets = new Map();
    let bestMoon = null;

    sampleContexts.forEach(({ context }) => {
      context.visiblePlanets.forEach((target) => {
        const existing = bestTargets.get(target.body);
        if (!existing || target.elevation > existing.elevation) {
          bestTargets.set(target.body, target);
        }
      });
      if (context.moon && (!bestMoon || context.moon.elevation > bestMoon.elevation)) {
        bestMoon = context.moon;
      }
    });

    const topTargets = Array.from(bestTargets.values())
      .sort((a, b) => {
        const magA = Number.isFinite(a.magnitude) ? a.magnitude : 99;
        const magB = Number.isFinite(b.magnitude) ? b.magnitude : 99;
        if (magA !== magB) return magA - magB;
        return b.elevation - a.elevation;
      })
      .slice(0, 3);

    const peakContextEntry = sampleContexts.reduce((closest, entry) => {
      if (!closest) return entry;
      return Math.abs(entry.timestamp - peakTimestamp) < Math.abs(closest.timestamp - peakTimestamp) ? entry : closest;
    }, null);
    const peakContext = peakContextEntry ? peakContextEntry.context : null;
    const alignmentEvent = findNearbyAlignment(peakTimestamp, state.alignmentEvents);
    const skySummary = topTargets.length ? `During pass: ${topTargets.map(formatSkyTarget).join(", ")}` : "";
    const moonSummary = bestMoon ? `Moon: ${Math.round(bestMoon.elevation)}° ${azimuthToCompass(bestMoon.azimuth)}` : "";
    const moonPhaseSummary = peakContext?.moonPhase ? formatMoonPhaseLine(peakContext.moonPhase, "Moon phase") : "";
    const moonlightQuality = peakContext?.moonlightQuality || "balanced";
    const moonlightSummary = `Moonlight: ${moonlightQualityLabel(moonlightQuality)}`;
    const moonlightBadge = moonlightBadgeValue(moonlightQuality);
    const darkSkyScore = peakContext?.darkSkyScore ?? 0;
    const alignmentSummary = alignmentEvent
      ? `${alignmentEvent.label} ${alignmentEvent.minSeparation.toFixed(1)}° apart`
      : "";

    const highlight = {
      skySummary,
      moonSummary,
      moonPhase: peakContext?.moonPhase || null,
      moonPhaseSummary,
      moonlightSummary,
      moonlightBadge,
      darkSkyScore,
      alignmentSummary,
      topTargets,
      alignmentEvent
    };
    state.passSkyHighlights[passKey(pass)] = highlight;
    return { ...pass, ...highlight };
  });
}

function registerGestureBlocker(element, isActive) {
  if (!element) return;
  let active = false;

  const onTouchStart = () => {
    active = isActive();
  };

  const onTouchMove = (event) => {
    if (!active || !isActive()) return;
    if (event.cancelable) {
      event.preventDefault();
    }
  };

  const onTouchEnd = () => {
    active = false;
  };

  element.addEventListener("touchstart", onTouchStart, { passive: true });
  element.addEventListener("touchmove", onTouchMove, { passive: false });
  element.addEventListener("touchend", onTouchEnd, { passive: true });
  element.addEventListener("touchcancel", onTouchEnd, { passive: true });
}

function renderLocationStatus() {
  if (!locateButton || !locationLabelEl || !locationCoordsEl || !locationMetaEl) return;

  const hasLocation = Boolean(state.user && Number.isFinite(state.user.lat) && Number.isFinite(state.user.lon));
  const buttonLabel = hasLocation ? "Update location" : "Use my location";
  locateButton.setAttribute("aria-label", buttonLabel);
  locateButton.setAttribute("title", buttonLabel);
  locateButton.classList.toggle("needs-location", !hasLocation);
  const hiddenText = locateButton.querySelector(".visually-hidden");
  if (hiddenText) hiddenText.textContent = buttonLabel;

  if (!hasLocation) {
    locationLabelEl.textContent = "Location not set";
    locationCoordsEl.textContent = "Use your location for local passes, sky events, and weather.";
    locationCoordsEl.hidden = false;
    locationMetaEl.hidden = false;
    locationMetaEl.textContent = "Update if you've moved since the last visit.";
    return;
  }

  const coordsLine = getCoordsLine(state.user.lat, state.user.lon);
  if (state.user.label) {
    locationLabelEl.textContent = normalizeLocalityName(state.user.label);
    locationCoordsEl.textContent = coordsLine;
    locationCoordsEl.hidden = false;
  } else {
    locationLabelEl.textContent = coordsLine;
    locationCoordsEl.hidden = true;
  }

  locationMetaEl.hidden = true;
  locationMetaEl.textContent = "";
}

function buildStoredLocationPayload(user) {
  return {
    lat: user.lat,
    lon: user.lon,
    source: getStoredLocationSource(user.source || ""),
    label: user.label || "",
    regionCode: user.regionCode || "",
    geocodedAt: user.geocodedAt || 0,
    savedAt: Date.now()
  };
}

async function ensureUserLocationLabel({ persist = true } = {}) {
  const user = state.user;
  if (!user || user.label || !Number.isFinite(user.lat) || !Number.isFinite(user.lon)) return;

  try {
    const result = await reverseGeocodeLocation(user.lat, user.lon);
    if (!state.user || state.user.lat !== user.lat || state.user.lon !== user.lon) return;
    if (!result.label) return;

    state.user = {
      ...state.user,
      label: result.label,
      regionCode: result.regionCode || "",
      geocodedAt: Date.now()
    };
    if (persist) {
      saveUserLocation(state.user);
    }
    setStatus();
  } catch (error) {
    console.warn("Reverse geocoding unavailable", error);
  }
}

function saveUserLocation(lat, lon, source) {
  try {
    const user = typeof lat === "object" && lat !== null ? lat : { lat, lon, source };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(buildStoredLocationPayload(user)));
  } catch (error) {
    console.warn("Unable to persist location", error);
  }
}

function loadStoredLocation() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return false;
    const data = JSON.parse(raw);
    if (!Number.isFinite(data.lat) || !Number.isFinite(data.lon)) return false;
    const rawSource = typeof data.source === "string" ? getStoredLocationSource(data.source) : "";
    state.user = {
      lat: data.lat,
      lon: data.lon,
      source: rawSource ? `${rawSource} (saved)` : "Saved location",
      label: typeof data.label === "string" && data.label.trim() ? data.label.trim() : "",
      regionCode: typeof data.regionCode === "string" ? data.regionCode : "",
      geocodedAt: Number.isFinite(data.geocodedAt) ? data.geocodedAt : 0
    };
    updateUserMarker();
    setStatus();
    if (!state.user.label) {
      void ensureUserLocationLabel();
    }
    return true;
  } catch (error) {
    console.warn("Stored location unavailable", error);
    return false;
  }
}

function interpolateLongitude(lonA, lonB, t) {
  let delta = lonB - lonA;
  if (Math.abs(delta) > 180) {
    delta -= Math.sign(delta) * 360;
  }
  return wrapLongitude(lonA + delta * t);
}

function interpolateSample(prev, next, nowMs) {
  if (!prev && !next) return null;
  if (!prev) return next;
  if (!next) return prev;
  const span = Math.max(1, next.localTime - prev.localTime);
  const t = Math.min(1, Math.max(0, (nowMs - prev.localTime) / span));
  const altitudeA = prev.altitude ?? 0;
  const altitudeB = next.altitude ?? altitudeA;
  const velocityA = prev.velocity ?? 0;
  const velocityB = next.velocity ?? velocityA;
  return {
    ...next,
    latitude: prev.latitude + (next.latitude - prev.latitude) * t,
    longitude: interpolateLongitude(prev.longitude, next.longitude, t),
    altitude: altitudeA + (altitudeB - altitudeA) * t,
    velocity: velocityA + (velocityB - velocityA) * t
  };
}

function buildTrackSegments(points) {
  if (!points.length) return [];
  const segments = [];
  let segment = [];
  points.forEach((point) => {
    if (!segment.length) {
      segment.push(point);
      return;
    }
    const prev = segment[segment.length - 1];
    const delta = Math.abs(point.longitude - prev.longitude);
    if (delta > 180) {
      segments.push(segment);
      segment = [point];
    } else {
      segment.push(point);
    }
  });
  if (segment.length) segments.push(segment);
  return segments.map((seg) => seg.map((p) => [p.latitude, p.longitude]));
}

function setStatus() {
  const issCoords = document.getElementById("iss-coords");
  const issMeta = document.getElementById("iss-meta");
  const userCoords = document.getElementById("user-coords");
  const userMeta = document.getElementById("user-meta");
  const nextPass = document.getElementById("next-pass");
  const nextPassMeta = document.getElementById("next-pass-meta");
  const visibility = document.getElementById("visibility");
  const visibilityMeta = document.getElementById("visibility-meta");
  const moonPhase = document.getElementById("moon-phase");
  const moonPhaseMeta = document.getElementById("moon-phase-meta");

  if (state.iss) {
    issCoords.textContent = `${formatCoord(state.iss.latitude)}, ${formatCoord(state.iss.longitude)}`;
    issMeta.textContent = `Altitude ${state.iss.altitude.toFixed(1)} km • Velocity ${state.iss.velocity.toFixed(0)} km/h`;
  } else {
    issCoords.textContent = "Loading…";
    issMeta.textContent = "Awaiting data";
  }

  renderLocationStatus();

  if (state.user) {
    userCoords.textContent = getCoordsLine(state.user.lat, state.user.lon);
    userMeta.textContent = [state.user.label, getUserSourceMeta(state.user.source)].filter(Boolean).join(" · ") || "Custom location";
  } else {
    userCoords.textContent = "Unknown";
    userMeta.textContent = "Geolocation not set";
  }

  if (state.nextVisible) {
    nextPass.textContent = formatDateTime(new Date(state.nextVisible.start * 1000));
    nextPassMeta.textContent = `Max elevation ${state.nextVisible.maxEl.toFixed(0)}° • Visible ${state.nextVisible.duration} min`;
  } else {
    nextPass.textContent = "No visible pass found";
    nextPassMeta.textContent = state.user ? `No good passes in the next ${FORECAST_DAYS} days` : "Need location to predict";
  }

  if (state.user) {
    const nowContext = getSkyContextAt(new Date(), state.user.lat, state.user.lon);
    const sunAlt = nowContext.sunAltitude;
    const label = sunAlt < -6 ? "Night" : sunAlt < 0 ? "Civil Twilight" : "Daylight";
    visibility.textContent = label;
    visibilityMeta.textContent = `Sun altitude ${sunAlt.toFixed(1)}°`;
    if (nowContext.moonPhase) {
      moonPhase.textContent = `${nowContext.moonPhase.icon} ${nowContext.moonPhase.name} • ${nowContext.moonPhase.illuminationPct}%`;
      if (sunAlt < PLANET_VISUALS.maxSunAltitudeDeg) {
        if (!nowContext.moonAboveHorizon) {
          moonPhaseMeta.textContent = `Moon below horizon now • Dark-sky score ${Math.round(nowContext.darkSkyScore)}/100`;
        } else {
          moonPhaseMeta.textContent = `Moonlight ${moonlightQualityLabel(nowContext.moonlightQuality)} • Dark-sky score ${Math.round(nowContext.darkSkyScore)}/100`;
        }
      } else {
        moonPhaseMeta.textContent = `Daylight now • Dark-sky score ${Math.round(nowContext.darkSkyScore)}/100`;
      }
    } else {
      moonPhase.textContent = "Unavailable";
      moonPhaseMeta.textContent = "Moon phase data unavailable";
    }
  } else {
    visibility.textContent = "Night check pending";
    visibilityMeta.textContent = "Sun altitude unavailable";
    moonPhase.textContent = "Calculating…";
    moonPhaseMeta.textContent = "Need location to evaluate sky darkness";
  }
}

function updateTonightHighlights() {
  const tonightIss = document.getElementById("tonight-iss");
  const tonightIssMeta = document.getElementById("tonight-iss-meta");
  const tonightSky = document.getElementById("tonight-sky");
  const tonightSkyMeta = document.getElementById("tonight-sky-meta");
  const tonightMoon = document.getElementById("tonight-moon");
  const tonightMoonMeta = document.getElementById("tonight-moon-meta");
  const tonightWeather = document.getElementById("tonight-weather");
  const tonightWeatherMeta = document.getElementById("tonight-weather-meta");
  const shareTonightIssBtn = document.getElementById("share-tonight-iss");
  const shareTonightSkyBtn = document.getElementById("share-tonight-sky");

  if (!tonightIss || !tonightSky || !tonightMoon || !tonightWeather) return;

  state.tonightSnapshot = buildTonightSnapshot();

  if (!state.user) {
    state.tonight.pass = null;
    state.tonight.skyEvent = null;
    state.tonightWindow = null;
    state.tonightTimeline = [];
    tonightIss.textContent = "Set your location";
    tonightIssMeta.textContent = "Need location to find tonight's visible ISS pass.";
    tonightSky.textContent = "Set your location";
    tonightSkyMeta.textContent = "Need location to evaluate visible planets and alignments.";
    tonightMoon.textContent = "Moon phase pending";
    tonightMoonMeta.textContent = "Moonlight quality needs your observing location.";
    tonightWeather.textContent = "Weather pending";
    tonightWeatherMeta.textContent = "Weather forecast needs your observing location.";
    if (shareTonightIssBtn) shareTonightIssBtn.disabled = true;
    if (shareTonightSkyBtn) shareTonightSkyBtn.disabled = true;
    return;
  }

  const snapshot = state.tonightSnapshot;
  const tonightPass = snapshot.issTonight.pass;
  const nextPass = snapshot.issTonight.nextPass;
  const tonightEvent = snapshot.skyTonight.event;
  const nextSkyEvent = snapshot.skyTonight.nextEvent;
  const tonightPassStatus = snapshot.issTonight.status;
  const tonightEventStatus = snapshot.skyTonight.status;
  state.tonight.pass = tonightPass;
  state.tonight.skyEvent = tonightEvent;
  state.tonightWindow = snapshot.window;
  state.tonightTimeline = snapshot.scheduleEntries;
  if (state.ui.timelineExpanded && !state.ui.booting) {
    renderTimeline();
  }

  if (tonightPass) {
    if (tonightPassStatus === "active") {
      tonightIss.textContent = "Happening now";
      tonightIssMeta.textContent = `Started ${formatTime(new Date(tonightPass.start * 1000))} • Max ${tonightPass.maxEl.toFixed(0)}° • Visible ${tonightPass.duration} min`;
    } else {
      tonightIss.textContent = formatTonightMoment(tonightPass.start);
      tonightIssMeta.textContent = `Max ${tonightPass.maxEl.toFixed(0)}° • Visible ${tonightPass.duration} min`;
    }
  } else {
    tonightIss.textContent = "No ISS pass tonight";
    tonightIssMeta.textContent = nextPass
      ? `Next good pass ${formatDateTime(new Date(nextPass.start * 1000))}`
      : `No high-quality night pass in the next ${FORECAST_DAYS} days.`;
  }

  if (tonightEvent) {
    const eventLabel = getSkyEventDisplayLabel(tonightEvent);
    tonightSky.textContent = eventLabel;
    if (tonightEventStatus === "active") {
      tonightSkyMeta.textContent = `Happening now • Started ${formatTime(new Date(tonightEvent.start * 1000))} • ${tonightEvent.details}`;
    } else {
      tonightSkyMeta.textContent = `${getSkyEventWindowLabel(tonightEvent)} • ${formatTonightMoment(tonightEvent.focusTs || tonightEvent.start)} • ${tonightEvent.details}`;
    }
  } else {
    tonightSky.textContent = "No standout sky event tonight";
    tonightSkyMeta.textContent = nextSkyEvent
      ? `Next highlight ${formatDateTime(new Date((nextSkyEvent.focusTs || nextSkyEvent.start) * 1000))}`
      : "No standout naked-eye grouping detected in the next week.";
  }

  const context = snapshot.moonTonight?.context;
  if (context?.moonPhase) {
    const quality = moonlightQualityLabel(context.moonlightQuality);
    tonightMoon.textContent = `${context.moonPhase.icon} ${context.moonPhase.name} • ${context.moonPhase.illuminationPct}%`;
    if (context.sunAltitude >= PLANET_VISUALS.maxSunAltitudeDeg) {
      tonightMoonMeta.textContent = `Before dark • Dark-sky score ${Math.round(context.darkSkyScore)}/100`;
    } else if (!context.moonAboveHorizon) {
      tonightMoonMeta.textContent = `Moon below horizon • Dark-sky score ${Math.round(context.darkSkyScore)}/100`;
    } else {
      tonightMoonMeta.textContent = `Moonlight ${quality} • Dark-sky score ${Math.round(context.darkSkyScore)}/100`;
    }
  } else {
    tonightMoon.textContent = "Moon phase unavailable";
    tonightMoonMeta.textContent = "Moonlight quality unavailable.";
  }

  const weatherSummary = snapshot.weatherTonight.summary;
  const clearestWindow = snapshot.weatherTonight.clearestWindow;
  if (weatherSummary) {
    tonightWeather.textContent = weatherSummary.label;
    const clearSnippet = clearestWindow
      ? ` • Clearest ${formatTime(new Date(clearestWindow.timestamp * 1000))}`
      : "";
    tonightWeatherMeta.textContent = `Cloud ${Math.round(weatherSummary.cloudCover)}% • Wind ${Math.round(weatherSummary.windSpeed)} km/h${clearSnippet}`;
  } else if (snapshot.weatherTonight.error) {
    tonightWeather.textContent = "Weather unavailable";
    tonightWeatherMeta.textContent = "Could not load observing weather.";
  } else {
    tonightWeather.textContent = "Weather pending";
    tonightWeatherMeta.textContent = "Forecast is still loading.";
  }

  if (shareTonightIssBtn) shareTonightIssBtn.disabled = !Boolean(state.tonight.pass);
  if (shareTonightSkyBtn) shareTonightSkyBtn.disabled = !Boolean(state.tonight.skyEvent);
}

function showMapMessage(message) {
  if (state.mapFallbackNotified) return;
  state.mapFallbackNotified = true;

  const existing = mapEl.querySelector(".map-status");
  if (existing) existing.remove();

  const note = document.createElement("div");
  note.className = "map-status";
  note.textContent = message;
  mapEl.appendChild(note);

  window.setTimeout(() => {
    note.classList.add("fade");
    window.setTimeout(() => note.remove(), 360);
  }, 4200);
}

function initMap() {
  const bounds = L.latLngBounds([[-85, -180], [85, 180]]);
  const initialZoom = computeNoWrapFitZoom(mapEl.clientWidth || window.innerWidth);
  state.mapFitZoom = initialZoom;

  mapEl.style.setProperty("--map-bg", MAP_VISUALS.mapBackground);
  mapEl.style.setProperty("--map-tile-filter-primary", MAP_VISUALS.tileFilterPrimary);
  mapEl.style.setProperty("--map-tile-filter-fallback", MAP_VISUALS.tileFilterFallback);
  setMapTheme("primary");

  state.map = L.map(mapEl, {
    zoomControl: true,
    worldCopyJump: false,
    maxBounds: bounds,
    maxBoundsViscosity: 1.0,
    preferCanvas: false,
    minZoom: initialZoom,
    maxZoom: 8
  }).setView([0, 0], initialZoom);

  const createTileLayer = (url) => L.tileLayer(url, {
    attribution: "&copy; OpenStreetMap contributors &copy; CARTO",
    subdomains: "abcd",
    maxZoom: 8,
    noWrap: true,
    bounds
  });

  state.mapTileLayer = createTileLayer(MAP_VISUALS.tilePrimary).addTo(state.map);

  let tileErrors = 0;
  const tileErrorLimit = 3;
  const tileErrorWindowMs = 12000;
  const tileLoadStart = Date.now();
  const activateFallback = () => {
    if (state.mapTheme === "fallback") return;
    if (state.mapTileLayer) {
      state.map.removeLayer(state.mapTileLayer);
    }
    state.mapTileLayer = createTileLayer(MAP_VISUALS.tileFallback).addTo(state.map);
    setMapTheme("fallback");
    showMapMessage("Map style fallback active.");
  };

  state.mapTileLayer.on("tileerror", () => {
    if (state.mapTheme === "fallback") return;
    if (Date.now() - tileLoadStart > tileErrorWindowMs) return;
    tileErrors += 1;
    if (tileErrors >= tileErrorLimit) {
      activateFallback();
    }
  });

  const issIcon = L.divIcon({
    className: "iss-marker",
    html: '<div class="iss-dot"></div>',
    iconSize: [20, 20],
    iconAnchor: [10, 10]
  });

  state.markers.iss = L.marker([0, 0], { icon: issIcon }).addTo(state.map);
  state.trackOutline = L.polyline([], {
    color: MAP_VISUALS.trackOutlineColor,
    weight: 7,
    opacity: 0.55,
    lineCap: "round"
  }).addTo(state.map);
  state.trackGlow = L.polyline([], {
    color: MAP_VISUALS.trackGlowColor,
    weight: 5,
    opacity: 0.30,
    lineCap: "round"
  }).addTo(state.map);
  state.trackLine = L.polyline([], {
    color: MAP_VISUALS.trackDashColor,
    weight: 2.6,
    opacity: 0.95,
    dashArray: "7 9",
    lineCap: "round"
  }).addTo(state.map);

  syncMapNoWrapZoomConstraints(true);
}

function initMapResizing() {
  if (!state.map) return;
  let queued = false;
  const queueInvalidate = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      state.map.invalidateSize({ animate: false });
      syncMapNoWrapZoomConstraints();
    });
  };

  window.addEventListener("resize", queueInvalidate);
  window.addEventListener("scroll", queueInvalidate, { passive: true });

  if (window.ResizeObserver) {
    const observer = new ResizeObserver(queueInvalidate);
    observer.observe(document.querySelector(".viewer"));
  }

  if (window.IntersectionObserver) {
    const observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        queueInvalidate();
      }
    }, { threshold: 0.1 });
    observer.observe(mapEl);
  }
}

function updateISSMarker() {
  if (state.iss && state.map && state.markers.iss) {
    state.markers.iss.setLatLng([state.iss.latitude, state.iss.longitude]);
  }
  updateGlobeMarkers();
}

function updateUserMarker() {
  if (!state.user || !state.map) return;
  if (!state.markers.user) {
    const userIcon = L.divIcon({
      className: "user-marker",
      html: "",
      iconSize: [10, 10],
      iconAnchor: [5, 5]
    });
    state.markers.user = L.marker([state.user.lat, state.user.lon], { icon: userIcon }).addTo(state.map);
  } else {
    state.markers.user.setLatLng([state.user.lat, state.user.lon]);
  }
  updateGlobeMarkers();
}

function updateTrackLine() {
  if (!state.map || !state.trackOutline || !state.trackLine || !state.trackGlow) return;
  const source = state.trackData.length ? state.trackData : state.trail;
  const segments = buildTrackSegments(source);
  if (segments.length) {
    state.trackOutline.setLatLngs(segments);
    state.trackGlow.setLatLngs(segments);
    state.trackLine.setLatLngs(segments);
  } else {
    state.trackOutline.setLatLngs([]);
    state.trackGlow.setLatLngs([]);
    state.trackLine.setLatLngs([]);
  }
  updateGlobeTrack();
}

function latLonToVector3(lat, lon, radius = 1) {
  const phi = toRadians(90 - lat);
  const theta = toRadians(lon + 180);
  return new THREE.Vector3(
    -radius * Math.sin(phi) * Math.cos(theta),
    radius * Math.cos(phi),
    radius * Math.sin(phi) * Math.sin(theta)
  );
}

function renderGlobe() {
  if (!state.globe.ready) return;
  if (state.globe.controls) {
    state.globe.controls.update();
  }
  state.globe.renderer.render(state.globe.scene, state.globe.camera);
}

function createFallbackControls(camera, domElement) {
  const stateControls = {
    dragging: false,
    startX: 0,
    startY: 0,
    theta: 0,
    phi: 0,
    radius: camera.position.length()
  };

  const updateCamera = () => {
    const phi = Math.max(0.1, Math.min(Math.PI - 0.1, stateControls.phi));
    camera.position.set(
      stateControls.radius * Math.sin(phi) * Math.sin(stateControls.theta),
      stateControls.radius * Math.cos(phi),
      stateControls.radius * Math.sin(phi) * Math.cos(stateControls.theta)
    );
    camera.lookAt(0, 0, 0);
    renderGlobe();
  };

  const initial = camera.position.clone();
  stateControls.radius = initial.length();
  stateControls.phi = Math.acos(initial.y / stateControls.radius);
  stateControls.theta = Math.atan2(initial.x, initial.z);
  updateCamera();

  const onPointerDown = (event) => {
    stateControls.dragging = true;
    stateControls.startX = event.clientX;
    stateControls.startY = event.clientY;
    domElement.setPointerCapture(event.pointerId);
  };

  const onPointerMove = (event) => {
    if (!stateControls.dragging) return;
    const dx = event.clientX - stateControls.startX;
    const dy = event.clientY - stateControls.startY;
    stateControls.startX = event.clientX;
    stateControls.startY = event.clientY;
    stateControls.theta -= dx * 0.005;
    stateControls.phi += dy * 0.005;
    updateCamera();
  };

  const onPointerUp = (event) => {
    stateControls.dragging = false;
    domElement.releasePointerCapture(event.pointerId);
  };

  const onWheel = (event) => {
    event.preventDefault();
    const delta = Math.sign(event.deltaY);
    stateControls.radius = Math.min(4.2, Math.max(1.6, stateControls.radius + delta * 0.15));
    updateCamera();
  };

  domElement.addEventListener("pointerdown", onPointerDown);
  domElement.addEventListener("pointermove", onPointerMove);
  domElement.addEventListener("pointerup", onPointerUp);
  domElement.addEventListener("wheel", onWheel, { passive: false });
  domElement.style.cursor = "grab";

  return {
    update: () => {},
    dispose: () => {
      domElement.removeEventListener("pointerdown", onPointerDown);
      domElement.removeEventListener("pointermove", onPointerMove);
      domElement.removeEventListener("pointerup", onPointerUp);
      domElement.removeEventListener("wheel", onWheel);
    }
  };
}

function resizeGlobe() {
  if (!state.globe.ready) return;
  const rect = globeViewEl.getBoundingClientRect();
  if (!rect.width || !rect.height) return;
  state.globe.renderer.setPixelRatio(window.devicePixelRatio || 1);
  state.globe.renderer.setSize(rect.width, rect.height, false);
  state.globe.camera.aspect = rect.width / rect.height;
  state.globe.camera.updateProjectionMatrix();
  renderGlobe();
}

function showGlobeMessage(message) {
  const existing = globeViewEl.querySelector(".globe-status");
  if (existing) existing.remove();
  const note = document.createElement("div");
  note.className = "globe-status";
  note.textContent = message;
  Object.assign(note.style, {
    position: "absolute",
    right: "20px",
    top: "20px",
    padding: "10px 14px",
    background: "rgba(6, 10, 18, 0.6)",
    border: "1px solid rgba(100, 140, 200, 0.3)",
    borderRadius: "16px",
    fontFamily: "\"IBM Plex Mono\", monospace",
    fontSize: "0.75rem",
    color: "var(--muted)"
  });
  globeViewEl.appendChild(note);
}

function initGlobe() {
  if (!window.THREE || !window.THREE.WebGLRenderer) {
    showGlobeMessage("WebGL unavailable. Globe view disabled.");
    return;
  }
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  if ("outputColorSpace" in renderer && THREE.SRGBColorSpace) {
    renderer.outputColorSpace = THREE.SRGBColorSpace;
  } else if ("outputEncoding" in renderer && THREE.sRGBEncoding) {
    renderer.outputEncoding = THREE.sRGBEncoding;
  }
  if (THREE.ACESFilmicToneMapping) {
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = GLOBE_VISUALS.toneMappingExposure;
  }
  renderer.setPixelRatio(window.devicePixelRatio || 1);
  renderer.setSize(globeEl.clientWidth, globeEl.clientHeight);
  globeEl.innerHTML = "";
  globeEl.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(45, globeEl.clientWidth / globeEl.clientHeight, 0.1, 100);
  camera.position.set(0, 0, 3);

  const hasControls = !!window.THREE.OrbitControls;
  const controls = hasControls
    ? new THREE.OrbitControls(camera, renderer.domElement)
    : createFallbackControls(camera, renderer.domElement);
  if (hasControls) {
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;
    controls.enablePan = false;
    controls.minDistance = 1.7;
    controls.maxDistance = 4;
  }

  const ambient = new THREE.AmbientLight(0xffffff, GLOBE_VISUALS.ambientIntensity);
  scene.add(ambient);

  const keyLight = new THREE.DirectionalLight(0xffffff, GLOBE_VISUALS.keyIntensity);
  keyLight.position.set(...GLOBE_VISUALS.keyPosition);
  scene.add(keyLight);

  // Fill light prevents night-side crushing when rotating.
  const fillLight = new THREE.DirectionalLight(0xa9c3ff, GLOBE_VISUALS.fillIntensity);
  fillLight.position.set(...GLOBE_VISUALS.fillPosition);
  scene.add(fillLight);

  const globeGroup = new THREE.Group();
  scene.add(globeGroup);

  const earthGeometry = new THREE.SphereGeometry(1, 64, 64);
  const textureLoader = new THREE.TextureLoader();
  const earthMaterial = new THREE.MeshPhongMaterial({
    color: 0xffffff,
    emissive: new THREE.Color(GLOBE_VISUALS.emissive),
    shininess: GLOBE_VISUALS.shininess
  });
  const earth = new THREE.Mesh(earthGeometry, earthMaterial);
  globeGroup.add(earth);

  const setTextureColorSpace = (texture) => {
    if ("colorSpace" in texture && THREE.SRGBColorSpace) {
      texture.colorSpace = THREE.SRGBColorSpace;
    } else if ("encoding" in texture && THREE.sRGBEncoding) {
      texture.encoding = THREE.sRGBEncoding;
    }
  };

  const loadEarthTexture = (url, onSuccess, onError) => {
    textureLoader.load(
      url,
      (texture) => {
        setTextureColorSpace(texture);
        onSuccess(texture);
      },
      undefined,
      onError
    );
  };

  loadEarthTexture(
    GLOBE_VISUALS.texturePrimary,
    (texture) => {
      earthMaterial.map = texture;
      earthMaterial.needsUpdate = true;
      renderGlobe();
    },
    () => {
      loadEarthTexture(
        GLOBE_VISUALS.textureFallback,
        (texture) => {
          earthMaterial.map = texture;
          earthMaterial.needsUpdate = true;
          renderGlobe();
        },
        () => {
          earthMaterial.color = new THREE.Color(0x3b6d98);
          earthMaterial.needsUpdate = true;
          showGlobeMessage("Globe texture failed to load. Showing simplified surface.");
          renderGlobe();
        }
      );
    }
  );

  const atmosphere = new THREE.Mesh(
    new THREE.SphereGeometry(1.02, 64, 64),
    new THREE.MeshBasicMaterial({ color: 0x2ad1ff, transparent: true, opacity: GLOBE_VISUALS.atmosphereOpacity })
  );
  globeGroup.add(atmosphere);

  const issMesh = new THREE.Mesh(
    new THREE.SphereGeometry(0.02, 16, 16),
    new THREE.MeshBasicMaterial({ color: 0x2ad1ff })
  );
  scene.add(issMesh);

  const userMesh = new THREE.Mesh(
    new THREE.SphereGeometry(0.018, 16, 16),
    new THREE.MeshBasicMaterial({ color: 0x17f1b1 })
  );
  scene.add(userMesh);

  state.globe = {
    ready: true,
    scene,
    camera,
    renderer,
    controls,
    earth,
    issMesh,
    userMesh,
    trackLine: null,
    trackGlow: null
  };

  if (hasControls) {
    controls.addEventListener("change", renderGlobe);
  }
  window.addEventListener("resize", resizeGlobe);
  resizeGlobe();
  updateGlobeMarkers();
  updateGlobeTrack();
  renderGlobe();
  requestAnimationFrame(resizeGlobe);
}

function updateGlobeMarkers() {
  if (!state.globe.ready) return;
  if (state.iss) {
    const radius = 1 + (state.iss.altitude || 420) / 6378.137;
    state.globe.issMesh.position.copy(latLonToVector3(state.iss.latitude, state.iss.longitude, radius));
    state.globe.issMesh.visible = true;
  } else {
    state.globe.issMesh.visible = false;
  }
  if (state.user) {
    state.globe.userMesh.position.copy(latLonToVector3(state.user.lat, state.user.lon, 1.015));
    state.globe.userMesh.visible = true;
  } else {
    state.globe.userMesh.visible = false;
  }
}

function updateGlobeTrack() {
  if (!state.globe.ready) return;
  const source = state.trackData.length ? state.trackData : state.trail;
  const points = source.map((p) => latLonToVector3(p.latitude, p.longitude, 1.03));
  if (state.globe.trackLine) {
    state.globe.scene.remove(state.globe.trackLine);
    state.globe.trackLine.geometry.dispose();
    state.globe.trackLine.material.dispose();
    state.globe.trackLine = null;
  }
  if (state.globe.trackGlow) {
    state.globe.scene.remove(state.globe.trackGlow);
    state.globe.trackGlow.geometry.dispose();
    state.globe.trackGlow.material.dispose();
    state.globe.trackGlow = null;
  }
  if (points.length < 2) return;

  const geometry = new THREE.BufferGeometry().setFromPoints(points);
  const glowMaterial = new THREE.LineBasicMaterial({
    color: 0x2ad1ff,
    transparent: true,
    opacity: 0.22,
    depthTest: true,
    depthWrite: false
  });
  const glow = new THREE.Line(geometry, glowMaterial);

  const dashedMaterial = new THREE.LineDashedMaterial({
    color: 0x2ad1ff,
    dashSize: 0.05,
    gapSize: 0.03,
    transparent: true,
    opacity: 0.95,
    depthTest: true,
    depthWrite: false
  });
  const dashed = new THREE.Line(geometry, dashedMaterial);
  dashed.computeLineDistances();
  glow.frustumCulled = false;
  dashed.frustumCulled = false;
  glow.renderOrder = 2;
  dashed.renderOrder = 3;

  state.globe.scene.add(glow);
  state.globe.scene.add(dashed);
  state.globe.trackGlow = glow;
  state.globe.trackLine = dashed;
  renderGlobe();
}

async function fetchISSNow() {
  const response = await fetch(ISS_NOW_URL);
  if (!response.ok) {
    throw new Error("ISS API failed");
  }
  const data = await response.json();
  const sample = { ...data, localTime: Date.now() };
  state.issSamples.prev = state.issSamples.next || sample;
  state.issSamples.next = sample;
  state.iss = sample;
  state.trail.push({ latitude: sample.latitude, longitude: sample.longitude });
  if (state.trail.length > 240) {
    state.trail.splice(0, state.trail.length - 240);
  }
  updateISSMarker();
  updateTrackLine();
  setStatus();
}

function buildTimestamps(hours, stepSeconds, maxPoints = 360) {
  const safeHours = Number.isFinite(hours) && hours > 0 ? hours : 6;
  let safeStep = Number.isFinite(stepSeconds) && stepSeconds > 0 ? stepSeconds : 60;
  const totalSeconds = safeHours * 3600;
  const minStep = Math.max(30, Math.ceil(totalSeconds / maxPoints));
  if (safeStep < minStep) safeStep = minStep;

  const now = Math.floor(Date.now() / 1000);
  const end = now + totalSeconds;
  const stamps = [];
  for (let t = now; t <= end; t += safeStep) {
    stamps.push(t);
  }
  return stamps;
}

async function ensureTLE() {
  const now = Date.now();
  if (state.tle && now - state.tleUpdated < 6 * 3600 * 1000) {
    return state.tle;
  }
  const response = await fetch(ISS_TLE_URL);
  if (!response.ok) {
    throw new Error("TLE API failed");
  }
  const data = await response.json();
  if (!window.satellite || !data.line1 || !data.line2) {
    throw new Error("TLE parsing unavailable");
  }
  const satrec = window.satellite.twoline2satrec(data.line1, data.line2);
  state.tle = { ...data, satrec };
  state.tleUpdated = now;
  return state.tle;
}

function buildTrackFromTLE(satrec, timestamps) {
  const track = [];
  timestamps.forEach((ts) => {
    const date = new Date(ts * 1000);
    const pv = window.satellite.propagate(satrec, date);
    if (!pv.position) return;
    const gmst = window.satellite.gstime(date);
    const geodetic = window.satellite.eciToGeodetic(pv.position, gmst);
    const latitude = window.satellite.degreesLat(geodetic.latitude);
    const longitude = window.satellite.degreesLong(geodetic.longitude);
    const altitude = geodetic.height;
    let velocity;
    if (pv.velocity) {
      const v = pv.velocity;
      velocity = Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) * 3600;
    }
    track.push({ timestamp: ts, latitude, longitude, altitude, velocity });
  });
  return track;
}

async function fetchISSTrack(hours = 6, stepSeconds = 60) {
  const timestamps = buildTimestamps(hours, stepSeconds, 360);
  if (!timestamps.length) {
    state.trackData = [];
    updateTrackLine();
    return [];
  }

  if (window.satellite) {
    try {
      const tle = await ensureTLE();
      const track = buildTrackFromTLE(tle.satrec, timestamps);
      state.trackData = track;
      updateTrackLine();
      return track;
    } catch (error) {
      console.warn("TLE track failed, falling back to positions API.", error);
    }
  }

  const limitedTimestamps = timestamps.slice(0, 10);
  const response = await fetch(`${ISS_POS_URL}${limitedTimestamps.join(",")}`);
  if (!response.ok) {
    throw new Error("ISS track API failed");
  }
  const data = await response.json();
  state.trackData = data;
  updateTrackLine();
  return data;
}

async function fetchISSForecast(days = FORECAST_DAYS, stepSeconds = 120) {
  if (!window.satellite) return [];
  try {
    const tle = await ensureTLE();
    const timestamps = buildTimestamps(days * 24, stepSeconds, 6000);
    return buildTrackFromTLE(tle.satrec, timestamps);
  } catch (error) {
    console.warn("Forecast generation failed.", error);
    return [];
  }
}

async function refinePasses(passes, stepSeconds = 10) {
  if (!window.satellite || !state.user || !passes.length) return passes;
  try {
    const tle = await ensureTLE();
    const refined = [];
    for (const pass of passes) {
      const stamps = [];
      for (let t = pass.start; t <= pass.end; t += stepSeconds) {
        stamps.push(t);
      }
      const track = buildTrackFromTLE(tle.satrec, stamps);
      const observer = ecefFromLatLon(state.user.lat, state.user.lon, 0);
      const points = track.map((p) => {
        const sat = ecefFromLatLon(p.latitude, p.longitude, p.altitude || 0);
        const look = topocentricAzEl(observer, sat);
        return { ...p, ...look };
      });

      const above = points.filter((pt) => pt.elevation > 0);
      if (!above.length) {
        refined.push(pass);
        continue;
      }
      const first = above[0];
      const last = above[above.length - 1];
      const peak = above.reduce((a, b) => (b.elevation > a.elevation ? b : a), above[0]);
      const sunAlt = SunCalc.getPosition(new Date(peak.timestamp * 1000), state.user.lat, state.user.lon).altitude * 180 / Math.PI;
      const night = sunAlt < -6;
      const durationMin = Math.max(1, Math.round((last.timestamp - first.timestamp) / 60));

      refined.push({
        ...pass,
        start: first.timestamp,
        end: last.timestamp,
        duration: durationMin,
        maxEl: peak.elevation,
        peakPoint: peak,
        night,
        visible: night && peak.elevation > 20 && durationMin >= 2,
        points
      });
    }
    return refined;
  } catch (error) {
    console.warn("Pass refinement failed.", error);
    return passes;
  }
}

function toRadians(deg) {
  return deg * Math.PI / 180;
}

function toDegrees(rad) {
  return rad * 180 / Math.PI;
}

function ecefFromLatLon(lat, lon, altKm) {
  const a = 6378.137;
  const e2 = 0.00669437999014;
  const latRad = toRadians(lat);
  const lonRad = toRadians(lon);
  const sinLat = Math.sin(latRad);
  const cosLat = Math.cos(latRad);
  const sinLon = Math.sin(lonRad);
  const cosLon = Math.cos(lonRad);
  const N = a / Math.sqrt(1 - e2 * sinLat * sinLat);
  const x = (N + altKm) * cosLat * cosLon;
  const y = (N + altKm) * cosLat * sinLon;
  const z = (N * (1 - e2) + altKm) * sinLat;
  return { x, y, z, sinLat, cosLat, sinLon, cosLon };
}

function topocentricAzEl(observer, satellite) {
  const rx = satellite.x - observer.x;
  const ry = satellite.y - observer.y;
  const rz = satellite.z - observer.z;

  const east = -observer.sinLon * rx + observer.cosLon * ry;
  const north = -observer.sinLat * observer.cosLon * rx - observer.sinLat * observer.sinLon * ry + observer.cosLat * rz;
  const up = observer.cosLat * observer.cosLon * rx + observer.cosLat * observer.sinLon * ry + observer.sinLat * rz;

  const az = Math.atan2(east, north);
  const el = Math.atan2(up, Math.sqrt(east * east + north * north));
  return { azimuth: (toDegrees(az) + 360) % 360, elevation: toDegrees(el) };
}

function computePasses(samples) {
  if (!state.user) return [];
  const observer = ecefFromLatLon(state.user.lat, state.user.lon, 0);
  const enriched = samples.map((p) => {
    const sat = ecefFromLatLon(p.latitude, p.longitude, p.altitude || 0);
    const look = topocentricAzEl(observer, sat);
    return { ...p, ...look };
  });

  const passes = [];
  let current = null;

  for (const point of enriched) {
    if (point.elevation > 0) {
      if (!current) {
        current = { start: point.timestamp, end: point.timestamp, points: [point], maxEl: point.elevation };
      } else {
        current.end = point.timestamp;
        current.points.push(point);
        current.maxEl = Math.max(current.maxEl, point.elevation);
      }
    } else if (current) {
      passes.push(current);
      current = null;
    }
  }
  if (current) passes.push(current);

  return passes.map((pass) => {
    const peak = pass.points.reduce((a, b) => (b.elevation > a.elevation ? b : a), pass.points[0]);
    const sunAlt = SunCalc.getPosition(new Date(peak.timestamp * 1000), state.user.lat, state.user.lon).altitude * 180 / Math.PI;
    const night = sunAlt < -6;
    const durationMin = Math.max(1, Math.round((pass.end - pass.start) / 60));
    return {
      start: pass.start,
      end: pass.end,
      duration: durationMin,
      maxEl: peak.elevation,
      peakPoint: peak,
      night,
      visible: night && peak.elevation > 20 && durationMin >= 2,
      points: pass.points
    };
  });
}

function renderPassList() {
  passList.innerHTML = "";
  if (!state.user) {
    passList.innerHTML = `
      <div class="pass-item">
        <div>
          <p class="pass-title">Waiting for location…</p>
          <div class="pass-meta">Enable geolocation to calculate visible passes</div>
        </div>
        <span class="badge daylight">Standby</span>
      </div>
    `;
    return;
  }
  if (!state.goodPasses.length) {
    passList.innerHTML = `
      <div class="pass-item">
        <div>
          <p class="pass-title">No visible passes in the next ${FORECAST_DAYS} days</p>
          <div class="pass-meta">Try another location, then check again tonight.</div>
        </div>
        <span class="badge low">None</span>
      </div>
    `;
    return;
  }

  const bestPass = getBestPass(state.goodPasses);
  const previewKey = state.preview.active && state.preview.mode === "pass" && state.preview.pass
    ? passKey(state.preview.pass)
    : null;
  const compactMobile = isCompactMobileLayout();
  state.goodPasses.slice(0, 14).forEach((pass) => {
    const isBest = bestPass && pass.start === bestPass.start && pass.end === bestPass.end;
    const isPreview = previewKey && passKey(pass) === previewKey;
    const item = document.createElement("div");
    item.className = `pass-item clickable${isBest ? " best" : ""}${isPreview ? " preview" : ""}${compactMobile ? " compact-mobile" : ""}`;
    const badgeDescriptors = [];
    if (isBest) badgeDescriptors.push({ className: "best", label: "Best", priority: 1 });
    if (pass.alignmentEvent) badgeDescriptors.push({ className: "alignment", label: "Alignment", priority: 2 });
    const badgeSpansCompact = renderBadgeSpans(badgeDescriptors, true);
    const badgeSpansDesktop = renderBadgeSpans(badgeDescriptors, false);
    if (compactMobile) {
      const moonPct = Number.isFinite(pass.moonPhase?.illuminationPct) ? `${pass.moonPhase.illuminationPct}%` : "--";
      const compactMoon = pass.moonPhase
        ? `${pass.moonPhase.icon} ${pass.moonPhase.name}`
        : "Moon phase unavailable";
      item.innerHTML = `
        <div class="compact-head">
          <p class="compact-title compact-title-pass">${formatDateTime(new Date(pass.start * 1000))}</p>
          <div class="compact-actions">
            <button class="share-chip" type="button">Share</button>
            ${badgeSpansCompact ? `<div class="compact-badges">${badgeSpansCompact}</div>` : ""}
          </div>
        </div>
        <div class="compact-sub">${describePassQuality(pass)}</div>
        <div class="compact-grid">
          <div class="compact-cell"><p class="compact-k">Max El</p><p class="compact-v">${pass.maxEl.toFixed(0)}°</p></div>
          <div class="compact-cell"><p class="compact-k">Duration</p><p class="compact-v">${pass.duration} min</p></div>
          <div class="compact-cell"><p class="compact-k">Moon %</p><p class="compact-v">${moonPct}</p></div>
        </div>
        <div class="compact-secondary">${compactMoon}</div>
      `;
    } else {
      const badgeColumn = `
        <div class="badge-row">
          <button class="share-chip" type="button">Share</button>
          ${badgeSpansDesktop}
        </div>
      `;
      const moonContextLine = formatCombinedMoonContext({
        moonSummary: pass.moonSummary,
        moonPhaseSummary: pass.moonPhaseSummary,
        moonlightSummary: pass.moonlightSummary
      });
      const highlights = [
        moonContextLine ? `<div class="pass-meta moon-phase">${moonContextLine}</div>` : ""
      ].join("");
      item.innerHTML = `
        <div>
          <p class="pass-title">${formatDateTime(new Date(pass.start * 1000))}</p>
          <div class="pass-meta">Visible ${pass.duration} min • Max elevation ${pass.maxEl.toFixed(0)}°</div>
          ${highlights}
        </div>
        ${badgeColumn}
      `;
    }
    const shareButton = item.querySelector(".share-chip");
    if (shareButton) {
      shareButton.addEventListener("click", (clickEvent) => {
        clickEvent.stopPropagation();
        sharePass(pass);
      });
    }
    item.addEventListener("click", () => setPreviewPass(pass));
    passList.appendChild(item);
  });
}

function updateNextVisible() {
  const now = Date.now() / 1000;
  const upcoming = state.goodPasses.filter((p) => p.end > now + 60);
  state.nextVisible = upcoming[0] || null;
}

function resolveSkyViewState(nowTs = Math.floor(Date.now() / 1000)) {
  const nowDate = new Date(nowTs * 1000);
  const emptyState = {
    mode: "live-now",
    contextDate: nowDate,
    skyPass: null,
    skyEvent: null,
    bannerText: "",
    showExit: false
  };
  if (!state.user) return emptyState;

  if (state.preview.active && state.preview.mode === "pass" && state.preview.pass) {
    return {
      mode: "manual-pass",
      contextDate: new Date((state.preview.pass.peakPoint?.timestamp || state.preview.pass.start) * 1000),
      skyPass: state.preview.pass,
      skyEvent: null,
      bannerText: `Previewing pass ${formatDateTime(new Date(state.preview.pass.start * 1000))}`,
      showExit: true
    };
  }

  if (state.preview.active && state.preview.mode === "event" && state.preview.skyEvent) {
    const previewTs = getEventFocusTs(state.preview.skyEvent);
    return {
      mode: "manual-event",
      contextDate: new Date(previewTs * 1000),
      skyPass: null,
      skyEvent: state.preview.skyEvent,
      bannerText: `Previewing sky ${formatDateTime(new Date(previewTs * 1000))}`,
      showExit: true
    };
  }

  const snapshot = state.tonightSnapshot || buildTonightSnapshot(nowDate);
  const activePass = snapshot.issTonight?.status === "active" ? snapshot.issTonight.pass : null;
  if (activePass) {
    return {
      mode: "active-pass",
      contextDate: nowDate,
      skyPass: activePass,
      skyEvent: null,
      bannerText: "",
      showExit: false
    };
  }

  const activeEvent = snapshot.skyTonight?.status === "active" ? snapshot.skyTonight.event : null;
  if (activeEvent) {
    return {
      mode: "active-event",
      contextDate: nowDate,
      skyPass: null,
      skyEvent: activeEvent,
      bannerText: "",
      showExit: false
    };
  }

  const upcomingPass = snapshot.issTonight?.status === "upcoming" ? snapshot.issTonight.pass : null;
  if (upcomingPass) {
    return {
      mode: "auto-pass",
      contextDate: new Date((upcomingPass.peakPoint?.timestamp || upcomingPass.start) * 1000),
      skyPass: upcomingPass,
      skyEvent: null,
      bannerText: `Tonight preview: ISS pass ${formatPreviewMoment(upcomingPass.start)}`,
      showExit: false
    };
  }

  const upcomingEvent = snapshot.skyTonight?.status === "upcoming" ? snapshot.skyTonight.event : null;
  if (upcomingEvent) {
    const focusTs = getEventFocusTs(upcomingEvent);
    return {
      mode: "auto-event",
      contextDate: new Date(focusTs * 1000),
      skyPass: null,
      skyEvent: upcomingEvent,
      bannerText: `Tonight preview: ${getSkyEventDisplayLabel(upcomingEvent)} ${formatPreviewMoment(focusTs)}`,
      showExit: false
    };
  }

  return emptyState;
}

function updatePreviewBanner(viewState) {
  if (!previewBanner || !previewText || !previewExitButton) return;
  if (!skyViewEl.classList.contains("active")) {
    previewExitButton.hidden = true;
    previewBanner.hidden = true;
    return;
  }
  previewText.textContent = viewState.bannerText || "";
  previewExitButton.hidden = !viewState.showExit;
  previewBanner.hidden = !viewState.bannerText;
}

function getBestPass(passes) {
  if (!passes.length) return null;
  return passes.reduce((best, pass) => {
    const skyScore = (entry) => (entry.topTargets?.length || 0) + (entry.alignmentEvent ? 1 : 0) + (entry.moonSummary ? 0.5 : 0);
    if (pass.maxEl > best.maxEl) return pass;
    if (pass.maxEl === best.maxEl && pass.duration > best.duration) return pass;
    if (pass.maxEl === best.maxEl && pass.duration === best.duration && skyScore(pass) > skyScore(best)) return pass;
    if (pass.maxEl === best.maxEl && pass.duration === best.duration && skyScore(pass) === skyScore(best) && pass.start < best.start) return pass;
    return best;
  }, passes[0]);
}

function setPreviewPass(pass) {
  if (!pass) return;
  state.preview.active = true;
  state.preview.mode = "pass";
  state.preview.pass = pass;
  state.preview.skyEvent = null;
  renderPassList();
  renderSkyEventsList();
  setActiveView("sky");
  updateSkyCanvas();
}

function setSkyEventPreview(event) {
  if (!event) return;
  state.preview.active = true;
  state.preview.mode = "event";
  state.preview.pass = null;
  state.preview.skyEvent = event;
  renderPassList();
  renderSkyEventsList();
  setActiveView("sky");
  updateSkyCanvas();
}

function clearPreview() {
  state.preview.active = false;
  state.preview.mode = "live";
  state.preview.pass = null;
  state.preview.skyEvent = null;
  renderPassList();
  renderSkyEventsList();
  updateSkyCanvas();
}

function updateSkyCanvas() {
  const ctx = skyCanvas.getContext("2d");
  const width = skyCanvas.clientWidth;
  const height = skyCanvas.clientHeight;
  ctx.clearRect(0, 0, width, height);

  const cx = width / 2;
  const cy = height / 2;
  const radius = Math.min(width, height) * 0.42 * state.sky.zoom;

  const gradient = ctx.createRadialGradient(cx, cy, radius * 0.1, cx, cy, radius);
  gradient.addColorStop(0, "rgba(16, 32, 64, 0.95)");
  gradient.addColorStop(1, "rgba(2, 6, 12, 0.95)");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);

  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(state.sky.rotation);

  const toXY = (azimuth, elevation) => {
    const clampedElevation = Math.max(0, Math.min(90, elevation));
    const r = radius * (1 - clampedElevation / 90);
    const angle = toRadians(azimuth);
    return {
      x: Math.sin(angle) * r,
      y: -Math.cos(angle) * r
    };
  };

  for (const star of state.sky.stars) {
    const point = toXY(star.az, star.el);
    ctx.fillStyle = star.bright;
    ctx.beginPath();
    ctx.arc(point.x, point.y, star.size, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.strokeStyle = "rgba(120, 150, 200, 0.3)";
  ctx.lineWidth = 1;
  [30, 60].forEach((alt) => {
    const r = radius * (1 - alt / 90);
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.stroke();
  });

  ctx.beginPath();
  ctx.arc(0, 0, radius, 0, Math.PI * 2);
  ctx.strokeStyle = "rgba(42, 209, 255, 0.6)";
  ctx.stroke();

  const directions = [
    { label: "N", az: 0 },
    { label: "E", az: 90 },
    { label: "S", az: 180 },
    { label: "W", az: 270 }
  ];
  ctx.fillStyle = "rgba(230, 237, 246, 0.7)";
  ctx.font = "12px IBM Plex Mono";
  directions.forEach((d) => {
    const r = radius + 12;
    const angle = toRadians(d.az);
    ctx.fillText(d.label, Math.sin(angle) * r - 4, -Math.cos(angle) * r + 4);
  });

  const viewState = resolveSkyViewState();
  const skyPass = viewState.skyPass;
  const highlightedEvent = viewState.skyEvent;
  const contextDate = viewState.contextDate;
  updatePreviewBanner(viewState);

  if (state.user) {
    const skyContext = getSkyContextAt(contextDate, state.user.lat, state.user.lon);
    const observer = window.Astronomy?.Observer
      ? new window.Astronomy.Observer(state.user.lat, state.user.lon, 0)
      : null;
    const constellationGuides = getVisibleConstellationGuides(contextDate, state.user.lat, state.user.lon, skyContext);
    const drawableSkyGuideItems = observer
      ? state.skyGuide.filter((item) => item.kind !== "constellation").slice(0, 4)
      : [];

    if (skyContext.darkEnough && (constellationGuides.length || skyContext.visiblePlanets.length || skyContext.moon || drawableSkyGuideItems.length)) {
      const labelBoxes = [];
      const safePadding = 12;
      const hasOverlap = (candidate) => labelBoxes.some((box) => (
        candidate.x < box.x + box.width &&
        candidate.x + candidate.width > box.x &&
        candidate.y < box.y + box.height &&
        candidate.y + candidate.height > box.y
      ));
      const isWithinSafeBounds = (candidate, padding = safePadding) => (
        candidate.x >= -cx + padding &&
        candidate.x + candidate.width <= width - cx - padding &&
        candidate.y >= -cy + padding &&
        candidate.y + candidate.height <= height - cy - padding
      );
      const buildDefaultLabelCandidates = (anchor, boxWidth, boxHeight) => ([
        { x: anchor.x + 8, y: anchor.y - 14, width: boxWidth, height: boxHeight },
        { x: anchor.x + 8, y: anchor.y + 4, width: boxWidth, height: boxHeight },
        { x: anchor.x - boxWidth - 8, y: anchor.y - 14, width: boxWidth, height: boxHeight },
        { x: anchor.x - boxWidth - 8, y: anchor.y + 4, width: boxWidth, height: boxHeight },
        { x: anchor.x - boxWidth / 2, y: anchor.y - 20, width: boxWidth, height: boxHeight },
        { x: anchor.x - boxWidth / 2, y: anchor.y + 10, width: boxWidth, height: boxHeight }
      ]);
      const buildConstellationLabelCandidates = (anchor, boxWidth, boxHeight, options = {}) => {
        const offset = options.labelOffsetPx || { x: 10, y: -14 };
        const offsetX = Math.abs(offset.x ?? 10);
        const offsetY = Math.abs(offset.y ?? 14);
        const preferredSide = (offset.x ?? 10) >= 0 ? "right" : "left";
        const oppositeSide = preferredSide === "right" ? "left" : "right";
        const preferredVertical = (offset.y ?? -14) >= 0 ? "below" : "above";
        const oppositeVertical = preferredVertical === "above" ? "below" : "above";
        const resolveX = (side) => side === "right" ? anchor.x + offsetX : anchor.x - boxWidth - offsetX;
        const resolveY = (vertical) => vertical === "below" ? anchor.y + offsetY : anchor.y - boxHeight - offsetY;
        return [
          { x: resolveX(preferredSide), y: resolveY(preferredVertical), width: boxWidth, height: boxHeight },
          { x: resolveX(preferredSide), y: resolveY(oppositeVertical), width: boxWidth, height: boxHeight },
          { x: resolveX(oppositeSide), y: resolveY(preferredVertical), width: boxWidth, height: boxHeight },
          { x: resolveX(oppositeSide), y: resolveY(oppositeVertical), width: boxWidth, height: boxHeight },
          { x: anchor.x - boxWidth / 2, y: resolveY(preferredVertical), width: boxWidth, height: boxHeight },
          { x: anchor.x - boxWidth / 2, y: resolveY(oppositeVertical), width: boxWidth, height: boxHeight }
        ];
      };
      const placeLabel = (text, anchor, options = {}) => {
        const boxWidth = ctx.measureText(text).width + (options.horizontalPadding ?? 6);
        const boxHeight = options.height ?? 14;
        const candidates = (options.candidatesBuilder || buildDefaultLabelCandidates)(anchor, boxWidth, boxHeight, options);
        const choice = candidates.find((candidate) => (
          (!options.requireSafeBounds || isWithinSafeBounds(candidate, options.safePadding))
          && !hasOverlap(candidate)
        )) || (options.allowOverlapFallback === false ? null : candidates[0]);
        if (!choice) return null;
        labelBoxes.push(choice);
        return choice;
      };
      const highlightedBodies = highlightedEvent?.bodies ? new Set(highlightedEvent.bodies) : null;
      const pendingConstellationLabels = [];
      const drawTarget = (target, size) => {
        const point = toXY(target.azimuth, target.elevation);
        const isHighlighted = highlightedBodies ? highlightedBodies.has(target.body) : false;
        const dotSize = isHighlighted ? size + 1.25 : size;
        ctx.fillStyle = target.color;
        ctx.strokeStyle = "rgba(7, 14, 28, 0.92)";
        ctx.lineWidth = 1.4;
        ctx.beginPath();
        ctx.arc(point.x, point.y, dotSize, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();

        if (target.bright || target.body === "Moon" || isHighlighted) {
          ctx.strokeStyle = `${target.color}88`;
          ctx.lineWidth = isHighlighted ? 1.4 : 1;
          ctx.beginPath();
          ctx.arc(point.x, point.y, dotSize + (isHighlighted ? 4.2 : 2.8), 0, Math.PI * 2);
          ctx.stroke();
        }

        const label = `${target.body} ${Math.round(target.elevation)}°`;
        const box = placeLabel(label, point);
        ctx.fillStyle = "rgba(4, 10, 20, 0.72)";
        ctx.strokeStyle = "rgba(102, 132, 173, 0.35)";
        ctx.lineWidth = 1;
        ctx.fillRect(box.x - 2, box.y - 1, box.width + 4, box.height + 2);
        ctx.strokeRect(box.x - 2, box.y - 1, box.width + 4, box.height + 2);
        ctx.fillStyle = target.color;
        ctx.fillText(label, box.x + 3, box.y + 10.5);
      };

      if (constellationGuides.length) {
        constellationGuides.forEach((guide) => {
          const pointsById = new Map(
            guide.projectedStars.map((star) => [
              star.id,
              {
                x: toXY(star.azimuth, star.elevation).x,
                y: toXY(star.azimuth, star.elevation).y
              }
            ])
          );

          ctx.strokeStyle = "rgba(180,220,245,0.18)";
          ctx.lineWidth = 0.85;
          guide.visibleSegments.forEach(({ from, to }) => {
            const fromPoint = pointsById.get(from.id);
            const toPoint = pointsById.get(to.id);
            if (!fromPoint || !toPoint) return;
            ctx.beginPath();
            ctx.moveTo(fromPoint.x, fromPoint.y);
            ctx.lineTo(toPoint.x, toPoint.y);
            ctx.stroke();
          });

          guide.visibleStars.forEach((star) => {
            const point = pointsById.get(star.id);
            if (!point) return;
            const emphasized = star.anchor || star.id === guide.labelStarId || star.id === guide.anchorGuideStarId;
            ctx.fillStyle = emphasized ? "rgba(220,240,255,0.30)" : "rgba(205,230,250,0.20)";
            ctx.beginPath();
            ctx.arc(point.x, point.y, emphasized ? 1.8 : 1.2, 0, Math.PI * 2);
            ctx.fill();
          });

          const labelPoint = pointsById.get(guide.labelStar.id);
          if (labelPoint) {
            pendingConstellationLabels.push({
              label: guide.name,
              point: labelPoint,
              labelOffsetPx: guide.labelOffsetPx
            });
          }
        });
      }

      ctx.font = "11px IBM Plex Mono";
      skyContext.visiblePlanets.forEach((target) => drawTarget(target, 3.1));
      if (skyContext.moon) {
        drawTarget(skyContext.moon, 3.6);
      }

      drawableSkyGuideItems.forEach((item) => {
        if (!Number.isFinite(item.raHours) || !Number.isFinite(item.decDeg)) return;
        const obs = getEquatorialObservation({ raHours: item.raHours, decDeg: item.decDeg }, contextDate, observer);
        if (!obs || obs.elevation < 10) return;
        const point = toXY(obs.azimuth, obs.elevation);
        ctx.strokeStyle = item.tier === "binoculars" ? "rgba(255, 196, 130, 0.92)" : "rgba(165, 240, 255, 0.92)";
        ctx.lineWidth = 1.4;
        ctx.beginPath();
        ctx.moveTo(point.x - 4, point.y);
        ctx.lineTo(point.x + 4, point.y);
        ctx.moveTo(point.x, point.y - 4);
        ctx.lineTo(point.x, point.y + 4);
        ctx.stroke();

        const label = item.kind === "star" ? item.title : `${item.title}`;
        const box = placeLabel(label, point);
        ctx.fillStyle = "rgba(6, 12, 22, 0.7)";
        ctx.fillRect(box.x - 2, box.y - 1, box.width + 4, box.height + 2);
        ctx.strokeStyle = item.tier === "binoculars" ? "rgba(255, 196, 130, 0.4)" : "rgba(126, 217, 255, 0.35)";
        ctx.strokeRect(box.x - 2, box.y - 1, box.width + 4, box.height + 2);
        ctx.fillStyle = item.tier === "binoculars" ? "#ffd9aa" : "#b8f9ff";
        ctx.fillText(label, box.x + 3, box.y + 10.5);
      });

      if (pendingConstellationLabels.length) {
        ctx.font = "10px IBM Plex Mono";
        ctx.fillStyle = "rgba(220,240,255,0.38)";
        pendingConstellationLabels.forEach((label) => {
          const box = placeLabel(label.label, label.point, {
            allowOverlapFallback: false,
            requireSafeBounds: true,
            safePadding,
            height: 12,
            horizontalPadding: 2,
            labelOffsetPx: label.labelOffsetPx,
            candidatesBuilder: buildConstellationLabelCandidates
          });
          if (!box) return;
          ctx.fillText(label.label, box.x, box.y + 9.5);
        });
      }
    }
  }

  if (skyPass && skyPass.points) {
    ctx.strokeStyle = "rgba(23, 241, 177, 0.9)";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    skyPass.points.forEach((pt, idx) => {
      const { x, y } = toXY(pt.azimuth, pt.elevation);
      if (idx === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();

    if (skyPass.points.length >= 2) {
      const last = skyPass.points[skyPass.points.length - 1];
      const end = toXY(last.azimuth, last.elevation);
      let start = null;
      for (let i = skyPass.points.length - 2; i >= 0; i--) {
        const candidate = toXY(skyPass.points[i].azimuth, skyPass.points[i].elevation);
        const dx = end.x - candidate.x;
        const dy = end.y - candidate.y;
        if (dx * dx + dy * dy > 1) {
          start = candidate;
          break;
        }
      }

      if (start) {
        const dx = end.x - start.x;
        const dy = end.y - start.y;
        const len = Math.sqrt(dx * dx + dy * dy) || 1;
        const ux = dx / len;
        const uy = dy / len;
        const arrowSize = 14;
        const leftX = end.x - ux * arrowSize - uy * (arrowSize * 0.6);
        const leftY = end.y - uy * arrowSize + ux * (arrowSize * 0.6);
        const rightX = end.x - ux * arrowSize + uy * (arrowSize * 0.6);
        const rightY = end.y - uy * arrowSize - ux * (arrowSize * 0.6);

        ctx.fillStyle = "rgba(23, 241, 177, 0.95)";
        ctx.strokeStyle = "rgba(10, 14, 24, 0.9)";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(end.x, end.y);
        ctx.lineTo(leftX, leftY);
        ctx.lineTo(rightX, rightY);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
      }
    }
  }

  if (viewState.mode === "manual-pass" && skyPass?.peakPoint) {
    const pt = skyPass.peakPoint;
    const { x, y } = toXY(pt.azimuth, pt.elevation);
    ctx.fillStyle = "rgba(155, 92, 255, 0.95)";
    ctx.beginPath();
    ctx.arc(x, y, 5, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.restore();
}

function resizeSky() {
  const rect = skyViewEl.getBoundingClientRect();
  const ratio = window.devicePixelRatio || 1;
  skyCanvas.width = rect.width * ratio;
  skyCanvas.height = rect.height * ratio;
  const ctx = skyCanvas.getContext("2d");
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.scale(ratio, ratio);
  updateSkyCanvas();
}

function initSky() {
  state.sky.stars = Array.from({ length: 140 }).map(() => ({
    az: Math.random() * 360,
    el: Math.random() * 90,
    size: Math.random() * 1.5 + 0.4,
    bright: `rgba(255, 255, 255, ${Math.random() * 0.8 + 0.1})`
  }));

  const handlePointer = (event) => {
    if (!state.sky.dragging) return;
    const dx = event.clientX - state.sky.dragStart.x;
    state.sky.rotation = state.sky.dragStart.rotation + dx * 0.01;
    updateSkyCanvas();
  };

  skyCanvas.addEventListener("pointerdown", (event) => {
    state.sky.dragging = true;
    state.sky.dragStart = { x: event.clientX, rotation: state.sky.rotation };
    skyCanvas.setPointerCapture(event.pointerId);
  });

  skyCanvas.addEventListener("pointermove", handlePointer);

  skyCanvas.addEventListener("pointerup", (event) => {
    state.sky.dragging = false;
    skyCanvas.releasePointerCapture(event.pointerId);
  });

  skyCanvas.addEventListener("wheel", (event) => {
    event.preventDefault();
    const delta = Math.sign(event.deltaY) * 0.05;
    state.sky.zoom = Math.min(1.4, Math.max(0.8, state.sky.zoom - delta));
    updateSkyCanvas();
  }, { passive: false });

  window.addEventListener("resize", resizeSky);
  resizeSky();
}

function handleLayoutChange(force = false) {
  updateForecastNoteCopy();
  const compact = isCompactMobileLayout();
  const narrow = isNarrowMobileLayout();
  const changed = force || compact !== state.layout.compactMobile || narrow !== state.layout.narrowMobile;
  state.layout.compactMobile = compact;
  state.layout.narrowMobile = narrow;
  if (changed) {
    renderPassList();
    renderSkyEventsList();
  }
}

async function refreshAll(options = {}) {
  const interactive = Boolean(options.interactive);
  const initialBoot = !state.ui.hasCompletedInitialLoad;
  if (state.ui.refreshPromise) return state.ui.refreshPromise;

  const task = (async () => {
    if (interactive) triggerHaptic("start");
    if (initialBoot) {
      state.ui.bootError = null;
      setBooting(true);
      setBootStage("iss");
    }
    setRefreshingUI(true);
    try {
      state.planetCache.clear();
      state.passSkyHighlights = {};
      state.alignmentEvents = [];
      await fetchISSNow();
      const hoursRaw = Number(document.getElementById("track-hours")?.value ?? 6);
      const hours = Number.isFinite(hoursRaw) ? hoursRaw : 6;
      await fetchISSTrack(hours, 60);
      const forecast = await fetchISSForecast(FORECAST_DAYS, 120);
      state.passes = computePasses(forecast);
      state.passes = await refinePasses(state.passes, 10);
      state.passes = enrichPassesWithSkyContext(state.passes);
      state.goodPasses = state.passes.filter((pass) => pass.visible);
      if (state.user) {
        if (initialBoot) setBootStage("weather");
        try {
          await fetchWeatherForecast(state.user.lat, state.user.lon);
        } catch (error) {
          console.warn("Weather forecast failed.", error);
          state.weather.hourly = [];
          state.weather.error = error.message || "Weather unavailable";
        }
        const now = Math.floor(Date.now() / 1000);
        const end = now + FORECAST_DAYS * 24 * 3600;
        state.meteorEvents = buildMeteorEvents(now, end, state.user.lat, state.user.lon);
        if (initialBoot) setBootStage("sky");
        state.skyEvents = buildSkyEvents(state.user.lat, state.user.lon, state.alignmentEvents);
        state.tonightWindow = getTonightWindow(state.user.lat, state.user.lon, new Date());
        state.skyGuide = buildSkyGuide(state.user.lat, state.user.lon, state.tonightWindow);
      } else {
        if (initialBoot) setBootStage("sky");
        state.weather.hourly = [];
        state.weather.error = null;
        state.meteorEvents = [];
        state.skyEvents = [];
        state.tonightWindow = null;
        state.tonightTimeline = [];
        state.skyGuide = [];
      }
      if (state.preview.active) {
        if (state.preview.mode === "pass") {
          const match = state.goodPasses.find((pass) => pass.start === state.preview.pass?.start && pass.end === state.preview.pass?.end);
          if (match) {
            state.preview.pass = match;
          } else {
            clearPreview();
          }
        } else if (state.preview.mode === "event") {
          const matchEvent = state.skyEvents.find((event) => event.id === state.preview.skyEvent?.id);
          if (matchEvent) {
            state.preview.skyEvent = matchEvent;
          } else {
            clearPreview();
          }
        }
      }
      if (initialBoot) setBootStage("finalizing");
      updateNextVisible();
      updateTonightHighlights();
      renderPassList();
      renderSkyEventsList();
      renderTimeline();
      renderConditionsList();
      updateForecastNoteCopy();
      updateSkyCanvas();
      state.ui.lastRefreshStatus = "success";
      state.ui.lastSuccessfulRefreshAt = Date.now();
      state.ui.lastRefreshLocalDate = getLocalDateKey(state.ui.lastSuccessfulRefreshAt);
      setActionStatus(`Updated ${formatTime(new Date())} local`);
      if (interactive) {
        triggerHaptic("success");
        showToast("Forecast recalculated.");
      }
    } catch (error) {
      console.error(error);
      state.ui.lastRefreshStatus = "error";
      state.ui.bootError = error.message || "Startup calculations failed.";
      updateTonightHighlights();
      renderPassList();
      renderSkyEventsList();
      renderTimeline();
      renderConditionsList();
      setActionStatus("Update failed. Try again.");
      if (interactive || initialBoot) {
        triggerHaptic("error");
        showToast(initialBoot ? "Initial sky calculations failed. Showing available data." : "Recalculation failed. Please try again.", 3400);
      }
    } finally {
      setRefreshingUI(false);
      if (initialBoot) {
        finishInitialBoot();
      }
      state.ui.refreshPromise = null;
    }
  })();

  state.ui.refreshPromise = task;
  return task;
}

function animateISS() {
  const now = Date.now();
  const sample = interpolateSample(state.issSamples.prev, state.issSamples.next, now);
  if (sample) {
    state.iss = sample;
    updateISSMarker();
    if (now - state.anim.lastStatus > 900) {
      setStatus();
      state.anim.lastStatus = now;
    }
    if (globeViewEl.classList.contains("active")) {
      renderGlobe();
    }
    if (skyViewEl.classList.contains("active")) {
      updateSkyCanvas();
    }
  }
  state.anim.rafId = requestAnimationFrame(animateISS);
}

async function setUserLocation(lat, lon, source, persist = true) {
  state.user = {
    lat,
    lon,
    source,
    label: "",
    regionCode: "",
    geocodedAt: 0
  };
  if (persist) {
    saveUserLocation(state.user);
  }
  updateUserMarker();
  setStatus();
  void ensureUserLocationLabel({ persist });
  await refreshAll();
}

locateButton.addEventListener("click", async (event) => {
  const button = event.currentTarget;
  button.disabled = true;
  button.dataset.busy = "true";
  button.classList.add("loading");
  button.setAttribute("aria-label", "Updating location");
  button.setAttribute("title", "Updating location");
  const hiddenText = button.querySelector(".visually-hidden");
  if (hiddenText) hiddenText.textContent = "Updating location";
  triggerHaptic("start");

  let geoError = null;
  try {
    if (navigator.geolocation && window.isSecureContext) {
      try {
        const pos = await requestDeviceLocationWithRetry();
        await setUserLocation(pos.coords.latitude, pos.coords.longitude, "Device location");
        triggerHaptic("success");
        setActionStatus(`Location updated ${formatTime(new Date())} local`);
        showToast("Using precise device location.");
        return;
      } catch (error) {
        geoError = error;
      }
    } else if (!window.isSecureContext) {
      geoError = { code: 0 };
    }

    const approx = await requestApproxLocationFromIp();
    if (approx) {
      await setUserLocation(approx.lat, approx.lon, `${approx.source} (approximate)`);
      const prefix = geoError ? `${geolocationErrorMessage(geoError)} ` : "";
      triggerHaptic("success");
      setActionStatus(`Approximate location set ${formatTime(new Date())} local`);
      showToast(`${prefix}Using approximate IP location.`, 3600);
      return;
    }

    const fallbackHint = state.user
      ? "Keeping your saved location."
      : "Enter coordinates manually.";
    const baseError = geoError
      ? geolocationErrorMessage(geoError)
      : "Location services are unavailable.";
    triggerHaptic("error");
    showToast(`${baseError} ${fallbackHint}`, 4200);
  } finally {
    button.disabled = false;
    delete button.dataset.busy;
    button.classList.remove("loading");
    renderLocationStatus();
  }
});

document.getElementById("apply-coords").addEventListener("click", () => {
  const lat = parseFloat(document.getElementById("lat").value);
  const lon = parseFloat(document.getElementById("lon").value);
  if (Number.isFinite(lat) && Number.isFinite(lon)) {
    triggerHaptic("start");
    setUserLocation(lat, lon, "Manual coordinates").then(() => {
      triggerHaptic("success");
      setActionStatus(`Manual location set ${formatTime(new Date())} local`);
      showToast("Using manual coordinates.");
    }).catch(() => {
      triggerHaptic("error");
      showToast("Could not apply manual coordinates.", 2800);
    });
  } else {
    triggerHaptic("error");
    showToast("Enter valid latitude and longitude.", 2600);
  }
});

document.getElementById("refresh").addEventListener("click", () => refreshAll({ interactive: true }));

if (timelineToggle) {
  timelineToggle.addEventListener("click", () => {
    setTimelineExpanded(!state.ui.timelineExpanded);
  });
}

document.getElementById("track-hours").addEventListener("input", (event) => {
  document.getElementById("track-hours-label").textContent = `${event.target.value} hours of orbit path`;
});

document.getElementById("track-hours").addEventListener("change", () => refreshAll({ interactive: false }));

document.getElementById("preview-exit").addEventListener("click", () => {
  clearPreview();
  setActiveView("sky");
});

document.getElementById("share-tonight-iss").addEventListener("click", () => {
  if (!state.tonight.pass) return;
  sharePass(state.tonight.pass);
});

document.getElementById("share-tonight-sky").addEventListener("click", () => {
  if (!state.tonight.skyEvent) return;
  shareSkyEvent(state.tonight.skyEvent);
});

const infoNoteBindings = [];
function wireInfoNote(buttonId, noteId) {
  const button = document.getElementById(buttonId);
  const note = document.getElementById(noteId);
  if (!button || !note) return;
  infoNoteBindings.push({ button, note });
  button.addEventListener("click", (event) => {
    event.stopPropagation();
    const willOpen = note.hidden;
    infoNoteBindings.forEach((binding) => {
      binding.note.hidden = true;
      binding.button.setAttribute("aria-expanded", "false");
    });
    note.hidden = !willOpen;
    button.setAttribute("aria-expanded", String(willOpen));
  });
}

wireInfoNote("iss-best-info", "iss-best-note");
wireInfoNote("sky-best-info", "sky-best-note");

function closeInfoNotes() {
  infoNoteBindings.forEach((binding) => {
    binding.note.hidden = true;
    binding.button.setAttribute("aria-expanded", "false");
  });
}

document.addEventListener("pointerdown", (event) => {
  if (event.target.closest(".panel-info-wrap")) return;
  closeInfoNotes();
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeInfoNotes();
});

function setActiveView(view) {
  const isMap = view === "map";
  const isGlobe = view === "globe";
  const isSky = view === "sky";

  document.getElementById("btn-map").classList.toggle("active", isMap);
  document.getElementById("btn-globe").classList.toggle("active", isGlobe);
  document.getElementById("btn-sky").classList.toggle("active", isSky);

  mapEl.classList.toggle("active", isMap);
  globeViewEl.classList.toggle("active", isGlobe);
  skyViewEl.classList.toggle("active", isSky);

  if (isMap && state.map) {
    state.map.invalidateSize();
    syncMapNoWrapZoomConstraints(true);
  }
  if (isGlobe) {
    resizeGlobe();
    renderGlobe();
  }
  if (isSky) {
    updateSkyCanvas();
  } else if (previewBanner) {
    previewExitButton.hidden = true;
    previewBanner.hidden = true;
  }
}

document.getElementById("btn-map").addEventListener("click", () => setActiveView("map"));
document.getElementById("btn-globe").addEventListener("click", () => setActiveView("globe"));
document.getElementById("btn-sky").addEventListener("click", () => setActiveView("sky"));

let layoutQueued = false;
window.addEventListener("resize", () => {
  if (layoutQueued) return;
  layoutQueued = true;
  requestAnimationFrame(() => {
    layoutQueued = false;
    handleLayoutChange();
  });
});

window.addEventListener("pageshow", () => {
  maybeAutoRefresh();
});

window.addEventListener("focus", () => {
  maybeAutoRefresh();
});

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") {
    maybeAutoRefresh();
  }
});

initMap();
initMapResizing();
initGlobe();
initSky();
handleLayoutChange(true);
setBootStage(state.ui.bootStage);
setBooting(true);
setTimelineExpanded(false);
clearPreview();
registerGestureBlocker(mapEl, () => mapEl.classList.contains("active"));
registerGestureBlocker(globeEl, () => globeViewEl.classList.contains("active"));
registerGestureBlocker(skyCanvas, () => skyViewEl.classList.contains("active"));
loadStoredLocation();
refreshAll();
animateISS();
setInterval(fetchISSNow, 6000);
