export const MONTHLY_SKY_GUIDES = {
  "2026-09": {
    label: "September 2026",
    title: "September sky guide",
    summary: "Brilliant Venus, Moon-led landmarks, the equinox, and a memorable lunar pairing.",
    sourceName: "NASA/JPL-Caltech",
    sourceUrl: "https://science.nasa.gov/solar-system/skywatching/whats-up-september-2026-skywatching-tips-from-nasa/",
    highlights: [
      {
        id: "moon-antares-teapot",
        startDate: "2026-09-14",
        endDate: "2026-09-20",
        dateLabel: "14–20 Sep",
        title: "Moon, Antares & the Teapot",
        summary: "Use the Moon to find red Antares and Sagittarius' Teapot. Darker skies may reveal the Milky Way's bright centre.",
        equipment: "Naked eye",
        timePreference: "evening",
        targets: [
          { type: "body", name: "Moon" },
          { type: "fixed", name: "Antares", raHours: 16.49, decDeg: -26.43 },
          { type: "fixed", name: "The Teapot", raHours: 18.4, decDeg: -28.0 }
        ]
      },
      {
        id: "venus-peak-brilliance",
        startDate: "2026-09-18",
        endDate: "2026-09-18",
        dateLabel: "18 Sep",
        title: "Venus at peak brilliance",
        summary: "Look low after sunset for Venus at its brightest during this evening appearance.",
        equipment: "Naked eye",
        timePreference: "evening",
        maxSunAltitudeDeg: -0.5,
        minimumElevationDeg: 3,
        targets: [
          { type: "body", name: "Venus" }
        ]
      },
      {
        id: "september-equinox",
        startDate: "2026-09-22",
        endDate: "2026-09-22",
        dateLabel: "22 Sep",
        title: "September equinox",
        northernTitle: "Autumn begins",
        southernTitle: "Spring begins",
        summary: "Day and night are close to equal as the Sun crosses Earth's equator.",
        equipment: "Season marker",
        type: "season"
      },
      {
        id: "harvest-moon-planets",
        startDate: "2026-09-26",
        endDate: "2026-09-26",
        dateLabel: "26 Sep",
        title: "Full Moon, Saturn & Neptune",
        summary: "The full Moon rises near Saturn, with faint Neptune completing the grouping. Neptune needs optical help.",
        equipment: "Eyes + binoculars",
        timePreference: "evening",
        minimumElevationDeg: 3,
        targets: [
          { type: "body", name: "Moon" },
          { type: "body", name: "Saturn" },
          { type: "body", name: "Neptune" }
        ]
      }
    ]
  }
};

export const MONTHLY_SKY_GUIDE_INDEX_URL = "https://science.nasa.gov/skywatching/whats-up/";

export function getMonthlySkyGuide(date = new Date()) {
  const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
  return MONTHLY_SKY_GUIDES[key] || null;
}
