// ArrowDrawing.swift - Fixed version with debugging and proper click detection
import SwiftUI
import AppKit
import Foundation

// MARK: - Coordinate System Handler
struct BoardCoordinateSystem {
    let boardSize: CGFloat
    
    // Convert NSView point to chess square
    func nsViewPointToSquare(_ point: CGPoint) -> Square? {
        let squareSize = boardSize / 8
        let fileIndex = Int(point.x / squareSize)
        
        // NSView has Y=0 at bottom, but our board visual has rank 8 at top
        // The board is created with (0..<8).reversed(), so:
        // - Visual top row = rankIndex 7 = rank 7
        // - Visual bottom row = rankIndex 0 = rank 0
        
        // Click at NSView bottom (y≈0) should map to rank 0
        // Click at NSView top (y≈boardSize) should map to rank 7
        let rankIndex = Int(point.y / squareSize)
        
        guard fileIndex >= 0, fileIndex < 8, rankIndex >= 0, rankIndex < 8,
              let file = File(rawValue: fileIndex),
              let rank = Rank(rawValue: rankIndex) else {
            return nil
        }
        
        return Square(file: file, rank: rank)
    }
    
    // Convert SwiftUI point to chess square
    func swiftUIPointToSquare(_ point: CGPoint) -> Square? {
        // SwiftUI has Y=0 at top, so we need to flip
        let flippedPoint = CGPoint(x: point.x, y: boardSize - point.y)
        return nsViewPointToSquare(flippedPoint)
    }
    
    // Convert chess square to visual center point (for SwiftUI)
    func squareToSwiftUIPoint(_ square: Square) -> CGPoint {
        let squareSize = boardSize / 8
        let x = CGFloat(square.file.rawValue) * squareSize + squareSize / 2
        // For SwiftUI: rank 8 should be at top (y=0), rank 1 at bottom
        let y = CGFloat(7 - square.rank.rawValue) * squareSize + squareSize / 2
        return CGPoint(x: x, y: y)
    }
    
    // Convert NSView mouse location to SwiftUI coordinates
    func nsViewToSwiftUI(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x, y: boardSize - point.y)
    }
}

// MARK: - Circle Highlight Data Structure
struct ChessCircle: Identifiable, Equatable {
    let id = UUID()
    let square: Square
    let color: Color
    
    static func == (lhs: ChessCircle, rhs: ChessCircle) -> Bool {
        return lhs.square == rhs.square
    }
}

struct ChessArrow: Identifiable, Equatable {
    let id = UUID()
    let from: Square
    let to: Square
    let color: Color
    
    static func == (lhs: ChessArrow, rhs: ChessArrow) -> Bool {
        return lhs.from == rhs.from && lhs.to == rhs.to
    }
}

// MARK: - Cursor Piece Manager
class CursorPieceManager: ObservableObject {
    @Published var cursorPiece: Piece? = nil
    @Published var cursorPosition: CGPoint = .zero
    @Published var isActive = false
    @Published var sourceSquare: Square? = nil
    
    func startCursorPiece(_ piece: Piece, from square: Square, at position: CGPoint) {
        cursorPiece = piece
        sourceSquare = square
        cursorPosition = position
        isActive = true
        NSLog("🎯 CURSOR MANAGER: Started cursor piece \(piece.type) from \(square) at \(position) - isActive: \(isActive)")
    }
    
    func updateCursorPosition(_ position: CGPoint) {
        if isActive {
            cursorPosition = position
            NSLog("🎯 CURSOR MANAGER: Updated position to \(position)")
            if let sourceSquare = sourceSquare {
                NSLog("🎯 CURSOR MANAGER: Source square is \(sourceSquare)")
            }
        }
    }
    
    func stopCursorPiece() {
        cursorPiece = nil
        sourceSquare = nil
        isActive = false
        print("🎯 CURSOR: Stopped cursor piece")
    }
}

// MARK: - Arrow Manager
class ArrowManager: ObservableObject {
    @Published var currentArrows: [ChessArrow] = []
    @Published var currentCircles: [ChessCircle] = []
    @Published var previewArrow: PreviewArrow? = nil
    @Published var isDrawing = false
    @Published private(set) var startSquare: Square? = nil
    
    // Store arrows and circles per move index
    private var arrowsByMoveIndex: [Int: [ChessArrow]] = [:]
    private var circlesByMoveIndex: [Int: [ChessCircle]] = [:]
    private var currentMoveIndex: Int = 0
    
    struct PreviewArrow {
        let from: Square
        let to: Square
        let color: Color
    }
    
    func setCurrentMove(_ moveIndex: Int) {
        // Save current arrows and circles to the previous move index
        if !currentArrows.isEmpty {
            arrowsByMoveIndex[currentMoveIndex] = currentArrows
        }
        if !currentCircles.isEmpty {
            circlesByMoveIndex[currentMoveIndex] = currentCircles
        }
        
        // Update to new move index
        currentMoveIndex = moveIndex
        
        // Load arrows and circles for the new move index
        currentArrows = arrowsByMoveIndex[moveIndex] ?? []
        currentCircles = circlesByMoveIndex[moveIndex] ?? []
        
        // Cancel any drawing in progress
        cancelDrawing()
        
        print("🔄 Arrow Manager: Switched to move \(moveIndex), loaded \(currentArrows.count) arrows, \(currentCircles.count) circles")
    }
    
    func startDrawing(from square: Square) {
        isDrawing = true
        startSquare = square
        previewArrow = nil
        print("🎯 Arrow Manager: Started drawing from \(square)")
    }
    
    func updatePreview(to square: Square) {
        guard let startSquare = startSquare else { return }
        previewArrow = PreviewArrow(from: startSquare, to: square, color: .blue.opacity(0.7))
        print("🎯 Arrow Manager: Updated preview to \(square)")
    }
    
    func finishDrawing(to square: Square) {
        guard let startSquare = startSquare else { return }
        
        if startSquare == square {
            // Same square - create/toggle circle
            if let existingIndex = currentCircles.firstIndex(where: { $0.square == square }) {
                currentCircles.remove(at: existingIndex)
                print("🔴 Arrow Manager: Removed circle from \(square) for move \(currentMoveIndex)")
            } else {
                let newCircle = ChessCircle(square: square, color: .red)
                currentCircles.append(newCircle)
                print("🟡 Arrow Manager: Added circle to \(square) for move \(currentMoveIndex)")
            }
            circlesByMoveIndex[currentMoveIndex] = currentCircles
        } else {
            // Different squares - create/toggle arrow
            if let existingIndex = currentArrows.firstIndex(where: { $0.from == startSquare && $0.to == square }) {
                currentArrows.remove(at: existingIndex)
                print("🗑️ Arrow Manager: Removed arrow from \(startSquare) to \(square) for move \(currentMoveIndex)")
            } else {
                let newArrow = ChessArrow(from: startSquare, to: square, color: .blue)
                currentArrows.append(newArrow)
                print("➕ Arrow Manager: Added arrow from \(startSquare) to \(square) for move \(currentMoveIndex)")
            }
            arrowsByMoveIndex[currentMoveIndex] = currentArrows
        }
        
        // Reset state
        isDrawing = false
        self.startSquare = nil
        previewArrow = nil
    }
    
    func cancelDrawing() {
        isDrawing = false
        self.startSquare = nil
        previewArrow = nil
        print("🚫 Arrow Manager: Cancelled drawing")
    }
    
    func clearAllArrows() {
        currentArrows.removeAll()
        currentCircles.removeAll()
        arrowsByMoveIndex[currentMoveIndex] = []
        circlesByMoveIndex[currentMoveIndex] = []
        cancelDrawing()
        print("🗑️ Arrow Manager: Cleared arrows and circles for move \(currentMoveIndex)")
    }
    
    func clearAllArrowsForAllMoves() {
        currentArrows.removeAll()
        currentCircles.removeAll()
        arrowsByMoveIndex.removeAll()
        circlesByMoveIndex.removeAll()
        cancelDrawing()
        print("🗑️ Arrow Manager: Cleared ALL arrows and circles for ALL moves")
    }
}

// MARK: - Circle Shape
struct CircleShape: Shape {
    let square: Square
    let boardSize: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let squareSize = boardSize / 8
        
        let centerPoint = CGPoint(
            x: CGFloat(square.file.rawValue) * squareSize + squareSize / 2,
            y: CGFloat(7 - square.rank.rawValue) * squareSize + squareSize / 2
        )
        
        let radius = squareSize * 0.35
        
        var path = Path()
        path.addEllipse(in: CGRect(
            x: centerPoint.x - radius,
            y: centerPoint.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        
        return path
    }
}

struct ArrowShape: Shape {
    let from: Square
    let to: Square
    let boardSize: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let squareSize = boardSize / 8
        
        let fromPoint = CGPoint(
            x: CGFloat(from.file.rawValue) * squareSize + squareSize / 2,
            y: CGFloat(7 - from.rank.rawValue) * squareSize + squareSize / 2
        )
        
        let toPoint = CGPoint(
            x: CGFloat(to.file.rawValue) * squareSize + squareSize / 2,
            y: CGFloat(7 - to.rank.rawValue) * squareSize + squareSize / 2
        )
        
        print("🎯 Arrow from \(from) (\(fromPoint)) to \(to) (\(toPoint))")
        
        let dx = toPoint.x - fromPoint.x
        let dy = toPoint.y - fromPoint.y
        let length = sqrt(dx * dx + dy * dy)
        
        guard length > 0 else { return Path() }
        
        let unitX = dx / length
        let unitY = dy / length
        
        let arrowHeadLength = max(12, boardSize / 30)
        let arrowHeadWidth = max(6, boardSize / 50)
        
        let shortenBy = squareSize * 0.2
        let adjustedFromPoint = CGPoint(
            x: fromPoint.x + unitX * shortenBy,
            y: fromPoint.y + unitY * shortenBy
        )
        let adjustedToPoint = CGPoint(
            x: toPoint.x - unitX * shortenBy,
            y: toPoint.y - unitY * shortenBy
        )
        
        let arrowTip = adjustedToPoint
        let arrowBase = CGPoint(
            x: arrowTip.x - unitX * arrowHeadLength,
            y: arrowTip.y - unitY * arrowHeadLength
        )
        
        let perpX = -unitY
        let perpY = unitX
        
        let arrowLeft = CGPoint(
            x: arrowBase.x + perpX * arrowHeadWidth,
            y: arrowBase.y + perpY * arrowHeadWidth
        )
        
        let arrowRight = CGPoint(
            x: arrowBase.x - perpX * arrowHeadWidth,
            y: arrowBase.y - perpY * arrowHeadWidth
        )
        
        var path = Path()
        
        // Arrow shaft
        path.move(to: adjustedFromPoint)
        path.addLine(to: arrowBase)
        
        // Arrow head
        path.move(to: arrowLeft)
        path.addLine(to: arrowTip)
        path.addLine(to: arrowRight)
        
        return path
    }
}

// MARK: - Arrow Drawing View
struct ArrowDrawingView: View {
    let currentArrows: [ChessArrow]
    let currentCircles: [ChessCircle]
    let previewArrow: ArrowManager.PreviewArrow?
    let boardSize: CGFloat
    
    var body: some View {
        ZStack {
            // Permanent arrows for current move
            ForEach(currentArrows) { arrow in
                ArrowShape(from: arrow.from, to: arrow.to, boardSize: boardSize)
                    .stroke(arrow.color, lineWidth: max(3, boardSize / 120))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 1)
            }
            
            // Circle highlights for current move
            ForEach(currentCircles) { circle in
                CircleShape(square: circle.square, boardSize: boardSize)
                    .stroke(circle.color, lineWidth: max(4, boardSize / 100))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 1)
            }
            
            // Preview arrow while dragging
            if let preview = previewArrow {
                ArrowShape(from: preview.from, to: preview.to, boardSize: boardSize)
                    .stroke(preview.color, lineWidth: max(3, boardSize / 120))
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 1, y: 1)
            }
        }
    }
}

// MARK: - Piece Overlay
struct PieceOverlay: View {
    let board: Board
    let boardSize: CGFloat
    @ObservedObject var cursorManager: CursorPieceManager
    
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { rankIndex in
                ForEach(0..<8, id: \.self) { fileIndex in
                    let square = Square(file: File(rawValue: fileIndex)!, rank: Rank(rawValue: rankIndex)!)
                    let piece = board.piece(at: square)
                    
                    if let piece = piece {
                        let squareSize = boardSize / 8
                        let x = CGFloat(fileIndex) * squareSize + squareSize / 2
                        let y = CGFloat(7 - rankIndex) * squareSize + squareSize / 2
                        
                        Image(piece.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: squareSize * 0.9, height: squareSize * 0.9)
                            .position(x: x, y: y)
                            .opacity(cursorManager.isActive && cursorManager.sourceSquare == square ? 0.3 : 1.0)
                    }
                }
            }
        }
        .frame(width: boardSize, height: boardSize)
    }
}

// MARK: - Cursor Piece Overlay
struct CursorPieceOverlay: View {
    @ObservedObject var cursorManager: CursorPieceManager
    let boardSize: CGFloat
    
    var body: some View {
        ZStack {
            if cursorManager.isActive, let piece = cursorManager.cursorPiece {
                Image(piece.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: boardSize / 9, height: boardSize / 9)
                    .position(cursorManager.cursorPosition)
                    .shadow(color: .black.opacity(0.6), radius: 6, x: 2, y: 2)
                    .scaleEffect(1.1)
                    .zIndex(2000)
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.1), value: cursorManager.cursorPosition)
                    .onAppear {
                        print("🎯 CURSOR OVERLAY: Showing \(piece.type) at \(cursorManager.cursorPosition)")
                    }
            } else {
                // Debug: Show when cursor is not active
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 1, height: 1)
                    .onAppear {
                        print("🎯 CURSOR OVERLAY: Not active - isActive: \(cursorManager.isActive), piece: \(cursorManager.cursorPiece?.type.character ?? Character("?"))")
                    }
            }
        }
        .frame(width: boardSize, height: boardSize)
        .clipped()
    }
}

// MARK: - Interactive Square View (Fixed for click detection)
struct InteractiveSquareView: View {
    let square: Square
    let piece: Piece?
    let isHighlighted: Bool
    let isLastMoveSquare: Bool
    let isValidMoveTarget: Bool
    let arrowManager: ArrowManager
    let cursorManager: CursorPieceManager
    let onPieceMove: (Square, Square) -> Void
    let boardSize: CGFloat
    
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var isPieceSelected = false
    @State private var isPieceCursorActive = false
    
    private var baseSquareColor: Color {
        let isLight = (square.file.rawValue + square.rank.rawValue) % 2 == 0
        return isLight ? Color(red: 0.9, green: 0.85, blue: 0.76) : Color(red: 0.7, green: 0.5, blue: 0.3)
    }
    
    private var finalSquareColor: Color {
        if isValidMoveTarget {
            return Color.green.opacity(0.6)
        } else if isHighlighted || isPieceSelected {
            return Color.yellow.opacity(0.8)
        } else if isLastMoveSquare {
            let isLight = (square.file.rawValue + square.rank.rawValue) % 2 == 0
            return isLight ? Color(red: 0.7, green: 0.7, blue: 0.9) : Color(red: 0.5, green: 0.4, blue: 0.6)
        } else if arrowManager.startSquare == square {
            return baseSquareColor.opacity(0.7)
        } else {
            return baseSquareColor
        }
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(finalSquareColor)
            
            if isHighlighted || isPieceSelected {
                Rectangle()
                    .stroke(Color.orange, lineWidth: 3)
            }
            
            if arrowManager.startSquare == square {
                Rectangle()
                    .stroke(Color.green, lineWidth: 3)
            }
            
            if isValidMoveTarget {
                Circle()
                    .fill(Color.green.opacity(0.8))
                    .frame(width: 20, height: 20)
            }
            
            // Piece will be rendered separately in the piece overlay layer
            if let piece = piece {
                Rectangle()
                    .fill(Color.clear)
                    .opacity(isPieceCursorActive ? 0.2 : 0.0) // Only show when cursor is active for visual feedback
            }
            
            if isHighlighted {
                Rectangle()
                    .fill(Color.yellow.opacity(0.2))
                    .blur(radius: 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture {
            print("🎯 SQUARE TAP: \(square) (piece: \(piece != nil ? String(describing: piece!.type) : "none"))")
            if piece == nil {
                // Empty square - try to move selected piece here
                print("🎯 EMPTY SQUARE TARGET: \(square)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("SquareTargeted"),
                    object: square
                )
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SquareSelected"))) { notification in
            if let selectedSquare = notification.object as? Square {
                isPieceSelected = (selectedSquare == square)
                print("🎯 SELECTION UPDATE: \(square) selected=\(isPieceSelected)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PieceDragEnded"))) { _ in
            isPieceSelected = false
            isPieceCursorActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PieceMoveCompleted"))) { _ in
            isPieceCursorActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SquareTargeted"))) { _ in
            isPieceCursorActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MouseDownOnSquare"))) { notification in
            NSLog("🎯 SQUARE VIEW: Received MouseDownOnSquare notification for square \(square)")
            if let clickedSquare = notification.object as? Square {
                NSLog("🎯 SQUARE VIEW: Clicked square is \(clickedSquare), this square is \(square)")
                if clickedSquare == square {
                    NSLog("🎯 SQUARE VIEW: Squares match!")
                    if let piece = piece {
                        NSLog("🎯 SQUARE VIEW: Found piece \(piece.type) at \(square)")
                        
                        // Use centralized coordinate system
                        let coords = BoardCoordinateSystem(boardSize: boardSize)
                        let centerPoint = coords.squareToSwiftUIPoint(square)
                        
                        NSLog("🎯 PIECE PICKUP DEBUG: square=\(square), centerPoint=\(centerPoint)")
                        
                        DispatchQueue.main.async {
                            cursorManager.startCursorPiece(piece, from: square, at: centerPoint)
                            isPieceCursorActive = true
                            NSLog("🎯 SQUARE VIEW: CURSOR ACTIVATED: \(cursorManager.isActive)")
                        }
                    } else {
                        NSLog("🎯 SQUARE VIEW: No piece on this square")
                    }
                } else {
                    NSLog("🎯 SQUARE VIEW: Squares don't match, ignoring")
                }
            } else {
                NSLog("🎯 SQUARE VIEW: Failed to cast notification object to Square")
            }
        }
    }
}

// MARK: - Interactive Chess Board (Simplified working version)
struct InteractiveChessBoard: View {
    let board: Board
    let highlightManager: MoveHighlightManager
    @Binding var boardSize: CGFloat
    @StateObject private var arrowManager = ArrowManager()
    @StateObject private var cursorManager = CursorPieceManager()
    @ObservedObject var gameViewModel: GameViewModel
    
    @State private var validMoveTargets: Set<Square> = []
    @State private var debugMessages: [String] = []
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 0), count: 8)
    
    var body: some View {
        ZStack {
            // Chess squares (bottom layer)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach((0..<8).reversed(), id: \.self) { rankIndex in
                    ForEach(0..<8, id: \.self) { fileIndex in
                        let square = Square(file: File(rawValue: fileIndex)!, rank: Rank(rawValue: rankIndex)!)
                        let piece = board.piece(at: square)
                        
                        InteractiveSquareView(
                            square: square,
                            piece: piece,
                            isHighlighted: highlightManager.isHighlighted(square),
                            isLastMoveSquare: highlightManager.isLastMoveSquare(square),
                            isValidMoveTarget: validMoveTargets.contains(square),
                            arrowManager: arrowManager,
                            cursorManager: cursorManager,
                            onPieceMove: { from, to in
                                print("🎯 BOARD: Move callback \(from) -> \(to)")
                                gameViewModel.attemptMove(from: from, to: to)
                            },
                            boardSize: boardSize
                        )
                    }
                }
            }
            .frame(width: boardSize, height: boardSize)
            .coordinateSpace(name: "ChessBoard")
            
            // Piece overlay (renders all pieces separately)
            PieceOverlay(board: board, boardSize: boardSize, cursorManager: cursorManager)
                .frame(width: boardSize, height: boardSize)
                .allowsHitTesting(false)
            
            // Arrow overlay (middle layer)
            ArrowDrawingView(
                currentArrows: arrowManager.currentArrows,
                currentCircles: arrowManager.currentCircles,
                previewArrow: arrowManager.previewArrow,
                boardSize: boardSize
            )
            .frame(width: boardSize, height: boardSize)
            .allowsHitTesting(false)
            
            // Cursor piece overlay (top layer)
            CursorPieceOverlay(cursorManager: cursorManager, boardSize: boardSize)
                .frame(width: boardSize, height: boardSize)
                .allowsHitTesting(false)
            
            // Mouse tracking and right-click detector (top layer)
            MouseTrackingView(cursorManager: cursorManager, arrowManager: arrowManager, boardSize: boardSize)
                .frame(width: boardSize, height: boardSize)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        cursorManager.updateCursorPosition(location)
                    case .ended:
                        break
                    }
                }
            
            // Debug overlay - positioned absolutely to ensure visibility
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🎯 DEBUG INFO")
                            .font(.title2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.9))
                            .border(Color.red, width: 2)
                        
                        Text("Cursor Active: \(cursorManager.isActive)")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.8))
                        
                        Text("Debug Test: \(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 100), specifier: "%.1f")")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.8))
                        
                        if let sourceSquare = cursorManager.sourceSquare {
                            Text("Source: \(sourceSquare)")
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.8))
                        }
                        
                        ForEach(debugMessages.suffix(5), id: \.self) { message in
                            Text(message)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.8))
                        }
                        
                        Button("🔥 TEST DEBUG") {
                            addDebugMessage("Test message: \(Date().timeIntervalSince1970)")
                        }
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.9))
                        .border(Color.blue, width: 2)
                    }
                    Spacer()
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(1000)
        }
        .border(Color.black, width: 1)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SquareSelected"))) { notification in
            if let square = notification.object as? Square {
                print("🎯 BOARD: Square selected notification for \(square)")
                addDebugMessage("Square selected: \(square)")
                gameViewModel.selectSquare(square)
                updateValidMoveTargets()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SquareTargeted"))) { notification in
            if let targetSquare = notification.object as? Square,
               let selectedSquare = gameViewModel.selectedSquare {
                print("🎯 BOARD: Square targeted \(targetSquare), selected=\(selectedSquare)")
                gameViewModel.attemptMove(from: selectedSquare, to: targetSquare)
                updateValidMoveTargets()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PieceDragStarted"))) { notification in
            if let square = notification.object as? Square {
                print("🎯 BOARD: Piece drag started at \(square)")
                gameViewModel.selectSquare(square)
                updateValidMoveTargets()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PieceMoveCompleted"))) { notification in
            if let moveData = notification.object as? [String: Square],
               let fromSquare = moveData["from"],
               let toSquare = moveData["to"] {
                print("🎯 BOARD: Received move completion \(fromSquare) -> \(toSquare)")
                
                // CRITICAL: Ensure the piece is selected and valid moves are generated before attempting the move
                print("🎯 BOARD: Ensuring piece selection before drag move")
                gameViewModel.selectSquare(fromSquare)
                
                // Give a tiny delay to ensure the selection and valid move generation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    print("🎯 BOARD: Now attempting drag move with \(gameViewModel.validMoves.count) valid moves")
                    gameViewModel.attemptMove(from: fromSquare, to: toSquare)
                    updateValidMoveTargets()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SmartSquareClick"))) { notification in
            if let square = notification.object as? Square {
                print("🎯 BOARD: Smart click on \(square)")
                
                // Check if we already have a piece selected
                if let selectedSquare = gameViewModel.selectedSquare {
                    // We have a selected piece - check if this click is on a valid target
                    let validTargets = Set(gameViewModel.validMoves.map { $0.to })
                    if validTargets.contains(square) {
                        // Valid target - make the move!
                        print("🎯 BOARD: Making move \(selectedSquare) -> \(square)")
                        gameViewModel.attemptMove(from: selectedSquare, to: square)
                    } else {
                        // Not a valid target - try to select this square instead
                        print("🎯 BOARD: Not valid target, selecting \(square)")
                        gameViewModel.selectSquare(square)
                    }
                } else {
                    // No piece selected - try to select this square
                    print("🎯 BOARD: No selection, selecting \(square)")
                    gameViewModel.selectSquare(square)
                }
                updateValidMoveTargets()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PieceDragEnded"))) { _ in
            updateValidMoveTargets() // Clear on drag end
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearArrows"))) { _ in
            arrowManager.clearAllArrows()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearAllArrows"))) { _ in
            arrowManager.clearAllArrowsForAllMoves()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MoveIndexChanged"))) { notification in
            if let moveIndex = notification.object as? Int {
                arrowManager.setCurrentMove(moveIndex)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PieceMoveCompleted"))) { _ in
            cursorManager.stopCursorPiece()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SquareTargeted"))) { _ in
            cursorManager.stopCursorPiece()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MouseDownOnSquare"))) { notification in
            if let square = notification.object as? Square {
                addDebugMessage("Mouse down on: \(square)")
            }
        }
    }
    
    private func updateValidMoveTargets() {
        let newTargets = Set(gameViewModel.validMoves.map { $0.to })
        if newTargets != validMoveTargets {
            validMoveTargets = newTargets
        }
        print("🎯 BOARD: Updated valid move targets: \(validMoveTargets)")
    }
    
    private func addDebugMessage(_ message: String) {
        DispatchQueue.main.async {
            debugMessages.append(message)
            if debugMessages.count > 10 {
                debugMessages.removeFirst()
            }
        }
    }
}

// MARK: - Mouse Tracking View
struct MouseTrackingView: NSViewRepresentable {
    @ObservedObject var cursorManager: CursorPieceManager
    @ObservedObject var arrowManager: ArrowManager
    let boardSize: CGFloat
    
    func makeNSView(context: Context) -> MouseTrackingNSView {
        let view = MouseTrackingNSView()
        view.cursorManager = cursorManager
        view.arrowManager = arrowManager
        view.boardSize = boardSize
        return view
    }
    
    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        nsView.cursorManager = cursorManager
        nsView.arrowManager = arrowManager
        nsView.boardSize = boardSize
    }
}

class MouseTrackingNSView: NSView {
    var cursorManager: CursorPieceManager?
    var arrowManager: ArrowManager?
    var boardSize: CGFloat = 350
    
    // Track piece dragging state
    private var isDraggingPiece = false
    private var dragStartSquare: Square?
    private var trackingArea: NSTrackingArea?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        updateTrackingArea()
        
        // Make sure we can receive mouse events
        NSLog("🎯 MOUSE TRACKING VIEW: setupView called, bounds: \(bounds)")
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        NSLog("🎯 MOUSE TRACKING VIEW: acceptsFirstMouse called")
        return true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        NSLog("🎯 MOUSE TRACKING VIEW: awakeFromNib called")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NSLog("🎯 MOUSE TRACKING VIEW: viewDidMoveToWindow called, window: \(window != nil)")
    }
    
    private func updateTrackingArea() {
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseMoved, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateTrackingArea()
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let coords = BoardCoordinateSystem(boardSize: boardSize)
        let swiftUILocation = coords.nsViewToSwiftUI(location)
        cursorManager?.updateCursorPosition(swiftUILocation)
        
        NSLog("🎯 MOUSE TRACKING: mouseMoved NSView: \(location), SwiftUI: \(swiftUILocation)")
        if let square = coords.nsViewPointToSquare(location) {
            NSLog("🎯 MOUSE TRACKING: mouseMoved over square \(square)")
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let coords = BoardCoordinateSystem(boardSize: boardSize)
        let swiftUILocation = coords.nsViewToSwiftUI(location)
        cursorManager?.updateCursorPosition(swiftUILocation)
        
        // Handle piece dragging
        guard let startSquare = dragStartSquare else { return }
        
        if !isDraggingPiece {
            // First drag event - start piece dragging
            isDraggingPiece = true
            print("🎯 Started dragging from \(startSquare)")
            NotificationCenter.default.post(
                name: NSNotification.Name("SquareSelected"),
                object: startSquare
            )
            NotificationCenter.default.post(
                name: NSNotification.Name("PieceDragStarted"),
                object: startSquare
            )
        }
        
        print("🎯 Dragging to location \(location)")
        if let square = coords.nsViewPointToSquare(location) {
            print("🎯 Dragging over square \(square)")
        }
    }

    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }
    
    // Handle right-clicks for arrows
    override func rightMouseDown(with event: NSEvent) {
        print("🔴 Right mouse down detected")
        guard let arrowManager = arrowManager else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        if let square = pointToSquare(location) {
            arrowManager.startDrawing(from: square)
        }
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        guard let arrowManager = arrowManager else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        if let square = pointToSquare(location) {
            arrowManager.updatePreview(to: square)
        }
    }
    
    override func rightMouseUp(with event: NSEvent) {
        print("🔴 Right mouse up")
        guard let arrowManager = arrowManager else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        if let square = pointToSquare(location) {
            arrowManager.finishDrawing(to: square)
        } else {
            arrowManager.cancelDrawing()
        }
    }
    
    // Handle left-clicks and drags for piece movement
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        NSLog("🎯 MOUSE DOWN at location: \(location)")
        
        if let square = pointToSquare(location) {
            NSLog("🎯 MOUSE DOWN on square: \(square)")
            dragStartSquare = square
            isDraggingPiece = false
            
            // Check if there's a piece on this square and start cursor piece if so
            // We need to get the piece information from the board
            // For now, let's post a notification to start cursor piece
            NotificationCenter.default.post(
                name: NSNotification.Name("MouseDownOnSquare"),
                object: square
            )
            NSLog("🎯 Posted MouseDownOnSquare notification for \(square)")
        } else {
            NSLog("🎯 MOUSE DOWN outside valid square")
        }
    }

    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode
        print("🎹 Key pressed: \(event.charactersIgnoringModifiers ?? "unknown"), keyCode: \(keyCode)")
        
        if keyCode == 15 { // "r" key
            print("🎹 R key pressed - clearing all arrows")
            arrowManager?.clearAllArrowsForAllMoves()
        } else if keyCode == 51 { // Delete key
            print("🎹 Delete key pressed - clearing arrows for current move")
            arrowManager?.clearAllArrows()
        } else {
            super.keyDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        print("🎹 SimpleRightClickView became first responder")
        return super.becomeFirstResponder()
    }
    
    override func mouseUp(with event: NSEvent) {
        defer {
            // Reset drag state AFTER processing
            let wasDragging = isDraggingPiece
            dragStartSquare = nil
            isDraggingPiece = false
            if wasDragging {
                NotificationCenter.default.post(
                    name: NSNotification.Name("PieceDragEnded"),
                    object: nil
                )
            }
        }
        
        let location = convert(event.locationInWindow, from: nil)
        
        // Stop cursor piece if it's active
        if cursorManager?.isActive == true {
            if let sourceSquare = cursorManager?.sourceSquare,
               let endSquare = pointToSquare(location) {
                print("🎯 Cursor piece dropped from \(sourceSquare) to \(endSquare)")
                cursorManager?.stopCursorPiece()
                
                if sourceSquare != endSquare {
                    // This is a move
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PieceMoveCompleted"),
                        object: ["from": sourceSquare, "to": endSquare]
                    )
                } else {
                    // Dropped on same square - just select it
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SmartSquareClick"),
                        object: endSquare
                    )
                }
            } else {
                // Dropped outside board - just stop the cursor piece
                cursorManager?.stopCursorPiece()
            }
            return
        }
        
        guard let startSquare = dragStartSquare else { return }
        
        if let endSquare = pointToSquare(location) {
            print("🎯 Mouse up at \(endSquare), startSquare: \(startSquare), isDragging: \(isDraggingPiece)")
            
            if isDraggingPiece && endSquare != startSquare {
                // Drag and drop move
                print("🎯 Completing drag move \(startSquare) -> \(endSquare)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("PieceMoveCompleted"),
                    object: ["from": startSquare, "to": endSquare]
                )
            } else if !isDraggingPiece {
                // This was a simple click, not a drag
                print("🎯 Click on \(endSquare) - sending smart click notification")
                NotificationCenter.default.post(
                    name: NSNotification.Name("SmartSquareClick"),
                    object: endSquare
                )
            }
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    private func pointToSquare(_ point: CGPoint) -> Square? {
        let coords = BoardCoordinateSystem(boardSize: boardSize)
        let square = coords.nsViewPointToSquare(point)
        NSLog("🎯 MouseTrackingNSView.pointToSquare: point=\(point) -> square=\(String(describing: square))")
        return square
    }
}

struct RightClickDetector: NSViewRepresentable {
    @ObservedObject var arrowManager: ArrowManager
    let boardSize: CGFloat
    
    func makeNSView(context: Context) -> NSView {
        let view = RightClickView()
        view.arrowManager = arrowManager
        view.boardSize = boardSize
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? RightClickView {
            view.arrowManager = arrowManager
            view.boardSize = boardSize
        }
    }
}

class RightClickView: NSView {
    var arrowManager: ArrowManager?
    var boardSize: CGFloat = 350
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    override func rightMouseDown(with event: NSEvent) {
        print("🔴 Right mouse down detected")
        guard let arrowManager = arrowManager else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        if let square = pointToSquare(location) {
            arrowManager.startDrawing(from: square)
        }
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        guard let arrowManager = arrowManager else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        if let square = pointToSquare(location) {
            arrowManager.updatePreview(to: square)
        }
    }
    
    override func rightMouseUp(with event: NSEvent) {
        print("🔴 Right mouse up")
        guard let arrowManager = arrowManager else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        if let square = pointToSquare(location) {
            arrowManager.finishDrawing(to: square)
        } else {
            arrowManager.cancelDrawing()
        }
    }
    
    private func pointToSquare(_ point: CGPoint) -> Square? {
        let squareSize = boardSize / 8
        let fileIndex = Int(point.x / squareSize)
        let rankIndex = Int(point.y / squareSize)
        
        guard fileIndex >= 0, fileIndex < 8, rankIndex >= 0, rankIndex < 8,
              let file = File(rawValue: fileIndex),
              let rank = Rank(rawValue: rankIndex) else {
            return nil
        }
        
        return Square(file: file, rank: rank)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}
