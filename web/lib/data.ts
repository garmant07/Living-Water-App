// The one place every screen asks for data.
// Screens never import from /data directly. When the data later moves to a
// database or CMS, only this file has to change.

import { bottles } from "@/data/bottles";
import { communities } from "@/data/communities";
import { companyTotals } from "@/data/company";
import { milestones } from "@/data/milestones";
import { partners } from "@/data/partners";
import { stories } from "@/data/stories";
import type {
  BottleCode,
  Community,
  Milestone,
  Partner,
  StoryUpdate,
} from "@/data/types";

// ---------- Partners ----------

export function getPartners(): Partner[] {
  return partners;
}

export function getPartner(id: string): Partner | undefined {
  return partners.find((partner) => partner.id === id);
}

// ---------- Communities ----------

export function getCommunities(): Community[] {
  return communities;
}

export function getCommunity(id: string): Community | undefined {
  return communities.find((community) => community.id === id);
}

export function getCommunitiesByPartner(partnerId: string): Community[] {
  return communities.filter((community) => community.partnerId === partnerId);
}

export function getCommunitiesByCountry(country: string): Community[] {
  const wanted = country.trim().toLowerCase();
  return communities.filter(
    (community) => community.country.toLowerCase() === wanted,
  );
}

/** Every country that has at least one community, A to Z. */
export function getCountries(): string[] {
  return [...new Set(communities.map((community) => community.country))].sort();
}

// ---------- Progress: accomplished vs. still to do ----------

export type Progress = {
  raised: number;
  goal: number;
  /** Dollars still to go. Never below zero. */
  remaining: number;
  /** 0 to 100, whole number. */
  percent: number;
  isComplete: boolean;
};

export function calculateProgress(raised: number, goal: number): Progress {
  const remaining = Math.max(goal - raised, 0);
  const percent =
    goal > 0 ? Math.min(Math.round((raised / goal) * 100), 100) : 0;
  return { raised, goal, remaining, percent, isComplete: remaining === 0 && goal > 0 };
}

export function getCommunityProgress(community: Community): Progress {
  return calculateProgress(community.raisedAmount, community.goalAmount);
}

// ---------- Totals ----------

export type Totals = {
  peopleServed: number;
  communities: number;
  communitiesCompleted: number;
  countries: number;
  partners: number;
  bottlesSold: number;
  progress: Progress;
  /** true when any number in these totals comes from sample data. */
  includesSampleData: boolean;
};

function totalsFor(list: Community[]): Omit<Totals, "partners" | "bottlesSold"> {
  const raised = list.reduce((sum, c) => sum + c.raisedAmount, 0);
  const goal = list.reduce((sum, c) => sum + c.goalAmount, 0);
  return {
    peopleServed: list.reduce((sum, c) => sum + c.peopleServed, 0),
    communities: list.length,
    communitiesCompleted: list.filter((c) => c.status === "completed").length,
    countries: new Set(list.map((c) => c.country)).size,
    progress: calculateProgress(raised, goal),
    includesSampleData: list.some((c) => c.isSample),
  };
}

/** The big-picture numbers for the whole app. */
export function getTotals(): Totals {
  const base = totalsFor(communities);
  return {
    ...base,
    partners: partners.length,
    bottlesSold: companyTotals.bottlesSold,
    includesSampleData: base.includesSampleData || companyTotals.isSample,
  };
}

/** The same numbers, for one partner's communities only. */
export function getPartnerTotals(partnerId: string) {
  return totalsFor(getCommunitiesByPartner(partnerId));
}

// ---------- Stories ----------

/** All field updates, newest first. */
export function getStories(): StoryUpdate[] {
  return [...stories].sort((a, b) => b.date.localeCompare(a.date));
}

export function getStoriesForCommunity(communityId: string): StoryUpdate[] {
  return getStories().filter((story) => story.communityId === communityId);
}

// ---------- Bottles ----------

/** Tidies a typed or scanned code so " lw-mw-0001 " matches "LW-MW-0001". */
export function normalizeBottleCode(code: string): string {
  return code.trim().toUpperCase();
}

export function getBottle(code: string): BottleCode | undefined {
  const wanted = normalizeBottleCode(code);
  return bottles.find((bottle) => bottle.code === wanted);
}

/** The community a bottle supported, or undefined for an unknown code. */
export function getCommunityForBottle(code: string): Community | undefined {
  const bottle = getBottle(code);
  return bottle ? getCommunity(bottle.communityId) : undefined;
}

// ---------- Milestones ----------

export function getMilestones(type?: Milestone["type"]): Milestone[] {
  return type ? milestones.filter((m) => m.type === type) : milestones;
}

// ---------- Formatting ----------

/** 18400 -> "$18,400" */
export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  }).format(amount);
}

/** 52000 -> "52,000" */
export function formatNumber(value: number): string {
  return new Intl.NumberFormat("en-US").format(value);
}

/** "2026-09-28" -> "September 28, 2026" */
export function formatDate(isoDate: string): string {
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "long",
    timeZone: "UTC",
  }).format(new Date(`${isoDate}T00:00:00Z`));
}
