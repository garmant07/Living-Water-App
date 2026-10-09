import SwiftUI

// One update from the field, naming the country and ministry it came from.
struct StoryCard: View {
    let story: StoryUpdate
    let community: Community

    var body: some View {
        Card {
            if let photo = story.photo {
                PhotoView(photo: photo)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            HStack {
                Text(Format.date(story.date))
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                Spacer()
                if story.isSample {
                    SampleBadge()
                }
            }
            Text(story.title)
                .font(.headline)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.leading)
            Text(story.body)
                .font(.body)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.leading)
            HStack(spacing: 4) {
                Text("\(community.country) · \(DataStore.shared.partner(id: community.partnerId)?.name ?? "")")
                Image(systemName: "chevron.right")
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.foreground)
        }
    }
}
