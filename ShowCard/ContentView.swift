import SwiftUI
import UniformTypeIdentifiers

struct CardImage: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var imageData: Data
    var originalImageData: Data
    var zoomLevel: CGFloat?
}

struct Card: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var images: [CardImage]
    var backgroundColor: String?
}

// Used for migrating old data
struct OldCard: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var imageData: Data
    var originalImageData: Data
}

struct ImagePickerSource: Identifiable {
    var id = UUID()
    var sourceType: UIImagePickerController.SourceType
}

struct ContentView: View {
    @State private var cards: [Card]
    @State private var selectedCard: Card?
    @State private var isShowingAddCardView = false

    init() {
        if let data = UserDefaults.standard.data(forKey: "cards") {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([Card].self, from: data) {
                _cards = State(initialValue: decoded)
                return
            }
            
            if let oldDecoded = try? decoder.decode([OldCard].self, from: data) {
                let migratedCards = oldDecoded.map {
                    Card(id: $0.id, name: $0.name, images: [CardImage(name: "Front", imageData: $0.imageData, originalImageData: $0.originalImageData)])
                }
                _cards = State(initialValue: migratedCards)
                
                let encoder = JSONEncoder()
                if let encoded = try? encoder.encode(migratedCards) {
                    UserDefaults.standard.set(encoded, forKey: "cards")
                }
                return
            }
        }
        _cards = State(initialValue: [])
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(cards) { card in
                    Button(action: {
                        selectedCard = card
                    }) {
                        HStack {
                            if let firstImage = card.images.first, let uiImage = UIImage(data: firstImage.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 30)
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(Color.gray)
                                    .frame(width: 50, height: 30)
                            }
                            Text(card.name)
                        }
                    }
                }
                .onDelete(perform: delete)
                .onMove(perform: move)
            }
            .navigationTitle("My Cards")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddCardView = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddCardView) {
                AddCardView(cards: $cards)
            }
            .sheet(item: $selectedCard) { card in
                if let index = cards.firstIndex(where: { $0.id == card.id }) {
                    CardDetailView(card: $cards[index], cards: $cards)
                }
            }
        }
    }

    func delete(at offsets: IndexSet) {
        cards.remove(atOffsets: offsets)
        saveCards()
    }

    func move(from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
        saveCards()
    }

    func saveCards() {
        if let encoded = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(encoded, forKey: "cards")
        }
    }
}

struct AddCardView: View {
    @Binding var cards: [Card]
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var images: [CardImage] = []
    @State private var isShowingAddImageView = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Card Name")) {
                    TextField(NSLocalizedString("Card Name", comment: ""), text: $name)
                }
                
                Section(header: Text("Images")) {
                    ForEach(images) { image in
                        HStack {
                            Image(uiImage: UIImage(data: image.imageData) ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 30)
                                .clipped()
                            Text(image.name)
                        }
                    }
                    .onDelete(perform: deleteImage)
                    .onMove(perform: moveImage)
                    
                    Button(NSLocalizedString("Add New Image", comment: "")) {
                        isShowingAddImageView = true
                    }
                }
            }
            .navigationTitle("New Card")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCard()
                    }
                    .disabled(name.isEmpty || images.isEmpty)
                }
            }
            .sheet(isPresented: $isShowingAddImageView) {
                AddImageToNewCardView(images: $images)
            }
        }
    }
    
    func deleteImage(at offsets: IndexSet) {
        images.remove(atOffsets: offsets)
    }

    func moveImage(from source: IndexSet, to destination: Int) {
        images.move(fromOffsets: source, toOffset: destination)
    }

    func saveCard() {
        let newCard = Card(name: name, images: images)
        cards.insert(newCard, at: 0)
        if let encoded = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(encoded, forKey: "cards")
        }
        presentationMode.wrappedValue.dismiss()
    }
}

struct AddImageToNewCardView: View {
    @Binding var images: [CardImage]
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var image: UIImage?
    @State private var originalImage: UIImage?
    @State private var isShowingCropView = false
    @State private var imagePickerSource: ImagePickerSource?

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    TextField(NSLocalizedString("Image Name", comment: ""), text: $name)
                }
                .frame(maxHeight: 80)

                HStack(spacing: 20) {
                    Button(action: {
                        self.imagePickerSource = ImagePickerSource(sourceType: .photoLibrary)
                    }) {
                        VStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.largeTitle)
                            Text(NSLocalizedString("Photo Library", comment: ""))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }

                    Button(action: {
                        self.imagePickerSource = ImagePickerSource(sourceType: .camera)
                    }) {
                        VStack {
                            Image(systemName: "camera")
                                .font(.largeTitle)
                            Text(NSLocalizedString("Camera", comment: ""))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)

                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .padding()
                    Button(NSLocalizedString("Crop Image", comment: "")) {
                        isShowingCropView = true
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Add Image")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveImage()
                    }
                    .disabled(image == nil)
                }
            }
            .sheet(item: $imagePickerSource) { source in
                ImagePicker(sourceType: source.sourceType) { image in
                    self.image = image
                    self.originalImage = image
                }
            }
            .sheet(isPresented: $isShowingCropView) {
                if let originalImage = originalImage {
                    CropView(image: originalImage) { croppedImage in
                        self.image = croppedImage
                    }
                }
            }
        }
    }

    func saveImage() {
        guard let image = image,
              let imageData = image.jpegData(compressionQuality: 0.8),
              let originalImage = originalImage,
              let originalImageData = originalImage.jpegData(compressionQuality: 0.8) else {
            return
        }
        let newImage = CardImage(name: name, imageData: imageData, originalImageData: originalImageData)
        images.append(newImage)
        presentationMode.wrappedValue.dismiss()
    }
}

struct EditCardView: View {
    @Binding var card: Card
    @Binding var cards: [Card]
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String
    @State private var isShowingAddImageView = false

    init(card: Binding<Card>, cards: Binding<[Card]>) {
        self._card = card
        self._cards = cards
        self._name = State(initialValue: card.wrappedValue.name)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Card Name")) {
                    TextField("Card Name", text: $name)
                }
                
                Section(header: Text("Images")) {
                    ForEach($card.images) { $image in
                        NavigationLink(destination: EditImageView(image: $image)) {
                            HStack {
                                Image(uiImage: UIImage(data: image.imageData) ?? UIImage())
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 30)
                                    .clipped()
                                Text(image.name)
                            }
                        }
                    }
                    .onDelete(perform: deleteImage)
                    .onMove(perform: moveImage)
                    
                    Button(NSLocalizedString("Add New Image", comment: "")) {
                        isShowingAddImageView = true
                    }
                }
            }
            .navigationTitle("Edit Card")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCard()
                    }
                }
            }
            .sheet(isPresented: $isShowingAddImageView) {
                AddImageView(card: $card)
            }
        }
    }

    func deleteImage(at offsets: IndexSet) {
        if card.images.count > 1 {
            card.images.remove(atOffsets: offsets)
        }
    }

    func moveImage(from source: IndexSet, to destination: Int) {
        card.images.move(fromOffsets: source, toOffset: destination)
    }

    func saveCard() {
        card.name = name
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
        }
        if let encoded = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(encoded, forKey: "cards")
        }
        presentationMode.wrappedValue.dismiss()
    }
}

struct AddImageView: View {
    @Binding var card: Card
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var image: UIImage?
    @State private var originalImage: UIImage?
    @State private var isShowingCropView = false
    @State private var imagePickerSource: ImagePickerSource?

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    TextField("Image Name", text: $name)
                }
                .frame(maxHeight: 80)
                
                HStack(spacing: 20) {
                    Button(action: {
                        self.imagePickerSource = ImagePickerSource(sourceType: .photoLibrary)
                    }) {
                        VStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.largeTitle)
                            Text(NSLocalizedString("Photo Library", comment: ""))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }

                    Button(action: {
                        self.imagePickerSource = ImagePickerSource(sourceType: .camera)
                    }) {
                        VStack {
                            Image(systemName: "camera")
                                .font(.largeTitle)
                            Text(NSLocalizedString("Camera", comment: ""))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)

                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .padding()
                    Button(NSLocalizedString("Crop Image", comment: "")) {
                        isShowingCropView = true
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Add Image")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveImage()
                    }
                    .disabled(image == nil)
                }
            }
            .sheet(item: $imagePickerSource) { source in
                ImagePicker(sourceType: source.sourceType) { image in
                    self.image = image
                    self.originalImage = image
                }
            }
            .sheet(isPresented: $isShowingCropView) {
                if let originalImage = originalImage {
                    CropView(image: originalImage) { croppedImage in
                        self.image = croppedImage
                    }
                }
            }
        }
    }

    func saveImage() {
        guard let image = image,
              let imageData = image.jpegData(compressionQuality: 0.8),
              let originalImage = originalImage,
              let originalImageData = originalImage.jpegData(compressionQuality: 0.8) else {
            return
        }
        let newImage = CardImage(name: name, imageData: imageData, originalImageData: originalImageData)
        card.images.append(newImage)
        presentationMode.wrappedValue.dismiss()
    }
}

struct EditImageView: View {
    @Binding var image: CardImage
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String
    @State private var uiImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var isShowingCropView = false
    @State private var imagePickerSource: ImagePickerSource?

    init(image: Binding<CardImage>) {
        self._image = image
        self._name = State(initialValue: image.wrappedValue.name)
        self._uiImage = State(initialValue: UIImage(data: image.wrappedValue.imageData))
        self._originalImage = State(initialValue: UIImage(data: image.wrappedValue.originalImageData))
    }

    var body: some View {
        VStack {
            Form {
                TextField("Image Name", text: $name)
            }
            .frame(maxHeight: 80)
            
            HStack(spacing: 20) {
                Button(action: {
                    self.imagePickerSource = ImagePickerSource(sourceType: .photoLibrary)
                }) {
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.largeTitle)
                        Text(NSLocalizedString("Photo Library", comment: ""))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                }

                Button(action: {
                    self.imagePickerSource = ImagePickerSource(sourceType: .camera)
                }) {
                    VStack {
                        Image(systemName: "camera")
                            .font(.largeTitle)
                        Text(NSLocalizedString("Camera", comment: ""))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal)

            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .padding()
                Button(NSLocalizedString("Crop Image", comment: "")) {
                    isShowingCropView = true
                }
            }
            
            Spacer()
        }
        .navigationTitle("Edit Image")
        .toolbar {
            Button("Save") {
                saveImage()
            }
            .disabled(uiImage == nil)
        }
        .sheet(item: $imagePickerSource) { source in
            ImagePicker(sourceType: source.sourceType) { image in
                self.uiImage = image
                self.originalImage = image
            }
        }
        .sheet(isPresented: $isShowingCropView) {
            if let originalImage = originalImage {
                CropView(image: originalImage) { croppedImage in
                    self.uiImage = croppedImage
                }
            }
        }
    }

    func saveImage() {
        guard let uiImage = uiImage,
              let imageData = uiImage.jpegData(compressionQuality: 0.8),
              let originalImage = originalImage,
              let originalImageData = originalImage.jpegData(compressionQuality: 0.8) else {
            return
        }
        image.name = name
        image.imageData = imageData
        image.originalImageData = originalImageData
        presentationMode.wrappedValue.dismiss()
    }
}

struct CardDetailView: View {
    @Binding var card: Card
    @Binding var cards: [Card]
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingEditCardView = false
    @State private var currentImageIndex = 0

    private var isBlackBackground: Bool {
        (card.backgroundColor ?? "black") == "black"
    }

    var body: some View {
        ZStack {
            (isBlackBackground ? Color.black : Color.white).edgesIgnoringSafeArea(.all)

            if !card.images.isEmpty {
                TabView(selection: $currentImageIndex) {
                    ForEach(Array(card.images.enumerated()), id: \.element.id) { index, image in
                        VStack {
                            Text(image.name)
                                .foregroundColor(isBlackBackground ? .white : .black)
                                .font(.title)
                                .padding()
                            
                            if let uiImage = UIImage(data: image.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(image.zoomLevel ?? 1.0)
                            } else {
                                Text("Image not available")
                                    .foregroundColor(isBlackBackground ? .white : .black)
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle())
            } else {
                Text("No images for this card.")
                    .foregroundColor(isBlackBackground ? .white : .black)
            }
            
            VStack {
                HStack {
                    Button(action: {
                        toggleBackgroundColor()
                    }) {
                        Image(systemName: isBlackBackground ? "sun.max.fill" : "moon.fill")
                            .font(.largeTitle)
                            .foregroundColor(isBlackBackground ? .white : .black)
                    }
                    .padding()

                    Button(action: {
                        isShowingEditCardView = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.largeTitle)
                            .foregroundColor(isBlackBackground ? .white : .black)
                    }
                    .padding()
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(isBlackBackground ? .white : .black)
                    }
                    .padding()
                }
                Spacer()
                HStack {
                    Button(action: {
                        zoomOut()
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(isBlackBackground ? .white : .black)
                    }
                    .padding()

                    Button(action: {
                        zoomIn()
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(isBlackBackground ? .white : .black)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $isShowingEditCardView) {
            EditCardView(card: $card, cards: $cards)
        }
    }

    func toggleBackgroundColor() {
        if card.backgroundColor == "white" {
            card.backgroundColor = "black"
        } else {
            card.backgroundColor = "white"
        }
        saveCards()
    }

    func zoomIn() {
        let currentZoom = card.images[currentImageIndex].zoomLevel ?? 1.0
        card.images[currentImageIndex].zoomLevel = min(currentZoom + 0.1, 3.0)
        saveCards()
    }

    func zoomOut() {
        let currentZoom = card.images[currentImageIndex].zoomLevel ?? 1.0
        card.images[currentImageIndex].zoomLevel = max(currentZoom - 0.1, 0.5)
        saveCards()
    }

    func saveCards() {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
        }
        if let encoded = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(encoded, forKey: "cards")
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.onImagePicked(uiImage)
            }
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    ContentView()
}