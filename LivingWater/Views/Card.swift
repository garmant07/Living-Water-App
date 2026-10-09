import SwiftUI

// The shared look for every card: a slightly deeper blue panel with a thin outline.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
    }
}

// A heading that VoiceOver announces as a heading.
struct SectionHeading: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.title2.weight(.semibold))
            .foregroundStyle(Theme.foreground)
            .accessibilityAddTraits(.isHeader)
    }
}

// One big number with its label underneath.
struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.brandStrong)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// A published figure from a partner, shown with where and when it came from.
struct SourcedStatRow: View {
    let stat: SourcedStat

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(stat.label)
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(stat.display)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.foreground)
        }
        .font(.body)
        .accessibilityElement(children: .combine)
    }
}
