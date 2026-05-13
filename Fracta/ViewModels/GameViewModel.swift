import Foundation
import SwiftUI
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    @Published var currentLevel: Level?
    @Published var pieces: [PuzzlePiece] = []
    @Published var selectedPiece: PuzzlePiece?
    @Published var moveCount: Int = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var isGameComplete: Bool = false
    @Published var isPaused: Bool = false
    
    private var timer: Timer?
    private var startTime: Date?
    private let storageService = StorageService.shared
    private let hapticService = HapticService.shared
    
    var isLevelComplete: Bool {
        for piece in pieces {
            guard let pieceAtTarget = pieces.first(where: { $0.currentPosition == piece.targetPosition }) else {
                return false
            }
            if pieceAtTarget.shape != piece.shape {
                return false
            }
        }
        return true
    }
    
    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var starsEarned: Int {
        guard let level = currentLevel else { return 0 }
        
        let movesScore: Int
        if moveCount <= level.targetMoves {
            movesScore = 3
        } else if moveCount <= level.targetMoves + 5 {
            movesScore = 2
        } else {
            movesScore = 1
        }
        
        let timeScore: Int
        if elapsedTime <= level.targetTime {
            timeScore = 3
        } else if elapsedTime <= level.targetTime * 1.5 {
            timeScore = 2
        } else {
            timeScore = 1
        }
        
        return min(movesScore, timeScore)
    }
    
    func startLevel(_ level: Level) {
        currentLevel = level
        var usedPositions: Set<GridPosition> = []
        var newPieces: [PuzzlePiece] = []
        
        for piece in level.pieces {
            var mutablePiece = piece
            var newPosition: GridPosition
            repeat {
                newPosition = GridPosition(
                    row: Int.random(in: 0..<level.gridSize),
                    column: Int.random(in: 0..<level.gridSize)
                )
            } while usedPositions.contains(newPosition)
            usedPositions.insert(newPosition)
            mutablePiece.currentPosition = newPosition
            newPieces.append(mutablePiece)
        }
        
        pieces = newPieces
        moveCount = 0
        elapsedTime = 0
        isGameComplete = false
        isPaused = false
        startTimer()
    }
    
    func selectPiece(_ piece: PuzzlePiece) {
        if selectedPiece?.id == piece.id {
            selectedPiece = nil
        } else {
            selectedPiece = piece
            hapticService.selection()
        }
    }
    
    func movePiece(to position: GridPosition) {
        guard let selected = selectedPiece,
              let index = pieces.firstIndex(where: { $0.id == selected.id }),
              let level = currentLevel else { return }
        
        guard position.row >= 0 && position.row < level.gridSize &&
              position.column >= 0 && position.column < level.gridSize else { return }
        
        if let existingPieceIndex = pieces.firstIndex(where: { $0.currentPosition == position && $0.id != selected.id }) {
            var updatedPieces = pieces
            updatedPieces[existingPieceIndex].currentPosition = selected.currentPosition
            updatedPieces[index].currentPosition = position
            pieces = updatedPieces
            
            moveCount += 1
            selectedPiece = nil
            hapticService.mediumImpact()
        } else {
            var updatedPieces = pieces
            updatedPieces[index].currentPosition = position
            pieces = updatedPieces
            
            moveCount += 1
            selectedPiece = nil
            
            if isPieceCorrectlyPlaced(pieces[index]) {
                hapticService.success()
            } else {
                hapticService.lightImpact()
            }
        }
        
        checkCompletion()
    }
    
    func swapPieces(_ piece1: PuzzlePiece, _ piece2: PuzzlePiece) {
        guard let index1 = pieces.firstIndex(where: { $0.id == piece1.id }),
              let index2 = pieces.firstIndex(where: { $0.id == piece2.id }) else { return }
        
        var updatedPieces = pieces
        let tempPosition = updatedPieces[index1].currentPosition
        updatedPieces[index1].currentPosition = updatedPieces[index2].currentPosition
        updatedPieces[index2].currentPosition = tempPosition
        pieces = updatedPieces
        
        moveCount += 1
        selectedPiece = nil
        hapticService.mediumImpact()
        
        checkCompletion()
    }
    
    func isPieceCorrectlyPlaced(_ piece: PuzzlePiece) -> Bool {
        guard let targetPiece = pieces.first(where: { $0.targetPosition == piece.currentPosition }) else {
            return false
        }
        return targetPiece.shape == piece.shape
    }
    
    private func checkCompletion() {
        if isLevelComplete {
            stopTimer()
            isGameComplete = true
            hapticService.success()
            saveProgress()
        }
    }
    
    private func saveProgress() {
        guard let level = currentLevel else { return }
        
        var stats = storageService.loadGameStats()
        stats.updateAfterLevel(levelId: level.id, moves: moveCount, time: elapsedTime, targetMoves: level.targetMoves)
        storageService.saveGameStats(stats)
        
        var settings = storageService.loadUserSettings()
        if level.id < Level.allLevels.count {
            settings.unlockLevel(level.id + 1)
        }
        storageService.saveUserSettings(settings)
    }
    
    private func startTimer() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isPaused else { return }
                if let start = self.startTime {
                    self.elapsedTime = Date().timeIntervalSince(start)
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func pauseGame() {
        isPaused = true
    }
    
    func resumeGame() {
        isPaused = false
    }
    
    func resetLevel() {
        guard let level = currentLevel else { return }
        startLevel(level)
        hapticService.mediumImpact()
    }
    
    deinit {
        timer?.invalidate()
    }
}
