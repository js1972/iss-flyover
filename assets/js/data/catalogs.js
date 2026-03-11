export const METEOR_SHOWERS = [
  {
    id: "quadrantids",
    name: "Quadrantids",
    activeStart: "12-28",
    activeEnd: "01-12",
    peakMonthDay: "01-03",
    radiantRaHours: 15.3,
    radiantDecDeg: 49.5,
    zhr: 110,
    speedKms: 41,
    tier: "naked-eye"
  },
  {
    id: "lyrids",
    name: "Lyrids",
    activeStart: "04-14",
    activeEnd: "04-30",
    peakMonthDay: "04-22",
    radiantRaHours: 18.1,
    radiantDecDeg: 33.3,
    zhr: 18,
    speedKms: 49,
    tier: "naked-eye"
  },
  {
    id: "eta-aquariids",
    name: "Eta Aquariids",
    activeStart: "04-19",
    activeEnd: "05-28",
    peakMonthDay: "05-06",
    radiantRaHours: 22.5,
    radiantDecDeg: -1,
    zhr: 50,
    speedKms: 66,
    tier: "naked-eye"
  },
  {
    id: "southern-delta-aquariids",
    name: "Southern Delta Aquariids",
    activeStart: "07-12",
    activeEnd: "08-23",
    peakMonthDay: "07-30",
    radiantRaHours: 22.7,
    radiantDecDeg: -16.4,
    zhr: 25,
    speedKms: 41,
    tier: "naked-eye"
  },
  {
    id: "perseids",
    name: "Perseids",
    activeStart: "07-17",
    activeEnd: "08-24",
    peakMonthDay: "08-12",
    radiantRaHours: 3.2,
    radiantDecDeg: 58,
    zhr: 100,
    speedKms: 59,
    tier: "naked-eye"
  },
  {
    id: "orionids",
    name: "Orionids",
    activeStart: "10-02",
    activeEnd: "11-07",
    peakMonthDay: "10-21",
    radiantRaHours: 6.33,
    radiantDecDeg: 15.7,
    zhr: 20,
    speedKms: 66,
    tier: "naked-eye"
  },
  {
    id: "leonids",
    name: "Leonids",
    activeStart: "11-06",
    activeEnd: "11-30",
    peakMonthDay: "11-17",
    radiantRaHours: 10.15,
    radiantDecDeg: 21.6,
    zhr: 15,
    speedKms: 71,
    tier: "naked-eye"
  },
  {
    id: "geminids",
    name: "Geminids",
    activeStart: "12-04",
    activeEnd: "12-17",
    peakMonthDay: "12-14",
    radiantRaHours: 7.5,
    radiantDecDeg: 32,
    zhr: 120,
    speedKms: 35,
    tier: "naked-eye"
  }
];

export const DEEP_SKY_TARGETS = [
  {
    id: "m42",
    name: "Orion Nebula",
    type: "Nebula",
    raHours: 5.59,
    decDeg: -5.45,
    tier: "binoculars",
    hint: "Easy glow below Orion's belt. Binoculars make it pop."
  },
  {
    id: "m45",
    name: "Pleiades",
    type: "Open cluster",
    raHours: 3.79,
    decDeg: 24.12,
    tier: "naked-eye",
    hint: "Compact star cluster. Binoculars add sparkle."
  },
  {
    id: "m31",
    name: "Andromeda Galaxy",
    type: "Galaxy",
    raHours: 0.71,
    decDeg: 41.27,
    tier: "binoculars",
    hint: "Visible from dark skies; binoculars help a lot."
  },
  {
    id: "omega-centauri",
    name: "Omega Centauri",
    type: "Globular cluster",
    raHours: 13.45,
    decDeg: -47.48,
    tier: "binoculars",
    hint: "Superb southern globular. Binoculars reveal its shape."
  },
  {
    id: "lmc",
    name: "Large Magellanic Cloud",
    type: "Dwarf galaxy",
    raHours: 5.39,
    decDeg: -69.75,
    tier: "naked-eye",
    hint: "Best from dark southern skies."
  },
  {
    id: "smc",
    name: "Small Magellanic Cloud",
    type: "Dwarf galaxy",
    raHours: 0.88,
    decDeg: -72.83,
    tier: "naked-eye",
    hint: "Compact southern cloud. Binoculars help resolve structure."
  },
  {
    id: "carina-nebula",
    name: "Carina Nebula",
    type: "Nebula",
    raHours: 10.75,
    decDeg: -59.68,
    tier: "binoculars",
    hint: "Huge southern nebula field. Strong binocular target."
  },
  {
    id: "jewel-box",
    name: "Jewel Box",
    type: "Open cluster",
    raHours: 12.9,
    decDeg: -60.37,
    tier: "binoculars",
    hint: "Tiny but beautiful cluster near the Southern Cross."
  }
];

export const BRIGHT_STARS = [
  { id: "sirius", name: "Sirius", raHours: 6.75, decDeg: -16.72, mag: -1.46 },
  { id: "canopus", name: "Canopus", raHours: 6.4, decDeg: -52.69, mag: -0.74 },
  { id: "arcturus", name: "Arcturus", raHours: 14.26, decDeg: 19.18, mag: -0.05 },
  { id: "vega", name: "Vega", raHours: 18.62, decDeg: 38.78, mag: 0.03 },
  { id: "capella", name: "Capella", raHours: 5.28, decDeg: 45.99, mag: 0.08 },
  { id: "rigel", name: "Rigel", raHours: 5.24, decDeg: -8.2, mag: 0.13 },
  { id: "procyon", name: "Procyon", raHours: 7.66, decDeg: 5.22, mag: 0.34 },
  { id: "achernar", name: "Achernar", raHours: 1.63, decDeg: -57.24, mag: 0.46 },
  { id: "betelgeuse", name: "Betelgeuse", raHours: 5.92, decDeg: 7.41, mag: 0.5 },
  { id: "altair", name: "Altair", raHours: 19.85, decDeg: 8.87, mag: 0.76 },
  { id: "acrux", name: "Acrux", raHours: 12.45, decDeg: -63.1, mag: 0.77 },
  { id: "aldebaran", name: "Aldebaran", raHours: 4.6, decDeg: 16.51, mag: 0.85 },
  { id: "spica", name: "Spica", raHours: 13.42, decDeg: -11.16, mag: 0.97 },
  { id: "antares", name: "Antares", raHours: 16.49, decDeg: -26.43, mag: 1.06 },
  { id: "fomalhaut", name: "Fomalhaut", raHours: 22.96, decDeg: -29.62, mag: 1.16 },
  { id: "pollux", name: "Pollux", raHours: 7.76, decDeg: 28.03, mag: 1.14 }
];

export const CONSTELLATIONS = [
  {
    id: "orion",
    name: "Orion",
    anchorStar: "Betelgeuse",
    raHours: 5.92,
    decDeg: 7.41,
    bestMonths: [12, 1, 2, 3],
    tip: "Look for the belt first, then sweep down to the Orion Nebula.",
    labelStarId: "betelgeuse",
    labelOffsetPx: { x: 10, y: -16 },
    guideStars: [
      { id: "betelgeuse", name: "Betelgeuse", raHours: 5.92, decDeg: 7.41, anchor: true },
      { id: "bellatrix", name: "Bellatrix", raHours: 5.42, decDeg: 6.35 },
      { id: "mintaka", name: "Mintaka", raHours: 5.53, decDeg: -0.3 },
      { id: "alnilam", name: "Alnilam", raHours: 5.6, decDeg: -1.2 },
      { id: "alnitak", name: "Alnitak", raHours: 5.68, decDeg: -1.94 },
      { id: "saiph", name: "Saiph", raHours: 5.79, decDeg: -9.67 },
      { id: "rigel", name: "Rigel", raHours: 5.24, decDeg: -8.2 }
    ],
    segments: [
      ["betelgeuse", "bellatrix"],
      ["bellatrix", "mintaka"],
      ["mintaka", "alnilam"],
      ["alnilam", "alnitak"],
      ["alnitak", "saiph"],
      ["saiph", "rigel"]
    ]
  },
  {
    id: "southern-cross",
    name: "Southern Cross",
    anchorStar: "Acrux",
    raHours: 12.45,
    decDeg: -63.1,
    bestMonths: [3, 4, 5, 6],
    tip: "Use the Cross to find south and the Coalsack dark nebula.",
    labelStarId: "gacrux",
    labelOffsetPx: { x: 10, y: -14 },
    guideStars: [
      { id: "gacrux", name: "Gacrux", raHours: 12.52, decDeg: -57.11 },
      { id: "mimosa", name: "Mimosa", raHours: 12.8, decDeg: -59.69 },
      { id: "delta-crucis", name: "Delta Crucis", raHours: 12.25, decDeg: -58.75 },
      { id: "acrux", name: "Acrux", raHours: 12.45, decDeg: -63.1, anchor: true }
    ],
    segments: [
      ["gacrux", "acrux"],
      ["delta-crucis", "mimosa"],
      ["gacrux", "delta-crucis"],
      ["gacrux", "mimosa"]
    ]
  },
  {
    id: "scorpius",
    name: "Scorpius",
    anchorStar: "Antares",
    raHours: 16.49,
    decDeg: -26.43,
    bestMonths: [5, 6, 7, 8],
    tip: "Curving tail and bright red Antares make this easy to spot.",
    labelStarId: "antares",
    labelOffsetPx: { x: 10, y: -14 },
    guideStars: [
      { id: "acrab", name: "Acrab", raHours: 16.09, decDeg: -19.81 },
      { id: "dschubba", name: "Dschubba", raHours: 16, decDeg: -22.62 },
      { id: "antares", name: "Antares", raHours: 16.49, decDeg: -26.43, anchor: true },
      { id: "sargas", name: "Sargas", raHours: 17.62, decDeg: -42.99 },
      { id: "shaula", name: "Shaula", raHours: 17.56, decDeg: -37.1 },
      { id: "lesath", name: "Lesath", raHours: 17.51, decDeg: -37.3 }
    ],
    segments: [
      ["acrab", "dschubba"],
      ["dschubba", "antares"],
      ["antares", "sargas"],
      ["sargas", "shaula"],
      ["shaula", "lesath"]
    ]
  },
  {
    id: "sagittarius",
    name: "Sagittarius",
    anchorStar: "Kaus Australis",
    raHours: 18.4,
    decDeg: -34.38,
    bestMonths: [6, 7, 8, 9],
    tip: "The Teapot points into the Milky Way's brightest region.",
    labelStarId: "kaus-media",
    labelOffsetPx: { x: 10, y: -14 },
    guideStars: [
      { id: "kaus-borealis", name: "Kaus Borealis", raHours: 18.47, decDeg: -25.42 },
      { id: "kaus-media", name: "Kaus Media", raHours: 18.35, decDeg: -29.83 },
      { id: "kaus-australis", name: "Kaus Australis", raHours: 18.4, decDeg: -34.38, anchor: true },
      { id: "alnasl", name: "Alnasl", raHours: 18.1, decDeg: -30.42 },
      { id: "nunki", name: "Nunki", raHours: 18.92, decDeg: -26.3 },
      { id: "ascella", name: "Ascella", raHours: 19.05, decDeg: -29.88 }
    ],
    segments: [
      ["kaus-borealis", "kaus-media"],
      ["kaus-media", "kaus-australis"],
      ["kaus-media", "alnasl"],
      ["kaus-borealis", "nunki"],
      ["nunki", "ascella"],
      ["ascella", "kaus-australis"]
    ]
  },
  {
    id: "taurus",
    name: "Taurus",
    anchorStar: "Aldebaran",
    raHours: 4.6,
    decDeg: 16.51,
    bestMonths: [11, 12, 1, 2],
    tip: "Aldebaran, the Hyades, and nearby Pleiades make a strong binocular area.",
    labelStarId: "aldebaran",
    labelOffsetPx: { x: 10, y: -14 },
    guideStars: [
      { id: "elnath", name: "Elnath", raHours: 5.43, decDeg: 28.61 },
      { id: "aldebaran", name: "Aldebaran", raHours: 4.6, decDeg: 16.51, anchor: true },
      { id: "ain", name: "Ain", raHours: 4.48, decDeg: 19.18 },
      { id: "zeta-tauri", name: "Zeta Tauri", raHours: 5.63, decDeg: 21.14 }
    ],
    segments: [
      ["ain", "aldebaran"],
      ["aldebaran", "zeta-tauri"],
      ["zeta-tauri", "elnath"]
    ]
  },
  {
    id: "carina",
    name: "Carina",
    anchorStar: "Canopus",
    raHours: 6.4,
    decDeg: -52.69,
    bestMonths: [1, 2, 3, 4],
    tip: "Canopus anchors a rich southern region full of clusters and nebulae.",
    labelStarId: "canopus",
    labelOffsetPx: { x: 10, y: -14 },
    guideStars: [
      { id: "canopus", name: "Canopus", raHours: 6.4, decDeg: -52.69, anchor: true },
      { id: "miaplacidus", name: "Miaplacidus", raHours: 9.22, decDeg: -69.72 },
      { id: "avior", name: "Avior", raHours: 8.38, decDeg: -59.51 },
      { id: "aspidiske", name: "Aspidiske", raHours: 9.28, decDeg: -59.28 },
      { id: "theta-carinae", name: "Theta Carinae", raHours: 10.72, decDeg: -64.39 }
    ],
    segments: [
      ["canopus", "avior"],
      ["avior", "miaplacidus"],
      ["avior", "aspidiske"],
      ["aspidiske", "theta-carinae"],
      ["miaplacidus", "theta-carinae"]
    ]
  }
];
