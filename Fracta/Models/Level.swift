import Foundation

enum ColorTheme: String, CaseIterable, Codable {
    case ocean
    case sunset
    case forest
    case lavender
    case midnight
    case coral
    
    var isDark: Bool {
        self == .midnight
    }
    
    var primaryColor: String {
        switch self {
        case .ocean: return "#1A73E8"
        case .sunset: return "#FF6B35"
        case .forest: return "#2D6A4F"
        case .lavender: return "#7B68EE"
        case .midnight: return "#5DADE2"
        case .coral: return "#FF7F7F"
        }
    }
    
    var secondaryColor: String {
        switch self {
        case .ocean: return "#4FC3F7"
        case .sunset: return "#FFD166"
        case .forest: return "#95D5B2"
        case .lavender: return "#DDA0DD"
        case .midnight: return "#85C1E9"
        case .coral: return "#FFB6C1"
        }
    }
    
    var backgroundColor: String {
        switch self {
        case .ocean: return "#E3F2FD"
        case .sunset: return "#FFF3E0"
        case .forest: return "#E8F5E9"
        case .lavender: return "#F3E5F5"
        case .midnight: return "#1E2A3A"
        case .coral: return "#FFF0F5"
        }
    }
    
    var accentColor: String {
        switch self {
        case .ocean: return "#0D47A1"
        case .sunset: return "#E65100"
        case .forest: return "#1B5E20"
        case .lavender: return "#4A148C"
        case .midnight: return "#00D4FF"
        case .coral: return "#C71585"
        }
    }
    
    var subtleTextColor: String {
        switch self {
        case .midnight: return "#B0BEC5"
        default: return "#9E9E9E"
        }
    }
    
    var displayName: String {
        switch self {
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        case .lavender: return "Lavender"
        case .midnight: return "Midnight"
        case .coral: return "Coral"
        }
    }
}

struct Level: Identifiable, Codable {
    let id: Int
    let name: String
    let gridSize: Int
    let theme: ColorTheme
    let targetMoves: Int
    let targetTime: TimeInterval
    let pieces: [PuzzlePiece]
    
    static let allLevels: [Level] = [
        Level(id: 1, name: "First Steps", gridSize: 3, theme: .ocean, targetMoves: 10, targetTime: 30, pieces: PuzzlePiece.generatePieces(count: 4, gridSize: 3)),
        Level(id: 2, name: "Rising Tide", gridSize: 3, theme: .ocean, targetMoves: 15, targetTime: 45, pieces: PuzzlePiece.generatePieces(count: 5, gridSize: 3)),
        Level(id: 3, name: "Golden Hour", gridSize: 4, theme: .sunset, targetMoves: 20, targetTime: 60, pieces: PuzzlePiece.generatePieces(count: 6, gridSize: 4)),
        Level(id: 4, name: "Warm Glow", gridSize: 4, theme: .sunset, targetMoves: 25, targetTime: 75, pieces: PuzzlePiece.generatePieces(count: 7, gridSize: 4)),
        Level(id: 5, name: "Deep Woods", gridSize: 4, theme: .forest, targetMoves: 30, targetTime: 90, pieces: PuzzlePiece.generatePieces(count: 8, gridSize: 4)),
        Level(id: 6, name: "Emerald Path", gridSize: 5, theme: .forest, targetMoves: 35, targetTime: 105, pieces: PuzzlePiece.generatePieces(count: 9, gridSize: 5)),
        Level(id: 7, name: "Purple Haze", gridSize: 5, theme: .lavender, targetMoves: 40, targetTime: 120, pieces: PuzzlePiece.generatePieces(count: 10, gridSize: 5)),
        Level(id: 8, name: "Violet Dreams", gridSize: 5, theme: .lavender, targetMoves: 45, targetTime: 135, pieces: PuzzlePiece.generatePieces(count: 11, gridSize: 5)),
        Level(id: 9, name: "Night Sky", gridSize: 6, theme: .midnight, targetMoves: 50, targetTime: 150, pieces: PuzzlePiece.generatePieces(count: 12, gridSize: 6)),
        Level(id: 10, name: "Starlight", gridSize: 6, theme: .midnight, targetMoves: 55, targetTime: 165, pieces: PuzzlePiece.generatePieces(count: 13, gridSize: 6)),
        Level(id: 11, name: "Coral Reef", gridSize: 6, theme: .coral, targetMoves: 60, targetTime: 180, pieces: PuzzlePiece.generatePieces(count: 14, gridSize: 6)),
        Level(id: 12, name: "Pink Paradise", gridSize: 7, theme: .coral, targetMoves: 70, targetTime: 210, pieces: PuzzlePiece.generatePieces(count: 16, gridSize: 7))
    ]
}

struct PuzzlePiece: Identifiable, Codable, Equatable {
    let id: UUID
    var currentPosition: GridPosition
    let targetPosition: GridPosition
    let shape: PieceShape
    
    var isCorrect: Bool {
        currentPosition == targetPosition
    }
    
    static func generatePieces(count: Int, gridSize: Int) -> [PuzzlePiece] {
        var pieces: [PuzzlePiece] = []
        var usedPositions: Set<GridPosition> = []
        
        for _ in 0..<count {
            var targetPos: GridPosition
            repeat {
                targetPos = GridPosition(row: Int.random(in: 0..<gridSize), column: Int.random(in: 0..<gridSize))
            } while usedPositions.contains(targetPos)
            usedPositions.insert(targetPos)
            
            var currentPos: GridPosition
            repeat {
                currentPos = GridPosition(row: Int.random(in: 0..<gridSize), column: Int.random(in: 0..<gridSize))
            } while currentPos == targetPos
            
            let shape = PieceShape.allCases.randomElement() ?? .triangle
            pieces.append(PuzzlePiece(id: UUID(), currentPosition: currentPos, targetPosition: targetPos, shape: shape))
        }
        
        return pieces
    }
}

struct GridPosition: Codable, Equatable, Hashable {
    let row: Int
    let column: Int
}

enum PieceShape: String, CaseIterable, Codable {
    case triangle
    case square
    case circle
    case diamond
    case hexagon
    case star
}
