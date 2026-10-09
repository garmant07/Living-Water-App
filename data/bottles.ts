import type { BottleCode } from "./types";

// SAMPLE DATA. Each code is what a bottle's QR link ends with: /b/LW-MW-0001
// OPEN QUESTION for the founders: does each bottle fund one specific project,
// or is the money split across the three partners? For now each code points
// at one community.

export const bottles: BottleCode[] = [
  { code: "LW-MW-0001", communityId: "wm-malawi-1", batch: "2026-09-A", dateProduced: "2026-09-02", isSample: true },
  { code: "LW-HN-0001", communityId: "wm-honduras-1", batch: "2026-09-A", dateProduced: "2026-09-02", isSample: true },
  { code: "LW-KE-0001", communityId: "wm-kenya-1", batch: "2026-09-B", dateProduced: "2026-09-16", isSample: true },
  { code: "LW-ET-0001", communityId: "wfg-ethiopia-1", batch: "2026-09-B", dateProduced: "2026-09-16", isSample: true },
  { code: "LW-CF-0001", communityId: "wfg-car-1", batch: "2026-10-A", dateProduced: "2026-10-01", isSample: true },
  { code: "LW-NE-0001", communityId: "coh-niger-1", batch: "2026-10-A", dateProduced: "2026-10-01", isSample: true },
  { code: "LW-UA-0001", communityId: "coh-ukraine-1", batch: "2026-10-A", dateProduced: "2026-10-01", isSample: true },
];
