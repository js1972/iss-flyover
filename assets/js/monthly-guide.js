import { MONTHLY_SKY_GUIDE_INDEX_URL, getMonthlySkyGuide } from "./data/monthly-highlights.js?v=2026.09.03-sky-tonight.1";

const DAY_MS = 24 * 60 * 60 * 1000;

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function parseLocalDate(dateString, hour = 12) {
  const [year, month, day] = dateString.split("-").map(Number);
  return new Date(year, month - 1, day, hour, 0, 0, 0);
}

function startOfLocalDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function addDays(date, amount) {
  const next = new Date(date);
  next.setDate(next.getDate() + amount);
  return next;
}

function azimuthToCompass(azimuth) {
  const directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
  const normalized = ((azimuth % 360) + 360) % 360;
  return directions[Math.round(normalized / 22.5) % directions.length];
}

function getDateStatus(highlight, referenceDate) {
  const today = startOfLocalDay(referenceDate);
  const start = startOfLocalDay(parseLocalDate(highlight.startDate));
  const end = startOfLocalDay(parseLocalDate(highlight.endDate));
  const daysUntil = Math.round((start - today) / DAY_MS);

  if (today >= start && today <= end) {
    return {
      className: "current",
      label: highlight.startDate === highlight.endDate ? "Tonight" : "Happening now"
    };
  }
  if (today > end) return { className: "past", label: "Passed" };
  if (daysUntil <= 7) return { className: "soon", label: "Coming up" };
  return { className: "upcoming", label: "Later" };
}

function getDisplayTitle(highlight, latitude) {
  if (!Number.isFinite(latitude)) return highlight.title;
  if (latitude < 0 && highlight.southernTitle) return highlight.southernTitle;
  if (latitude >= 0 && highlight.northernTitle) return highlight.northernTitle;
  return highlight.title;
}

function getTargetObservation(target, date, observer, astronomy) {
  try {
    if (target.type === "fixed") {
      const horizontal = astronomy.Horizon(date, observer, target.raHours, target.decDeg, "normal");
      return {
        name: target.name,
        elevation: horizontal.altitude,
        azimuth: (horizontal.azimuth + 360) % 360
      };
    }

    const equatorial = astronomy.Equator(target.name, date, observer, true, true);
    const horizontal = astronomy.Horizon(date, observer, equatorial.ra, equatorial.dec, "normal");
    return {
      name: target.name,
      elevation: horizontal.altitude,
      azimuth: (horizontal.azimuth + 360) % 360
    };
  } catch (error) {
    console.warn(`Monthly guide target failed for ${target.name}.`, error);
    return null;
  }
}

function getSamplingWindow(highlight, date, latitude, longitude, sunCalc) {
  const times = sunCalc.getTimes(date, latitude, longitude);
  const nextTimes = sunCalc.getTimes(addDays(date, 1), latitude, longitude);

  if (highlight.timePreference === "dawn") {
    return {
      start: new Date(times.sunrise.getTime() - 3 * 60 * 60 * 1000),
      end: times.sunrise
    };
  }

  if (highlight.timePreference === "night") {
    return { start: times.sunset, end: nextTimes.sunrise };
  }

  return {
    start: times.sunset,
    end: new Date(Math.min(times.sunset.getTime() + 4 * 60 * 60 * 1000, nextTimes.sunrise.getTime()))
  };
}

function getLocalVisibility(highlight, user, astronomy, sunCalc, referenceDate) {
  if (highlight.type === "season") {
    if (!user) return { className: "pending", label: "Set location for your season" };
    return {
      className: "visible",
      label: user.lat < 0 ? "Southern Hemisphere · Spring" : "Northern Hemisphere · Autumn"
    };
  }

  if (!user) return { className: "pending", label: "Set location for a local visibility check" };
  if (!astronomy?.Observer || !sunCalc?.getTimes || !sunCalc?.getPosition || !highlight.targets?.length) {
    return { className: "pending", label: "Local visibility check unavailable" };
  }

  const observer = new astronomy.Observer(user.lat, user.lon, 0);
  const startDate = parseLocalDate(highlight.startDate);
  const endDate = parseLocalDate(highlight.endDate);
  const minimumElevation = highlight.minimumElevationDeg ?? 6;
  const maxSunAltitude = highlight.maxSunAltitudeDeg ?? -1;
  let best = null;

  for (let day = startDate; day <= endDate; day = addDays(day, 1)) {
    const window = getSamplingWindow(highlight, day, user.lat, user.lon, sunCalc);
    for (let sampleMs = window.start.getTime(); sampleMs <= window.end.getTime(); sampleMs += 15 * 60 * 1000) {
      const sampleDate = new Date(sampleMs);
      const sunAltitude = sunCalc.getPosition(sampleDate, user.lat, user.lon).altitude * 180 / Math.PI;
      if (sunAltitude > maxSunAltitude) continue;

      const observations = highlight.targets
        .map((target) => getTargetObservation(target, sampleDate, observer, astronomy))
        .filter(Boolean);
      if (observations.length !== highlight.targets.length) continue;
      if (observations.some((observation) => observation.elevation < minimumElevation)) continue;

      const minimumTargetElevation = Math.min(...observations.map((observation) => observation.elevation));
      const averageElevation = observations.reduce((sum, observation) => sum + observation.elevation, 0) / observations.length;
      const score = minimumTargetElevation * 1.4 + averageElevation;
      if (!best || score > best.score) {
        best = { date: sampleDate, observations, minimumTargetElevation, score };
      }
    }
  }

  if (!best) {
    return { className: "limited", label: "No strong local viewing window found" };
  }

  const isTonight = startOfLocalDay(best.date).getTime() === startOfLocalDay(referenceDate).getTime();
  const dateLabel = best.date.toLocaleDateString([], { weekday: "short", day: "numeric", month: "short" });
  const timeLabel = best.date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  const direction = azimuthToCompass(best.observations[0].azimuth);
  const prefix = isTonight ? "Tonight" : dateLabel;
  return {
    className: "visible",
    label: `${prefix} around ${timeLabel} · ${direction} · ${Math.round(best.minimumTargetElevation)}°+`
  };
}

function renderHighlight(highlight, user, astronomy, sunCalc, referenceDate) {
  const status = getDateStatus(highlight, referenceDate);
  const visibility = getLocalVisibility(highlight, user, astronomy, sunCalc, referenceDate);
  const title = getDisplayTitle(highlight, user?.lat);
  return `
    <article class="monthly-highlight ${status.className}" role="listitem">
      <div class="monthly-date-block">
        <span class="monthly-date">${escapeHtml(highlight.dateLabel)}</span>
        <span class="monthly-status">${escapeHtml(status.label)}</span>
      </div>
      <div class="monthly-highlight-copy">
        <h3>${escapeHtml(title)}</h3>
        <p>${escapeHtml(highlight.summary)}</p>
        <div class="monthly-highlight-meta">
          <span class="monthly-equipment">${escapeHtml(highlight.equipment)}</span>
          <span class="monthly-local ${visibility.className}">${escapeHtml(visibility.label)}</span>
        </div>
      </div>
    </article>
  `;
}

export function renderMonthlySkyGuide({
  referenceDate = new Date(),
  user = null,
  astronomy = window.Astronomy,
  sunCalc = window.SunCalc,
  elements
}) {
  const {
    panel,
    title,
    summary,
    sourceLink,
    list,
    source
  } = elements || {};
  if (!panel || !title || !summary || !sourceLink || !list || !source) return;

  const guide = getMonthlySkyGuide(referenceDate);
  if (!guide) {
    title.textContent = `${referenceDate.toLocaleDateString([], { month: "long" })} sky guide`;
    summary.textContent = "The live local forecast above still updates automatically.";
    sourceLink.href = MONTHLY_SKY_GUIDE_INDEX_URL;
    sourceLink.textContent = "NASA What's Up";
    list.innerHTML = `
      <div class="monthly-empty">
        This month's editorial guide has not been added yet. Tonight and the seven-night outlook remain live for your location.
      </div>
    `;
    source.textContent = "Live local calculations remain available above.";
    return;
  }

  title.textContent = guide.title;
  summary.textContent = guide.summary;
  sourceLink.href = guide.sourceUrl;
  sourceLink.textContent = "NASA guide";
  list.innerHTML = guide.highlights
    .map((highlight) => renderHighlight(highlight, user, astronomy, sunCalc, referenceDate))
    .join("");
  source.textContent = user
    ? `Curated from ${guide.sourceName}; viewing windows checked for your location.`
    : `Curated from ${guide.sourceName}. Set your location to check local viewing windows.`;
}
