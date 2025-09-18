import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct Quadrilateral: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count == 4 else { return path }
        path.move(to: points[0])
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

struct Handle: View {
    var body: some View {
        Circle()
            .frame(width: 40, height: 40)
            .foregroundColor(.white)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
    }
}

struct MagnifierView: View {
    let image: UIImage
    let position: CGPoint
    let imageFrame: CGRect
    private let magnification: CGFloat = 2.0
    private let size: CGFloat = 100

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .frame(width: imageFrame.width, height: imageFrame.height)
                .scaleEffect(magnification)
                .offset(
                    x: (imageFrame.midX - position.x) * magnification,
                    y: (imageFrame.midY - position.y) * magnification
                )
        }
        .frame(width: size, height: size)
        .background(Color.white)
        .clipShape(Circle())
        .shadow(radius: 5)
        .overlay(Circle().stroke(Color.gray, lineWidth: 2))
        .overlay(
            ZStack {
                Rectangle().fill(Color.black).frame(width: 2, height: size)
                Rectangle().fill(Color.black).frame(width: size, height: 2)
            }
        )
    }
}

enum DraggedCorner {
    case topLeft, topRight, bottomLeft, bottomRight, none
}

struct CropView: View {
    var image: UIImage
    var onCropped: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var topLeft = CGPoint.zero
    @State private var topRight = CGPoint.zero
    @State private var bottomLeft = CGPoint.zero
    @State private var bottomRight = CGPoint.zero
    @State private var imageFrame: CGRect = .zero // To store the frame of the displayed image
    @State private var initialTopLeft = CGPoint.zero
    @State private var initialTopRight = CGPoint.zero
    @State private var initialBottomLeft = CGPoint.zero
    @State private var initialBottomRight = CGPoint.zero
    @State private var isConvex = true
    @State private var draggedCorner: DraggedCorner = .none
    @State private var dragPosition: CGPoint = .zero

    var body: some View {
        VStack {
            HStack {
                Button("Reset") {
                    self.topLeft = self.initialTopLeft
                    self.topRight = self.initialTopRight
                    self.bottomLeft = self.initialBottomLeft
                    self.bottomRight = self.initialBottomRight
                    self.isConvex = true
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(10)
                .foregroundColor(.black)
                Spacer()
                Button("Done") {
                    if isConvex, let croppedImage = cropAndRedress(image: image, topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, imageFrame: imageFrame) {
                        onCropped(croppedImage)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(10)
                .foregroundColor(.black)
            }
            .padding()

            GeometryReader { geometry in
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            Rectangle()
                                .fill(isConvex ? Color.clear : Color.red.opacity(0.3))
                        )

                    Quadrilateral(points: [topLeft, topRight, bottomRight, bottomLeft])
                        .stroke(isConvex ? Color.blue : Color.red, lineWidth: 2)

                    Handle()
                        .position(topLeft)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPosition = CGPoint(
                                        x: min(max(value.location.x, imageFrame.minX), imageFrame.maxX),
                                        y: min(max(value.location.y, imageFrame.minY), imageFrame.maxY)
                                    )
                                    self.topLeft = newPosition
                                    self.draggedCorner = .topLeft
                                    self.dragPosition = newPosition
                                    self.isConvex = isQuadrilateralConvex()
                                }
                                .onEnded { _ in
                                    self.draggedCorner = .none
                                }
                        )

                    Handle()
                        .position(topRight)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPosition = CGPoint(
                                        x: min(max(value.location.x, imageFrame.minX), imageFrame.maxX),
                                        y: min(max(value.location.y, imageFrame.minY), imageFrame.maxY)
                                    )
                                    self.topRight = newPosition
                                    self.draggedCorner = .topRight
                                    self.dragPosition = newPosition
                                    self.isConvex = isQuadrilateralConvex()
                                }
                                .onEnded { _ in
                                    self.draggedCorner = .none
                                }
                        )

                    Handle()
                        .position(bottomLeft)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPosition = CGPoint(
                                        x: min(max(value.location.x, imageFrame.minX), imageFrame.maxX),
                                        y: min(max(value.location.y, imageFrame.minY), imageFrame.maxY)
                                    )
                                    self.bottomLeft = newPosition
                                    self.draggedCorner = .bottomLeft
                                    self.dragPosition = newPosition
                                    self.isConvex = isQuadrilateralConvex()
                                }
                                .onEnded { _ in
                                    self.draggedCorner = .none
                                }
                        )

                    Handle()
                        .position(bottomRight)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPosition = CGPoint(
                                        x: min(max(value.location.x, imageFrame.minX), imageFrame.maxX),
                                        y: min(max(value.location.y, imageFrame.minY), imageFrame.maxY)
                                    )
                                    self.bottomRight = newPosition
                                    self.draggedCorner = .bottomRight
                                    self.dragPosition = newPosition
                                    self.isConvex = isQuadrilateralConvex()
                                }
                                .onEnded { _ in
                                    self.draggedCorner = .none
                                }
                        )
                    if !isConvex {
                        Text("Please adjust the points to form a convex shape.")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                    }
                    
                    if draggedCorner != .none {
                        MagnifierView(image: image, position: dragPosition, imageFrame: imageFrame)
                            .position(x: dragPosition.x, y: dragPosition.y - 80)
                    }
                }
                .onAppear {
                    // Calculate the frame of the displayed image
                    let viewSize = geometry.size
                    let imageSize = image.size

                    let aspectRatio = imageSize.width / imageSize.height
                    let viewAspectRatio = viewSize.width / viewSize.height

                    var displayedImageRect: CGRect

                    if viewAspectRatio > aspectRatio {
                        // Image is constrained by height, width is smaller
                        let scaledWidth = viewSize.height * aspectRatio
                        let xOffset = (viewSize.width - scaledWidth) / 2
                        displayedImageRect = CGRect(x: xOffset, y: 0, width: scaledWidth, height: viewSize.height)
                    } else {
                        // Image is constrained by width, height is smaller
                        let scaledHeight = viewSize.width / aspectRatio
                        let yOffset = (viewSize.height - scaledHeight) / 2
                        displayedImageRect = CGRect(x: 0, y: yOffset, width: viewSize.width, height: scaledHeight)
                    }
                    self.imageFrame = displayedImageRect

                    // Initialize corner points to the corners of the displayed image
                    self.topLeft = displayedImageRect.origin
                    self.topRight = CGPoint(x: displayedImageRect.maxX, y: displayedImageRect.minY)
                    self.bottomLeft = CGPoint(x: displayedImageRect.minX, y: displayedImageRect.maxY)
                    self.bottomRight = CGPoint(x: displayedImageRect.maxX, y: displayedImageRect.maxY)
                    
                    self.initialTopLeft = self.topLeft
                    self.initialTopRight = self.topRight
                    self.initialBottomLeft = self.bottomLeft
                    self.initialBottomRight = self.bottomRight
                }
            }
            .padding(40)
        }
    }
    
    func isQuadrilateralConvex() -> Bool {
        let points = [topLeft, topRight, bottomRight, bottomLeft]
        guard points.count == 4 else { return false }

        let sign = crossProduct(points[3], points[0], points[1]) > 0
        for i in 0..<3 {
            if (crossProduct(points[i], points[i+1], points[(i+2)%4]) > 0) != sign {
                return false
            }
        }
        return true
    }

    func crossProduct(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGFloat {
        return (p2.x - p1.x)*(p3.y - p1.y) - (p2.y - p1.y)*(p3.x - p1.x)
    }
    
    func convertViewPointToImagePoint(viewPoint: CGPoint, imageFrame: CGRect, originalImageSize: CGSize) -> CGPoint {
        let scaleX = originalImageSize.width / imageFrame.width
        let scaleY = originalImageSize.height / imageFrame.height

        let imageX = (viewPoint.x - imageFrame.minX) * scaleX
        let imageY = (viewPoint.y - imageFrame.minY) * scaleY

        // Core Image uses a bottom-left origin, so invert the Y coordinate
        let convertedPoint = CGPoint(x: imageX, y: originalImageSize.height - imageY)
        return convertedPoint
    }

    func cropAndRedress(image: UIImage, topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, imageFrame: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage).oriented(forExifOrientation: image.exifOrientation)

        let originalImageSize = ciImage.extent.size

        let imageTopLeft = convertViewPointToImagePoint(viewPoint: topLeft, imageFrame: imageFrame, originalImageSize: originalImageSize)
        let imageTopRight = convertViewPointToImagePoint(viewPoint: topRight, imageFrame: imageFrame, originalImageSize: originalImageSize)
        let imageBottomLeft = convertViewPointToImagePoint(viewPoint: bottomLeft, imageFrame: imageFrame, originalImageSize: originalImageSize)
        let imageBottomRight = convertViewPointToImagePoint(viewPoint: bottomRight, imageFrame: imageFrame, originalImageSize: originalImageSize)

        let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")!
        perspectiveCorrection.setValue(CIVector(cgPoint: imageTopLeft), forKey: "inputTopLeft")
        perspectiveCorrection.setValue(CIVector(cgPoint: imageTopRight), forKey: "inputTopRight")
        perspectiveCorrection.setValue(CIVector(cgPoint: imageBottomRight), forKey: "inputBottomRight")
        perspectiveCorrection.setValue(CIVector(cgPoint: imageBottomLeft), forKey: "inputBottomLeft")
        perspectiveCorrection.setValue(ciImage, forKey: kCIInputImageKey)

        if let outputImage = perspectiveCorrection.outputImage {
            let context = CIContext(options: nil)
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
            }
        }
        return nil
    }
}

extension UIImage {
    var exifOrientation: Int32 {
        switch imageOrientation {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 1
        }
    }
}

#Preview {
    CropView(image: UIImage(systemName: "photo")!) { _ in }
}