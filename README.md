# Chess Desktop Analysis App

A feature-rich chess analysis application built with Flutter for desktop platforms.

## Features

- **Interactive Chess Board**
  - Drag and drop pieces to make moves
  - Click to select pieces and see legal moves highlighted
  - Flip board orientation
  - Professional PNG piece graphics

- **Variation Management**
  - Create multiple side lines from any position
  - Navigate through variations with arrow keys
  - Delete variations with confirmation
  - Track main line and side line positions

- **Analysis Tools**
  - Draw arrows on the board (right-click and drag)
  - Arrows are saved per position
  - Undo moves (different from navigation)
  - Material count display
  - Move list with navigation

- **PGN Support**
  - Load PGN files for analysis
  - Parse and display chess games

- **Stockfish Integration**
  - Chess engine analysis
  - Evaluation display

## Getting Started

### Prerequisites

- Flutter SDK (3.0 or higher)
- Dart SDK
- Platform-specific requirements:
  - Windows: Visual Studio 2022 or Visual Studio Build Tools
  - macOS: Xcode
  - Linux: CMake and GTK development libraries

### Installation

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/chess_desktop.git
cd chess_desktop
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run -d windows  # or macos, linux
```

## Usage

### Making Moves
- **Drag and Drop**: Click and drag a piece to a valid square
- **Click to Move**: Click a piece to select it (yellow highlight), then click a legal square (green highlight)

### Creating Variations
- Make a move from any position to automatically create a side line
- Multiple side lines can be created from the same position

### Drawing Arrows
- Hold right mouse button on a square and drag to another square
- Release to create an arrow
- Click the same arrow pattern again to remove it
- Arrows persist when you navigate away and return to the position

### Navigation
- **Arrow Keys**: Navigate through moves
- **Home/End**: Jump to start/end of current line
- **Flip Board**: Click the flip button to rotate the board

## Dependencies

- `chess`: Chess logic and move validation
- `provider`: State management
- `http`: Stockfish download
- `path_provider`: File system access
- `archive`: Archive extraction

## Project Structure

```
lib/
├── models/         # Data models (Variation, GameTree)
├── services/       # Services (Engine, Downloader)
├── state/          # State management (Controllers)
├── ui/            # UI components
│   ├── analysis_page.dart
│   ├── interactive_board_view.dart
│   ├── variations_panel.dart
│   └── ...
└── utils/         # Utilities (PGN parser)
```

## License

This project is open source and available under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
