// The shapes of every kind of record in the app.
// Every screen reads these same shapes, so the data can later move from
// these files to a real database or CMS without rewriting the screens.

/** A photo plus the words a screen reader says in its place. */
export type Photo = {
  src: string;
  alt: string;
};

/** A published figure. Real statistics must always say where they came from. */
export type SourcedStat = {
  label: string;
  /** How the figure is shown, e.g. "8M+" */
  display: string;
  /** The plain number, when one exists, for sorting and math. */
  value?: number;
  sourceUrl: string;
  /** When the figure was published or last checked (YYYY-MM). */
  asOf: string;
};

export type Partner = {
  id: string;
  name: string;
  website: string;
  founded: number;
  headquarters?: string;
  description: string;
  faithStatement: string;
  /** Path to a logo file in /public. null until the partner supplies one. */
  logo: string | null;
  countries: string[];
  /** What the partner does on the ground. */
  work: string[];
  /** Published figures. May be empty when a partner hasn't published any. */
  headlineStats: SourcedStat[];
  /** A plain note shown when figures are missing, so the gap is honest. */
  statsNote?: string;
  /** An optional longer story to feature in the app. */
  featureStory?: { title: string; body: string };
};

export type ProjectStatus = "planned" | "in progress" | "completed";

export type SolutionType =
  | "well"
  | "treatment system"
  | "filters"
  | "sanitation"
  | "disaster response";

export type Community = {
  id: string;
  partnerId: string;
  name: string;
  country: string;
  region: string;
  latitude: number;
  longitude: number;
  status: ProjectStatus;
  solutionType: SolutionType;
  peopleServed: number;
  /** US dollars */
  goalAmount: number;
  /** US dollars */
  raisedAmount: number;
  startDate: string;
  completedDate?: string;
  heroPhoto: Photo;
  gallery: Photo[];
  story: string;
  scripture?: { reference: string; text: string };
  /** true = invented for building the app. Shown with a "Sample data" badge. */
  isSample: boolean;
};

export type StoryUpdate = {
  id: string;
  communityId: string;
  date: string;
  title: string;
  body: string;
  photo?: Photo;
  isSample: boolean;
};

export type BottleCode = {
  /** The code printed in the bottle's QR link, e.g. /b/LW-MW-0001 */
  code: string;
  communityId: string;
  batch: string;
  dateProduced: string;
  isSample: boolean;
};

export type Milestone = {
  id: string;
  title: string;
  description: string;
  type: "global" | "personal";
  /** What is being counted to reach this milestone. */
  metric: "peopleServed" | "communities" | "bottlesScanned" | "partners";
  threshold: number;
  achievedDate?: string;
  isSample: boolean;
};

/** Company-wide figures that don't belong to any one project. */
export type CompanyTotals = {
  bottlesSold: number;
  asOf: string;
  isSample: boolean;
};
