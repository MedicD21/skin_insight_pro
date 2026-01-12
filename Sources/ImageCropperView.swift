import SwiftUI

struct ImageCropperView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss

    let image: UIImage
    let onCrop: (UIImage) -> Void

    @State private var currentScale: CGFloat = 1.0
    @State private var previousScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var previousOffset: CGSize = .zero

    // Circle crop area diameter
    private let cropDiameter: CGFloat = 280

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Instructions
                    Text("Position and scale your logo")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.vertical, 20)

                    Spacer()

                    // Crop area
                    GeometryReader { geometry in
                        let size = geometry.size

                        ZStack {
                            // The image that can be panned and zoomed
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(currentScale)
                                .offset(currentOffset)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / previousScale
                                            previousScale = value
                                            currentScale = max(1.0, currentScale * delta)
                                        }
                                        .onEnded { _ in
                                            previousScale = 1.0
                                        }
                                )
                                .simultaneousGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            currentOffset = CGSize(
                                                width: previousOffset.width + value.translation.width,
                                                height: previousOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            previousOffset = currentOffset
                                        }
                                )

                            // Dimming overlay with circular cutout
                            Circle()
                                .frame(width: cropDiameter, height: cropDiameter)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                        .background(Color.black.opacity(0.75))
                        .frame(width: size.width, height: size.height)

                        // Circular border to show crop area
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: cropDiameter, height: cropDiameter)
                            .position(x: size.width / 2, y: size.height / 2)

                        // Grid lines for alignment
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            .frame(width: cropDiameter, height: cropDiameter)
                            .position(x: size.width / 2, y: size.height / 2)

                        Path { path in
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            let radius = cropDiameter / 2

                            // Horizontal center line
                            path.move(to: CGPoint(x: center.x - radius, y: center.y))
                            path.addLine(to: CGPoint(x: center.x + radius, y: center.y))

                            // Vertical center line
                            path.move(to: CGPoint(x: center.x, y: center.y - radius))
                            path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                        }
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    }
                    .frame(height: 400)

                    Spacer()

                    // Reset button
                    Button(action: resetTransform) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Crop Logo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        cropImage()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func resetTransform() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentScale = 1.0
            previousScale = 1.0
            currentOffset = .zero
            previousOffset = .zero
        }
    }

    private func cropImage() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropDiameter, height: cropDiameter))

        let croppedImage = renderer.image { context in
            let cgContext = context.cgContext

            // Create circular clipping path
            cgContext.addEllipse(in: CGRect(x: 0, y: 0, width: cropDiameter, height: cropDiameter))
            cgContext.clip()

            // Calculate the transform to apply to the image
            let imageSize = image.size
            let imageAspect = imageSize.width / imageSize.height

            // Determine base size (how the image would be displayed "scaledToFit" in the view)
            let viewWidth: CGFloat = UIScreen.main.bounds.width
            let viewHeight: CGFloat = 400

            var baseWidth: CGFloat
            var baseHeight: CGFloat

            let viewAspect = viewWidth / viewHeight

            if imageAspect > viewAspect {
                // Image is wider than view
                baseWidth = viewWidth
                baseHeight = viewWidth / imageAspect
            } else {
                // Image is taller than view
                baseHeight = viewHeight
                baseWidth = viewHeight * imageAspect
            }

            // Apply scale
            let scaledWidth = baseWidth * currentScale
            let scaledHeight = baseHeight * currentScale

            // Calculate where the image starts in the view
            let imageX = (viewWidth - scaledWidth) / 2 + currentOffset.width
            let imageY = (viewHeight - scaledHeight) / 2 + currentOffset.height

            // Calculate the crop area center in view coordinates
            let cropCenterX = viewWidth / 2
            let cropCenterY = viewHeight / 2

            // Calculate the crop area in image coordinates
            let cropX = cropCenterX - cropDiameter / 2
            let cropY = cropCenterY - cropDiameter / 2

            // Transform from view coordinates to image coordinates
            let imageInViewRect = CGRect(x: imageX, y: imageY, width: scaledWidth, height: scaledHeight)
            let cropInViewRect = CGRect(x: cropX, y: cropY, width: cropDiameter, height: cropDiameter)

            // Draw the portion of the image that appears in the crop circle
            let drawX = -(cropInViewRect.minX - imageInViewRect.minX)
            let drawY = -(cropInViewRect.minY - imageInViewRect.minY)

            let drawRect = CGRect(x: drawX, y: drawY, width: scaledWidth, height: scaledHeight)
            image.draw(in: drawRect)
        }

        onCrop(croppedImage)
        dismiss()
    }
}
