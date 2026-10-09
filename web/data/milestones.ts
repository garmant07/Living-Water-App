import type { Milestone } from "./types";

// SAMPLE DATA. "global" milestones are shared by everyone;
// "personal" milestones become badges on a person's own journey.

export const milestones: Milestone[] = [
  {
    id: "global-10k-people",
    title: "10,000 people reached together",
    description: "Sample milestone. Every bottle counted toward this.",
    type: "global",
    metric: "peopleServed",
    threshold: 10000,
    achievedDate: "2026-07-04",
    isSample: true,
  },
  {
    id: "global-25k-people",
    title: "25,000 people reached together",
    description: "Sample milestone.",
    type: "global",
    metric: "peopleServed",
    threshold: 25000,
    achievedDate: "2026-09-20",
    isSample: true,
  },
  {
    id: "global-50k-people",
    title: "50,000 people reached together",
    description: "Sample milestone. Not there yet.",
    type: "global",
    metric: "peopleServed",
    threshold: 50000,
    isSample: true,
  },
  {
    id: "personal-first-scan",
    title: "First bottle",
    description: "You scanned your first bottle.",
    type: "personal",
    metric: "bottlesScanned",
    threshold: 1,
    isSample: false,
  },
  {
    id: "personal-5-communities",
    title: "Five communities",
    description: "Your bottles have supported five different communities.",
    type: "personal",
    metric: "communities",
    threshold: 5,
    isSample: false,
  },
  {
    id: "personal-every-partner",
    title: "Every partner",
    description: "You have supported all three ministry partners.",
    type: "personal",
    metric: "partners",
    threshold: 3,
    isSample: false,
  },
];
