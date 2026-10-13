import SwiftUI

// The Community page: stories from the people we serve, written by the
// Living Water team. There is no chat, posting or commenting, by design.
struct CommunityView: View {
    private let content = CloudContent.shared

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 8) {
                PageTitle("Community")
                EditableText(key: "community_intro", fallback: "Stories from the people we serve.", name: "Community introduction")
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
                EditShortcut(title: "Edit stories", route: .operatorStories)
            }

            if content.stories.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.3")
                        .font(.system(size: 80))
                        .foregroundStyle(Theme.foreground)
                        .padding(.vertical, 24)
                        .accessibilityHidden(true)
                    Text(content.storiesFailed
                        ? "We couldn't load the stories. Pull down to try again."
                        : "Coming soon. We're building something good here.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.foreground)
                }
                .frame(maxWidth: .infinity)
            }

            ForEach(content.stories) { story in
                Card {
                    if story.imageUrl != nil {
                        Color.clear
                            .aspectRatio(16.0 / 10.0, contentMode: .fit)
                            .overlay { RemotePhoto(address: story.imageUrl) }
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .accessibilityHidden(true)
                    }
                    Text(story.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                    if let location = story.location, !location.isEmpty {
                        Text(location)
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    Text(story.body)
                        .lineSpacing(4)
                        .foregroundStyle(Theme.foreground)
                }
            }
        }
        .refreshable { await content.loadStories() }
        .task { await content.loadStories() }
    }
}

#Preview {
    NavigationStack {
        CommunityView()
    }
}
