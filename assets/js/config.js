export const ISS_NOW_URL = "https://api.wheretheiss.at/v1/satellites/25544";
export const ISS_POS_URL = "https://api.wheretheiss.at/v1/satellites/25544/positions?timestamps=";
export const ISS_TLE_URL = "https://api.wheretheiss.at/v1/satellites/25544/tles";
export const WEATHER_URL = "https://api.open-meteo.com/v1/forecast";
export const REVERSE_GEOCODE_URL = "https://nominatim.openstreetmap.org/reverse";
export const STORAGE_KEY = "iss-flyover-location";
export const FORECAST_DAYS = 7;
export const GLOBE_VISUALS = {
  texturePrimary: "https://unpkg.com/three-globe/example/img/earth-day.jpg",
  textureFallback: "https://unpkg.com/three-globe/example/img/earth-blue-marble.jpg",
  toneMappingExposure: 1.18,
  ambientIntensity: 0.95,
  keyIntensity: 1.1,
  keyPosition: [4.8, 2.6, 5.2],
  fillIntensity: 0.38,
  fillPosition: [-4.2, -1.4, -4.8],
  emissive: 0x0f1523,
  shininess: 10,
  atmosphereOpacity: 0.05
};
export const MAP_VISUALS = {
  tilePrimary: "https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}{r}.png",
  tileFallback: "https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png",
  tileFilterPrimary: "brightness(0.86) contrast(1.22) saturate(1.15)",
  tileFilterFallback: "brightness(1.12) contrast(1.10) saturate(1.06)",
  mapBackground: "#1a2940",
  trackOutlineColor: "#031b2a",
  trackGlowColor: "#22d5ff",
  trackDashColor: "#57e6ff"
};
export const PLANET_VISUALS = {
  planets: [
    { body: "Mercury", color: "#d0bea5" },
    { body: "Venus", color: "#ffd56a" },
    { body: "Mars", color: "#ff9166" },
    { body: "Jupiter", color: "#f1e8c9" },
    { body: "Saturn", color: "#e7c589" }
  ],
  moon: { body: "Moon", color: "#ccd8ff" },
  planetVisibility: {
    Mercury: { maxSunAltitudeDeg: -7, minElevationDeg: 6 },
    Venus: { maxSunAltitudeDeg: -1.5, minElevationDeg: 4 },
    Mars: { maxSunAltitudeDeg: -4.5, minElevationDeg: 4 },
    Jupiter: { maxSunAltitudeDeg: -2.5, minElevationDeg: 4 },
    Saturn: { maxSunAltitudeDeg: -3.5, minElevationDeg: 4 }
  },
  minElevationDeg: 10,
  maxSunAltitudeDeg: -4,
  moonlightElevationDeg: 0,
  brightMagnitude: 1.5,
  darkSkyIlluminationPctMax: 30,
  brightMoonIlluminationPctMin: 70,
  alignmentSeparationDeg: 4.0,
  alignmentWindowSeconds: 3600,
  alignmentStepMinutes: 30,
  moonPhaseBands: [
    { max: 0.0625, name: "New Moon", icon: "🌑" },
    { max: 0.1875, name: "Waxing Crescent", icon: "🌒" },
    { max: 0.3125, name: "First Quarter", icon: "🌓" },
    { max: 0.4375, name: "Waxing Gibbous", icon: "🌔" },
    { max: 0.5625, name: "Full Moon", icon: "🌕" },
    { max: 0.6875, name: "Waning Gibbous", icon: "🌖" },
    { max: 0.8125, name: "Last Quarter", icon: "🌗" },
    { max: 0.9375, name: "Waning Crescent", icon: "🌘" },
    { max: 1.01, name: "New Moon", icon: "🌑" }
  ]
};
