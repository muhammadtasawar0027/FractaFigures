import SwiftUI

struct GameView: View {
    let level: Level
    @ObservedObject var settingsViewModel: SettingsViewModel
    @StateObject private var viewModel = GameViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showCompletion = false
    
    private var theme: ColorTheme {
        level.theme
    }
    
    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(level.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primary)
                        
                        Text("Target: \(level.targetMoves) moves")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(viewModel.formattedTime)
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.primary)
                        
                        Text("Moves: \(viewModel.moveCount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondary)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                GameGridView(
                    gridSize: level.gridSize,
                    pieces: viewModel.pieces,
                    selectedPiece: viewModel.selectedPiece,
                    theme: theme,
                    onPieceTap: { piece in
                        if let selected = viewModel.selectedPiece, selected.id != piece.id {
                            viewModel.swapPieces(selected, piece)
                        } else {
                            viewModel.selectPiece(piece)
                        }
                    },
                    onCellTap: { position in
                        viewModel.movePiece(to: position)
                    }
                )
                .padding()
                
                Spacer()
                
                HStack(spacing: 20) {
                    GameControlButton(icon: "arrow.counterclockwise", theme: theme) {
                        viewModel.resetLevel()
                    }
                }
                .padding(.bottom, 30)
            }
            
            if showCompletion {
                CompletionOverlay(
                    moves: viewModel.moveCount,
                    time: viewModel.formattedTime,
                    stars: viewModel.starsEarned,
                    theme: theme,
                    onNextLevel: {
                        showCompletion = false
                        if level.id < Level.allLevels.count {
                            dismiss()
                        }
                    },
                    onReplay: {
                        showCompletion = false
                        viewModel.resetLevel()
                    },
                    onMenu: {
                        showCompletion = false
                        dismiss()
                    }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    HapticService.shared.lightImpact()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .onAppear {
            OrientationManager.shared.lockToPortrait()
            viewModel.startLevel(level)
        }
        .onChange(of: viewModel.isGameComplete) { isComplete in
            if isComplete {
                withAnimation(.spring()) {
                    showCompletion = true
                }
            }
        }
    }
}

struct GameGridView: View {
    let gridSize: Int
    let pieces: [PuzzlePiece]
    let selectedPiece: PuzzlePiece?
    let theme: ColorTheme
    let onPieceTap: (PuzzlePiece) -> Void
    let onCellTap: (GridPosition) -> Void
    
    private func isPieceCorrectlyPlaced(_ piece: PuzzlePiece, in allPieces: [PuzzlePiece]) -> Bool {
        guard let targetPiece = allPieces.first(where: { $0.targetPosition == piece.currentPosition }) else {
            return false
        }
        return targetPiece.shape == piece.shape
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let cellSize = size / CGFloat(gridSize)
            
            ZStack {
                ForEach(0..<gridSize, id: \.self) { row in
                    ForEach(0..<gridSize, id: \.self) { column in
                        let position = GridPosition(row: row, column: column)
                        let targetPiece = pieces.first { $0.targetPosition == position }
                        
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                targetPiece != nil ? theme.secondary.opacity(0.5) : theme.primary.opacity(0.2),
                                lineWidth: targetPiece != nil ? 2 : 1
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.background.opacity(0.5))
                            )
                            .frame(width: cellSize - 4, height: cellSize - 4)
                            .position(
                                x: CGFloat(column) * cellSize + cellSize / 2,
                                y: CGFloat(row) * cellSize + cellSize / 2
                            )
                            .onTapGesture {
                                onCellTap(position)
                            }
                        
                        if let target = targetPiece {
                            PieceShapeView(shape: target.shape, color: theme.secondary.opacity(0.3))
                                .frame(width: cellSize * 0.4, height: cellSize * 0.4)
                                .position(
                                    x: CGFloat(column) * cellSize + cellSize / 2,
                                    y: CGFloat(row) * cellSize + cellSize / 2
                                )
                        }
                    }
                }
                
                ForEach(pieces) { piece in
                    let isSelected = selectedPiece?.id == piece.id
                    let isCorrectlyPlaced = isPieceCorrectlyPlaced(piece, in: pieces)
                    
                    PieceShapeView(
                        shape: piece.shape,
                        color: isCorrectlyPlaced ? theme.accent : theme.primary
                    )
                    .frame(width: cellSize * 0.6, height: cellSize * 0.6)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .shadow(color: isSelected ? theme.primary.opacity(0.5) : .clear, radius: 8)
                    .position(
                        x: CGFloat(piece.currentPosition.column) * cellSize + cellSize / 2,
                        y: CGFloat(piece.currentPosition.row) * cellSize + cellSize / 2
                    )
                    .onTapGesture {
                        onPieceTap(piece)
                    }
                    .animation(.spring(response: 0.3), value: piece.currentPosition)
                    .animation(.spring(response: 0.2), value: isSelected)
                }
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct PieceShapeView: View {
    let shape: PieceShape
    let color: Color
    
    var body: some View {
        Group {
            switch shape {
            case .triangle:
                Triangle()
                    .fill(color)
            case .square:
                Rectangle()
                    .fill(color)
            case .circle:
                Circle()
                    .fill(color)
            case .diamond:
                Diamond()
                    .fill(color)
            case .hexagon:
                Hexagon()
                    .fill(color)
            case .star:
                Star()
                    .fill(color)
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct Star: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        
        for i in 0..<10 {
            let angle = CGFloat(i) * .pi / 5 - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct GameControlButton: View {
    let icon: String
    let theme: ColorTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(theme.primary)
                        .shadow(color: theme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                )
        }
    }
}

struct CompletionOverlay: View {
    let moves: Int
    let time: String
    let stars: Int
    let theme: ColorTheme
    let onNextLevel: () -> Void
    let onReplay: () -> Void
    let onMenu: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("Level Complete!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 40))
                            .foregroundColor(index < stars ? .yellow : .gray)
                    }
                }
                
                VStack(spacing: 8) {
                    Text("Moves: \(moves)")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Time: \(time)")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                VStack(spacing: 12) {
                    Button(action: onNextLevel) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(theme.primary)
                            )
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: onReplay) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(theme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.primary, lineWidth: 2)
                                )
                        }
                        
                        Button(action: onMenu) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(theme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.primary, lineWidth: 2)
                                )
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.8))
            )
            .padding(24)
        }
    }
}
