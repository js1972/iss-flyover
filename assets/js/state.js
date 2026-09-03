import { createHealthState } from "./status.js?v=2026.09.03-sky-tonight.1";

export const state =  {
  user: null,
  iss: null,
  issSamples: { prev: null, next: null },
  tle: null,
  tlePromise: null,
  tleUpdated: 0,
  map: null,
  mapTileLayer: null,
  mapTheme: "primary",
  mapFitZoom: 2,
  mapFallbackNotified: false,
  markers: {},
  trackOutline: null,
  trackLine: null,
  trackGlow: null,
  trackData: [],
  trail: [],
  passes: [],
  goodPasses: [],
  passSkyHighlights: {},
  alignmentEvents: [],
  skyEvents: [],
  meteorEvents: [],
  skyNightBundles: [],
  tonightTimeline: [],
  tonightSnapshot: null,
  tonightWindow: null,
  weather: {
    summary: null,
    hourly: [],
    fetchedAt: 0,
    error: null
  },
  planetCache: new Map(),
  nextVisible: null,
  tonight: { pass: null, skyEvent: null },
  anim: { rafId: null, lastStatus: 0 },
  preview: { active: false, mode: "live", pass: null, skyEvent: null },
  globe: {
    ready: false,
    scene: null,
    camera: null,
    renderer: null,
    controls: null,
    earth: null,
    issMesh: null,
    userMesh: null,
    trackLine: null,
    trackGlow: null
  },
  sky: {
    rotation: 0,
    zoom: 1,
    dragging: false,
    dragStart: null,
    compass: {
      active: false,
      heading: null,
      smoothedHeading: null,
      accuracy: null,
      supported: null
    },
    stars: []
  },
  layout: {
    compactMobile: null,
    narrowMobile: null
  },
  health: createHealthState(),
  ui: {
    refreshing: false,
    refreshPromise: null,
    lastRefreshStatus: "idle",
    timelineExpanded: true,
    advancedExpanded: false,
    booting: true,
    bootReady: false,
    bootStage: "iss",
    hasCompletedInitialLoad: false,
    bootError: null,
    lastSuccessfulRefreshAt: 0,
    lastRefreshLocalDate: "",
    issPassListExpanded: false,
    skyHighlightListExpanded: false,
    skyViewingPreference: "evening-first",
    expandedSkyDayKeys: new Set(),
    appVersion: {
      current: "",
      latest: "",
      updateAvailable: false
    }
  }
};
