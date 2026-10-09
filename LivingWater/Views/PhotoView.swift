import SwiftUI
import UIKit

// Shows a photo from Assets. Until a real photo with that name exists,
// it shows a clearly labeled placeholder instead.
struct PhotoView: View {
    let photo: Photo

    var body: some View {
        Group {
            if UIImage(named: photo.src) != nil {
                Image(photo.src)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Theme.background, Theme.deep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(photo.alt)
        .accessibilityAddTraits(.isImage)
    }
}
