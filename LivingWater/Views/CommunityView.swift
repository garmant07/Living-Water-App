import SwiftUI

// The Community page. A placeholder for now; stories from the people we
// serve go here later. There is no chat or posting, by design.
struct CommunityView: View {
    var body: some View {
        ComingSoonView(title: "Community", subtitle: "Stories from the people we serve.", icon: "person.3")
    }
}

#Preview {
    NavigationStack {
        CommunityView()
    }
}
