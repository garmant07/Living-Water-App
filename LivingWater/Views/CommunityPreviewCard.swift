import SwiftUI

// The small card that appears when a light on the globe is tapped.
struct CommunityPreviewCard: View {
    let community: Community
    let partner: Partner?
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Tapping the photo or the words opens the full story.
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 14) {
                    PhotoView(photo: community.heroPhoto)
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    details
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens this community's story")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close")
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(community.name)
                .font(.headline)
                .foregroundStyle(Theme.foreground)
            Text(community.country)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            if let partner {
                Text("with \(partner.name)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Text("\(Format.number(community.peopleServed)) people served")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.brandStrong)
            if community.isSample {
                SampleBadge()
                    .padding(.top, 2)
            }
            HStack(spacing: 4) {
                Text("Read the story")
                Image(systemName: "chevron.right")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.foreground)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
