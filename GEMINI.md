# Project: ShowCard

## Project Overview

ShowCard is a SwiftUI application for iOS that allows users to store and manage digital versions of physical cards. The app provides the following features:

*   **Card Management:** Users can add, edit, and delete cards. Each card consists of a name and an associated image.
*   **Image Importing:** Images for cards can be imported from the user's photo library or captured directly with the device's camera.
*   **Advanced Image Cropping:** The app includes a sophisticated image cropping tool that allows for perspective correction. This is ideal for capturing images of cards at an angle and having them appear as if they were scanned flat.
*   **Data Persistence:** The user's card collection is saved locally on the device using `UserDefaults`.

The application is structured with a main `ContentView` that displays the list of cards, an `AddCardView` for adding new cards, a `CardDetailView` to show a card in full screen, and a `CropView` for the image editing functionality.

## Building and Running

This is an Xcode project. To build and run the application, follow these steps:

1.  **Open the project in Xcode:**
    *   Double-click the `ShowCard.xcodeproj` file to open it in Xcode.

2.  **Select a simulator or device:**
    *   In the Xcode toolbar, choose an iOS Simulator (e.g., "iPhone 15 Pro") or a connected physical iOS device as the run destination.

3.  **Run the app:**
    *   Click the "Run" button (the triangle icon) in the Xcode toolbar or press `Cmd+R`.

Alternatively, you can use the `xcodebuild` command-line tool, but running from Xcode is recommended for development.

## Development Conventions

*   **SwiftUI:** The user interface is built entirely with SwiftUI.
*   **Data Flow:** The app uses SwiftUI's property wrappers like `@State` and `@Binding` to manage the state of the views. The list of cards is passed down through the view hierarchy.
*   **Model:** The `Card` struct is a simple `Codable` model, which allows it to be easily encoded to and decoded from `UserDefaults`.
*   **Views:** The code is organized into several distinct SwiftUI views, each with a specific responsibility.
*   **Image Handling:** The app uses `UIImagePickerController` (wrapped in a `UIViewControllerRepresentable`) to pick images and Core Image filters for the perspective correction in the `CropView`.
