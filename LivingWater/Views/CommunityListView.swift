import SwiftUI

// Every community as a plain list, grouped by country.
// This is the way in for anyone who can't use the spinning globe.
struct CommunityListView: View {
    let onSelect: (Community) -> Void

    @Environment(\.dismiss) private var dismiss
    private let store = DataStore.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.countries, id: \.self) { country in
                    Section(country) {
                        ForEach(store.communities(inCountry: country)) { community in
                            Button {
                                onSelect(community)
                                dismiss()
                            } label: {
                                row(community)
                            }
                        }
                    }
                }
            }
            .navigationTitle("All communities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ community: Community) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(community.name)
                .font(.headline)
                .foregroundStyle(Theme.foreground)
            Text("\(store.partner(id: community.partnerId)?.name ?? "") · \(Format.number(community.peopleServed)) people served")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            if community.isSample {
                SampleBadge()
            }
        }
        .padding(.vertical, 4)
    }
}
