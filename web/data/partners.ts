import type { Partner } from "./types";

// REAL DATA. Figures are as published by each partner, October 2026.
// Every figure carries its source link and as-of date.

export const partners: Partner[] = [
  {
    id: "water-mission",
    name: "Water Mission",
    website: "https://watermission.org",
    founded: 2001,
    headquarters: "North Charleston, South Carolina",
    description:
      "A Christian engineering nonprofit founded by George and Molly Greene that designs and builds safe-water systems for communities, refugee settlements, and disaster zones.",
    faithStatement:
      "Water Mission serves as a Christian engineering ministry, bringing safe water as an expression of God's love.",
    logo: null,
    countries: [
      "Honduras",
      "Indonesia",
      "Kenya",
      "Malawi",
      "Mexico",
      "Peru",
      "Tanzania",
      "Uganda",
    ],
    work: [
      "Engineered safe-water treatment systems",
      "Sanitation and hygiene",
      "Refugee water (Uganda)",
      "Disaster response worldwide, including Nepal flooding in 2026",
    ],
    headlineStats: [
      {
        label: "People served since 2001",
        display: "8M+",
        value: 8_000_000,
        sourceUrl: "https://watermission.org",
        asOf: "2026-10",
      },
      {
        label: "Countries",
        display: "60+",
        value: 60,
        sourceUrl: "https://watermission.org",
        asOf: "2026-10",
      },
      {
        label: "Years with Charity Navigator's top rating",
        display: "19 in a row",
        value: 19,
        sourceUrl: "https://watermission.org",
        asOf: "2026-10",
      },
      {
        label: "People served in Tanzania",
        display: "1.1M+",
        value: 1_100_000,
        sourceUrl: "https://watermission.org",
        asOf: "2026-10",
      },
      {
        label: "People served in Honduras",
        display: "~995,000",
        value: 995_000,
        sourceUrl: "https://watermission.org",
        asOf: "2026-10",
      },
      {
        label: "People served in Malawi",
        display: "~860,000",
        value: 860_000,
        sourceUrl: "https://watermission.org",
        asOf: "2026-10",
      },
      {
        label: "People served in Indonesia",
        display: "450,000+",
        value: 450_000,
        sourceUrl: "https://watermission.org",
        asOf: "2026-10",
      },
      {
        label: "People served in Kenya",
        display: "~450,000",
        value: 450_000,
        sourceUrl: "https://watermission.org",
        asOf: "2026-10",
      },
      {
        label: "People served in Mexico",
        display: "240,000+",
        value: 240_000,
        sourceUrl: "https://watermission.org",
        asOf: "2026-10",
      },
      {
        label: "People served in Peru",
        display: "162,000+",
        value: 162_000,
        sourceUrl: "https://watermission.org",
        asOf: "2026-10",
      },
    ],
    featureStory: {
      title: "Project Living Water",
      body: "Water Mission's very first effort was called \"Project Living Water,\" and the treatment unit it still builds today is named the Living Water Treatment System. Long before our bottles existed, the same two words were already bringing safe water to people.",
    },
  },
  {
    id: "water-for-good",
    name: "Water for Good",
    website: "https://waterforgood.org",
    founded: 2004,
    description:
      "A Christian organization founded in the Central African Republic by Jim Hocking. In 2024 it merged with Lifewater International (established 1977) and continues under the Water for Good name.",
    faithStatement:
      "Water for Good works alongside local churches so that whole villages can be healthy, in body and in spirit.",
    logo: null,
    countries: [
      "Cambodia",
      "Central African Republic",
      "Ethiopia",
      "Uganda",
      "Tanzania",
    ],
    work: [
      "Reliable, maintained water points",
      "\"Vision of a Healthy Village\" three-year model",
      "Partnership with local churches",
    ],
    headlineStats: [
      {
        label: "People with reliable water each year",
        display: "1.3M+",
        value: 1_300_000,
        sourceUrl: "https://waterforgood.org",
        asOf: "2026-10",
      },
      {
        label: "Water points working",
        display: "90%",
        value: 90,
        sourceUrl: "https://waterforgood.org",
        asOf: "2026-10",
      },
      {
        label: "Median drop in childhood diarrhea in completed villages",
        display: "90%",
        value: 90,
        sourceUrl: "https://waterforgood.org",
        asOf: "2026-10",
      },
    ],
    statsNote: "Goal: double its impact by 2028.",
  },
  {
    id: "convoy-of-hope",
    name: "Convoy of Hope",
    website: "https://convoyofhope.org/donate/water/",
    founded: 1994,
    headquarters: "Springfield, Missouri",
    description:
      "A global faith-based organization serving people through wells, water filters, community facilities, and disaster relief.",
    faithStatement:
      "Convoy of Hope is a faith-based organization driven to bring help and hope to those who are impoverished, hungry, and hurting.",
    logo: null,
    countries: [
      "Tanzania",
      "Niger",
      "Ukraine",
      "Indonesia",
      "Bulgaria",
      "United States",
    ],
    work: [
      "Wells in Tanzania and Niger",
      "Water filters in Ukraine and Indonesia",
      "A community bathhouse in Sredets, Bulgaria",
      "Bottled water for U.S. disaster relief",
    ],
    headlineStats: [
      {
        label: "People served across all programs",
        display: "350M",
        value: 350_000_000,
        sourceUrl: "https://convoyofhope.org/donate/water/",
        asOf: "2026-10",
      },
    ],
    statsNote:
      "Convoy of Hope has not yet published a water-only total. The figure shown covers all of its programs, not just water.",
  },
];
