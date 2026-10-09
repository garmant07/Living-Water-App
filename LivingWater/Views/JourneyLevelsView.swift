import SwiftUI

// The top of the Personal Journey: the level reached, the container being
// filled now, and all 25 levels from a glass of water to an Olympic pool.
struct JourneyLevelsView: View {
    /// The person's real number of saved bottles.
    let bottles: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedLevel: JourneyLevel?
    /// While building the app: a pretend number of bottles, to see any level.
    @State private var previewBottles: Int?

    private let store = DataStore.shared

    private var shownBottles: Int { previewBottles ?? bottles }
    private var progress: LevelProgress { store.levelProgress(bottles: shownBottles) }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            hero
            #if DEBUG
            previewTool
            #endif
            ladder
                .id("ladder")
        }
        .onAppear {
            #if DEBUG
            // For testing: launch with "-previewBottles 300" to open on that many bottles.
            if previewBottles == nil, UserDefaults.standard.object(forKey: "previewBottles") != nil {
                previewBottles = UserDefaults.standard.integer(forKey: "previewBottles")
            }
            #endif
        }
    }

    // MARK: Where you are now

    private var hero: some View {
        let progress = progress

        return Card {
            VStack(spacing: 14) {
                Text(progress.current.map { "Level \($0.level) of \(store.levels.count)" } ?? "Level 0 of \(store.levels.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)

                // The container being filled now. It fills as bottles are scanned.
                VesselView(kind: (progress.next ?? progress.current)?.vessel ?? .glass, fill: progress.fill, lineWidth: 4)
                    .frame(width: 170, height: 170)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: progress.fill)

                Text(progress.current?.name ?? "Your glass is waiting")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(givenLine(progress))
                    .font(.body)
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)

                Text(nextLine(progress))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    private func givenLine(_ progress: LevelProgress) -> String {
        guard progress.bottles > 0 else { return "Every bottle you scan pours a little more in." }
        return "\(Format.number(progress.bottles)) \(progress.bottles == 1 ? "bottle" : "bottles") · \(Format.volume(progress.liters)) of water"
    }

    private func nextLine(_ progress: LevelProgress) -> String {
        guard let next = progress.next else { return "You've filled an Olympic swimming pool. Every level is complete." }
        let count = progress.bottlesToNext
        if progress.bottles == 0 { return "Scan your first bottle to fill \(next.short)." }
        return "\(Format.number(count)) more \(count == 1 ? "bottle fills" : "bottles fill") \(next.short)."
    }

    // MARK: All 25 levels

    private var ladder: some View {
        let progress = progress
        let reached = progress.current?.level ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeading("All \(store.levels.count) levels")
            Text("From a glass of water to an Olympic swimming pool. Tap any level to see what it takes.")
                .font(.body)
                .foregroundStyle(Theme.muted)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(store.levels) { level in
                    let isReached = level.level <= reached
                    let isFilling = level.level == reached + 1

                    Button {
                        selectedLevel = selectedLevel == level ? nil : level
                    } label: {
                        VStack(spacing: 2) {
                            VesselView(kind: level.vessel, fill: isReached ? 1 : (isFilling ? progress.fill : 0), lineWidth: 2)
                                .frame(width: 36, height: 36)
                            Text("\(level.level)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.foreground)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .opacity(isReached || isFilling ? 1 : 0.55)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedLevel == level ? Theme.foreground : Theme.border, lineWidth: selectedLevel == level ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Level \(level.level), \(level.name), \(isReached ? "reached" : "not reached yet")")
                }
            }

            if let level = selectedLevel {
                levelDetail(level, isReached: level.level <= reached)
            }
        }
    }

    private func levelDetail(_ level: JourneyLevel, isReached: Bool) -> some View {
        let needed = store.bottlesNeeded(for: level)

        return Card {
            HStack(alignment: .top, spacing: 14) {
                VesselView(kind: level.vessel, fill: 1, lineWidth: 3)
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(level.level) · \(level.name)")
                        .font(.headline)
                        .foregroundStyle(Theme.foreground)
                    Text("\(Format.volume(level.liters)) · \(Format.number(needed)) \(needed == 1 ? "bottle" : "bottles")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                    Text(level.note)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    Text(isReached ? "Reached" : "\(Format.number(max(needed - shownBottles, 0))) more to go")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Preview tool (only while building the app)

    #if DEBUG
    /// The slider runs from 0 to 1. This turns that into bottles on a curve,
    /// so the small early levels and the huge late ones both get room.
    private var mostBottles: Double {
        Double(store.levels.last.map(store.bottlesNeeded) ?? 1)
    }

    private var sliderPosition: Binding<Double> {
        Binding(
            get: { shownBottles <= 0 ? 0 : min(log(Double(shownBottles) + 1) / log(mostBottles + 1), 1) },
            set: { previewBottles = Int((pow(mostBottles + 1, $0) - 1).rounded()) }
        )
    }

    private var previewTool: some View {
        Card {
            HStack {
                Text("Try the levels")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                Spacer()
                Text("Preview tool")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.sampleForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.sampleBackground, in: Capsule())
            }
            Text("Drag to pretend you've scanned more bottles and watch the levels fill. This box is only here while the app is being built.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

            Slider(value: sliderPosition)
                .tint(Theme.brand)
                .accessibilityLabel("Pretend number of bottles")
                .accessibilityValue("\(shownBottles) bottles")

            HStack(spacing: 10) {
                Button("Previous level") { jump(by: -1) }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Next level") { jump(by: 1) }
                    .buttonStyle(SecondaryButtonStyle())
            }

            if previewBottles != nil {
                Button("Back to my real bottles (\(bottles))") { previewBottles = nil }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    /// Moves the pretend bottle count to exactly the next or previous level.
    private func jump(by step: Int) {
        let reached = progress.current?.level ?? 0
        let target = min(max(reached + step, 0), store.levels.count)
        previewBottles = store.levels.first { $0.level == target }.map(store.bottlesNeeded) ?? 0
    }
    #endif
}

#Preview {
    ScrollView {
        JourneyLevelsView(bottles: 3)
            .padding()
    }
    .background(Theme.background)
}
