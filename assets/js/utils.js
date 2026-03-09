export const formatCoord = (val) => `${val.toFixed(3)}°`;

export const formatTime = (date) =>
  date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

export const formatDateTime = (date) =>
  date.toLocaleString([], {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  });

export const formatCompactBestTime = (timestampSec) =>
  new Date(timestampSec * 1000).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit"
  });

export const formatTonightMoment = (timestampSec) => {
  const value = new Date(timestampSec * 1000);
  const now = new Date();
  if (value.toDateString() === now.toDateString()) {
    return `${formatTime(value)} local`;
  }
  return formatDateTime(value);
};

export function isCompactMobileLayout() {
  return window.matchMedia("(max-width: 900px)").matches;
}

export function isNarrowMobileLayout() {
  return window.matchMedia("(max-width: 560px)").matches;
}
