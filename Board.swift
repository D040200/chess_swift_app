import Foundation

// MARK: - Square Representation
enum File: Int, CaseIterable, CustomStringConvertible {
    case A, B, C, D, E, F, G, H
    // Corrected description to return the actual letter
    var description: String {
        switch self {
        case .A: return "a"
        case .B: return "b"
        case .C: return "c"
        case .D: return "d"
        case .E: return "e"
        case .F: return "f"
        case .G: return "g"
        case .H: return "h"
        }
    }
}

enum Rank: Int, CaseIterable, CustomStringConvertible {
    case one, two, three, four, five, six, seven, eight
    var description: String { return String(rawValue + 1) }
}

struct Square: Equatable, Hashable, CustomStringConvertible {
    let file: File
    let rank: Rank
    
    init(file: File, rank: Rank) {
        self.file = file
        self.rank = rank
    }
    
    init?(index: Int) {
        guard index >= 0 && index < 64 else { return nil }
        self.file = File(rawValue: index % 8)!
        self.rank = Rank(rawValue: index / 8)!
    }
    
    // Corrected to handle optional characters from .first and .last
    init?(algebraic: String) {
        print("DEBUG: Square.init?(algebraic:) called with: \"\(algebraic)\"") //
        
        guard algebraic.count == 2 else {
            print("DEBUG: Square.init?(algebraic:) - Failed: string count is not 2. (Count: \(algebraic.count))") //
            return nil
        }
        
        guard let fileChar = algebraic.lowercased().first else {
            print("DEBUG: Square.init?(algebraic:) - Failed: could not get file character.") //
            return nil
        }
        
        guard let rankChar = algebraic.last else {
            print("DEBUG: Square.init?(algebraic:) - Failed: could not get rank character.") //
            return nil
        }
        
        print("DEBUG: fileChar: '\(fileChar)', rankChar: '\(rankChar)'") //
        
        guard let file = File.allCases.first(where: { $0.description.lowercased().first == fileChar }) else {
            print("DEBUG: Square.init?(algebraic:) - Failed: File enum not found for fileChar '\(fileChar)'.") //
            return nil
        }
        
        guard let rankInt = Int(String(rankChar)) else {
            print("DEBUG: Square.init?(algebraic:) - Failed: Could not convert rankChar '\(rankChar)' to Int.") //
            return nil
        }
        
        guard let rank = Rank(rawValue: rankInt - 1) else {
            print("DEBUG: Square.init?(algebraic:) - Failed: Rank enum not found for rankInt \(rankInt).") //
            return nil
        }
        
        self.file = file
        self.rank = rank
        print("DEBUG: Square.init?(algebraic:) - Succeeded: \(file)\(rank)") //
    }
    
    var index: Int { return rank.rawValue * 8 + file.rawValue }
    var description: String { return "\(file)\(rank)" }
    
    static let all: [Square] = {
        var squares: [Square] = []
        for rank in Rank.allCases {
            for file in File.allCases {
                squares.append(Square(file: file, rank: rank))
            }
        }
        return squares
    }()
}

// MARK: - Bitboard Struct
struct Bitboard: Equatable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    private(set) var rawValue: UInt64
    init(rawValue: UInt64) { self.rawValue = rawValue }
    init() { self.rawValue = 0 }
    init(integerLiteral value: UInt64) { self.rawValue = value }
    init(marked square: Square) { self.rawValue = 1 << square.index }
    func contains(_ square: Square) -> Bool { return (self.rawValue >> square.index) & 1 == 1 }
    mutating func set(_ square: Square) { self.rawValue |= (1 << square.index) }
    mutating func clear(_ square: Square) { self.rawValue &= ~(1 << square.index) }
    mutating func toggle(_ square: Square) { self.rawValue ^= (1 << square.index) }
    static func & (lhs: Bitboard, rhs: Bitboard) -> Bitboard { return Bitboard(rawValue: lhs.rawValue & rhs.rawValue) }
    static func | (lhs: Bitboard, rhs: Bitboard) -> Bitboard { return Bitboard(rawValue: lhs.rawValue | rhs.rawValue) }
    static func ^ (lhs: Bitboard, rhs: Bitboard) -> Bitboard { return Bitboard(rawValue: lhs.rawValue ^ rhs.rawValue) }
    static prefix func ~ (rhs: Bitboard) -> Bitboard { return Bitboard(rawValue: ~rhs.rawValue) }
    static func << (lhs: Bitboard, rhs: Int) -> Bitboard { return Bitboard(rawValue: lhs.rawValue << rhs) }
    static func >> (lhs: Bitboard, rhs: Int) -> Bitboard { return Bitboard(rawValue: lhs.rawValue >> rhs) }
    static func &= (lhs: inout Bitboard, rhs: Bitboard) { lhs.rawValue &= rhs.rawValue }
    static func |= (lhs: inout Bitboard, rhs: Bitboard) { lhs.rawValue |= rhs.rawValue }
    static func ^= (lhs: inout Bitboard, rhs: Bitboard) { lhs.rawValue ^= rhs.rawValue }
    static func <<= (lhs: inout Bitboard, rhs: Int) { lhs.rawValue <<= rhs }
    static func >>= (lhs: inout Bitboard, rhs: Int) { lhs.rawValue >>= rhs }
    var isEmpty: Bool { return rawValue == 0 }
    var populationCount: Int { return rawValue.nonzeroBitCount }
    func lsbIndex() -> Int? { guard rawValue != 0 else { return nil }; return rawValue.trailingZeroBitCount }
    var description: String {
        var output = ""
        for rankIndex in (0..<8).reversed() {
            output += "\(rankIndex + 1) "
            for fileIndex in 0..<8 {
                let squareIndex = rankIndex * 8 + fileIndex
                if (rawValue >> squareIndex) & 1 == 1 { output += "1 " } else { output += ". " }
            }
            output += "\n"
        }
        output += "  A B C D E F G H"
        return output
    }
}

// MARK: - Piece Definition
enum PieceColor: CaseIterable {
    case white, black
    var opposite: PieceColor { return self == .white ? .black : .white }
}

enum PieceType: CaseIterable {
    case pawn, knight, bishop, rook, queen, king
    var character: Character {
        switch self {
        case .pawn: return "p"
        case .knight: return "n"
        case .bishop: return "b"
        case .rook: return "r"
        case .queen: return "q"
        case .king: return "k"
        }
    }
}

struct Piece: Equatable {
    let type: PieceType
    let color: PieceColor
    
    init(type: PieceType, color: PieceColor) { self.type = type; self.color = color }
    
    var fenCharacter: Character {
        let char = type.character
        return color == .white ? Character(char.uppercased()) : char
    }
    
    var imageName: String {
        let colorPrefix = color == .white ? "w" : "b"
        // Use the FEN character's uppercase version for consistency in asset names
        let typeCharacter = String(type.character).uppercased()
        return "\(colorPrefix)\(typeCharacter)"
    }
    
    init?(fenCharacter: Character) {
        let isWhite = fenCharacter.isUppercase
        let lowercasedChar = Character(fenCharacter.lowercased())
        switch lowercasedChar {
        case "p": self.type = .pawn
        case "n": self.type = .knight
        case "b": self.type = .bishop
        case "r": self.type = .rook
        case "q": self.type = .queen
        case "k": self.type = .king
        default: return nil
        }
        self.color = isWhite ? .white : .black
    }
    

}

// MARK: - Board Object
struct Board {
    var whitePawns: Bitboard
    var whiteKnights: Bitboard
    var whiteBishops: Bitboard
    var whiteRooks: Bitboard
    var whiteQueens: Bitboard
    var whiteKing: Bitboard
    
    var blackPawns: Bitboard
    var blackKnights: Bitboard
    var blackBishops: Bitboard
    var blackRooks: Bitboard
    var blackQueens: Bitboard
    var blackKing: Bitboard
    
    // MARK: - Initializers
    // Designated initializer with all piece bitboards
    init(whitePawns: Bitboard, whiteKnights: Bitboard, whiteBishops: Bitboard,
         whiteRooks: Bitboard, whiteQueens: Bitboard, whiteKing: Bitboard,
         blackPawns: Bitboard, blackKnights: Bitboard, blackBishops: Bitboard,
         blackRooks: Bitboard, blackQueens: Bitboard, blackKing: Bitboard) {
        self.whitePawns = whitePawns; self.whiteKnights = whiteKnights; self.whiteBishops = whiteBishops
        self.whiteRooks = whiteRooks; self.whiteQueens = whiteQueens; self.whiteKing = whiteKing
        self.blackPawns = blackPawns; self.blackKnights = blackKnights; self.blackBishops = blackBishops
        self.blackRooks = blackRooks; self.blackQueens = blackQueens; self.blackKing = blackKing
    }
    
    // Convenience initializer for an empty board
    init() {
        self.init(whitePawns: 0, whiteKnights: 0, whiteBishops: 0,
                  whiteRooks: 0, whiteQueens: 0, whiteKing: 0,
                  blackPawns: 0, blackKnights: 0, blackBishops: 0,
                  blackRooks: 0, blackQueens: 0, blackKing: 0)
    }
    
    static func startingBoard() -> Board {
        return Board(
            whitePawns:   0b00000000_00000000_00000000_00000000_00000000_00000000_11111111_00000000,
            whiteKnights: 0b00000000_00000000_00000000_00000000_00000000_00000000_00000000_01000010,
            whiteBishops: 0b00000000_00000000_00000000_00000000_00000000_00000000_00000000_00100100,
            whiteRooks:   0b00000000_00000000_00000000_00000000_00000000_00000000_00000000_10000001,
            whiteQueens:  0b00000000_00000000_00000000_00000000_00000000_00000000_00000000_00001000,
            whiteKing:    0b00000000_00000000_00000000_00000000_00000000_00000000_00000000_00010000,
            blackPawns:   0b00000000_11111111_00000000_00000000_00000000_00000000_00000000_00000000,
            blackKnights: 0b01000010_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
            blackBishops: 0b00100100_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
            blackRooks:   0b10000001_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
            blackQueens:  0b00001000_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
            blackKing:    0b00010000_00000000_00000000_00000000_00000000_00000000_00000000_00010000
        )
        
    }
    
    init?(fen: String) {
        self.init() // Call the empty initializer first to initialize properties
        
        let components = fen.split(separator: " ").map(String.init)
        guard components.count >= 1 else { return nil }
        
        let piecePlacement = components[0]
        let rankStrings = piecePlacement.split(separator: "/")
        guard rankStrings.count == 8 else { return nil }
        
        for (rankOffset, rankString) in rankStrings.enumerated() {
            let currentRankRawValue = 7 - rankOffset
            guard let currentRank = Rank(rawValue: currentRankRawValue) else { return nil }
            
            var currentFileRawValue = 0
            for char in rankString {
                if let emptySquares = Int(String(char)) {
                    guard emptySquares >= 1 && emptySquares <= 8 else { return nil }
                    currentFileRawValue += emptySquares
                } else if let piece = Piece(fenCharacter: char) {
                    guard currentFileRawValue < 8 else { return nil }
                    guard let currentFile = File(rawValue: currentFileRawValue) else { return nil }
                    let square = Square(file: currentFile, rank: currentRank)
                    
                    switch (piece.type, piece.color) {
                    case (.pawn, .white): whitePawns.set(square)
                    case (.knight, .white): whiteKnights.set(square)
                    case (.bishop, .white): whiteBishops.set(square)
                    case (.rook, .white): whiteRooks.set(square)
                    case (.queen, .white): whiteQueens.set(square)
                    case (.king, .white): whiteKing.set(square)
                    case (.pawn, .black): blackPawns.set(square)
                    case (.knight, .black): blackKnights.set(square)
                    case (.bishop, .black): blackBishops.set(square)
                    case (.rook, .black): blackRooks.set(square)
                    case (.queen, .black): blackQueens.set(square)
                    case (.king, .black): blackKing.set(square)
                    }
                    currentFileRawValue += 1
                } else {
                    return nil
                }
            }
            guard currentFileRawValue == 8 else { return nil }
        }
    }
    
    // MARK: - Composite Bitboards
    var whitePieces: Bitboard { return whitePawns | whiteKnights | whiteBishops | whiteRooks | whiteQueens | whiteKing }
    var blackPieces: Bitboard { return blackPawns | blackKnights | blackBishops | blackRooks | blackQueens | blackKing }
    var allPieces: Bitboard { return whitePieces | blackPieces }
    var emptySquares: Bitboard { return ~allPieces }
    
    // MARK: - Piece Lookup
    func piece(at square: Square) -> Piece? {
        if whitePawns.contains(square) { return Piece(type: .pawn, color: .white) }
        if whiteKnights.contains(square) { return Piece(type: .knight, color: .white) }
        if whiteBishops.contains(square) { return Piece(type: .bishop, color: .white) }
        if whiteRooks.contains(square) { return Piece(type: .rook, color: .white) }
        if whiteQueens.contains(square) { return Piece(type: .queen, color: .white) }
        if whiteKing.contains(square) { return Piece(type: .king, color: .white) }
        if blackPawns.contains(square) { return Piece(type: .pawn, color: .black) }
        if blackKnights.contains(square) { return Piece(type: .knight, color: .black) }
        if blackBishops.contains(square) { return Piece(type: .bishop, color: .black) }
        if blackRooks.contains(square) { return Piece(type: .rook, color: .black) }
        if blackQueens.contains(square) { return Piece(type: .queen, color: .black) }
        if blackKing.contains(square) { return Piece(type: .king, color: .black) }
        return nil
    }
    
    // MARK: - Piece Removal Helper
    mutating func removePiece(at square: Square, pieceColor: PieceColor, pieceType: PieceType) {
        switch (pieceType, pieceColor) {
        case (.pawn, .white): whitePawns.clear(square)
        case (.knight, .white): whiteKnights.clear(square)
        case (.bishop, .white): whiteBishops.clear(square)
        case (.rook, .white): whiteRooks.clear(square)
        case (.queen, .white): whiteQueens.clear(square)
        case (.king, .white): whiteKing.clear(square)
        case (.pawn, .black): blackPawns.clear(square)
        case (.knight, .black): blackKnights.clear(square)
        case (.bishop, .black): blackBishops.clear(square)
        case (.rook, .black): blackRooks.clear(square)
        case (.queen, .black): blackQueens.clear(square)
        case (.king, .black): blackKing.clear(square)
        }
    }
    
    // MARK: - Piece Placement Helper
    mutating func placePiece(at square: Square, pieceColor: PieceColor, pieceType: PieceType) {
        switch (pieceType, pieceColor) {
        case (.pawn, .white): whitePawns.set(square)
        case (.knight, .white): whiteKnights.set(square)
        case (.bishop, .white): whiteBishops.set(square)
        case (.rook, .white): whiteRooks.set(square)
        case (.queen, .white): whiteQueens.set(square)
        case (.king, .white): whiteKing.set(square)
        case (.pawn, .black): blackPawns.set(square)
        case (.knight, .black): blackKnights.set(square)
        case (.bishop, .black): blackBishops.set(square)
        case (.rook, .black): blackRooks.set(square)
        case (.queen, .black): blackQueens.set(square)
        case (.king, .black): blackKing.set(square)
        }
    }
    
    // MARK: - Core Move Execution Logic
    mutating func applyMove(_ move: Move) {
        // 1. Remove the piece from its 'from' square
        removePiece(at: move.from, pieceColor: move.piece.color, pieceType: move.piece.type)
        
        // 2. Handle captures
        if let captured = move.capturedPiece {
            if move.flag == .enPassantCapture {
                // Square.init?(file:rank:) returns an optional, so we must safely unwrap it or force unwrap if we're certain it exists.
                // Assuming en-passant moves use valid squares, force unwrapping is acceptable here.
                let capturedPawnSquare: Square = move.piece.color == .white ?
                Square(file: move.to.file, rank: .five) :
                Square(file: move.to.file, rank: .four)
                removePiece(at: capturedPawnSquare, pieceColor: captured.color, pieceType: captured.type)
            } else {
                removePiece(at: move.to, pieceColor: captured.color, pieceType: captured.type)
            }
        }
        
        // 3. Place the moving piece on its 'to' square (handle promotion)
        if case .promotion(let promotedType) = move.flag {
            placePiece(at: move.to, pieceColor: move.piece.color, pieceType: promotedType)
        } else {
            placePiece(at: move.to, pieceColor: move.piece.color, pieceType: move.piece.type)
        }
        
        // 4. Handle castling (move the rook)
        if move.flag == .kingSideCastling {
            if move.piece.color == .white {
                removePiece(at: Square(file: .H, rank: .one), pieceColor: .white, pieceType: .rook)
                placePiece(at: Square(file: .F, rank: .one), pieceColor: .white, pieceType: .rook)
            } else {
                removePiece(at: Square(file: .H, rank: .eight), pieceColor: .black, pieceType: .rook)
                placePiece(at: Square(file: .F, rank: .eight), pieceColor: .black, pieceType: .rook)
            }
        } else if move.flag == .queenSideCastling {
            if move.piece.color == .white {
                removePiece(at: Square(file: .A, rank: .one), pieceColor: .white, pieceType: .rook)
                placePiece(at: Square(file: .D, rank: .one), pieceColor: .white, pieceType: .rook)
            } else {
                removePiece(at: Square(file: .A, rank: .eight), pieceColor: .black, pieceType: .rook)
                placePiece(at: Square(file: .D, rank: .eight), pieceColor: .black, pieceType: .rook)
            }
        }
    }
    
    // MARK: - Board Display (ASCII)
    var ascii: String {
        var output = ""
        for rankIndex in (0..<8).reversed() {
            output += "\(rankIndex + 1) "
            for fileIndex in 0..<8 {
                let square = Square(file: File(rawValue: fileIndex)!, rank: Rank(rawValue: rankIndex)!)
                if let piece = self.piece(at: square) { output += "\(piece.fenCharacter) " } else { output += ". " }
            }
            output += "\n"
        }
        output += "  a b c d e f g h"
        return output
    }
}

extension Board {
    func isPathClear(from start: Square, to end: Square, ignoring: Piece? = nil) -> Bool {
        let fileDiff = end.file.rawValue - start.file.rawValue
        let rankDiff = end.rank.rawValue - start.rank.rawValue
        
        let fileDirection = (fileDiff == 0) ? 0 : (fileDiff > 0 ? 1 : -1)
        let rankDirection = (rankDiff == 0) ? 0 : (rankDiff > 0 ? 1 : -1)
        
        var currentFile = start.file.rawValue + fileDirection
        var currentRank = start.rank.rawValue + rankDirection
        
        while currentFile != end.file.rawValue || currentRank != end.rank.rawValue {
            guard let intermediateFile = File(rawValue: currentFile),
                  let intermediateRank = Rank(rawValue: currentRank) else {
                // This shouldn't happen if start and end are valid squares on the board
                return false
            }
            let intermediateSquare = Square(file: intermediateFile, rank: intermediateRank)
            
            // Check if there's a piece on the intermediate square
            if let piece = self.piece(at: intermediateSquare) {
                // Important: Only block if it's NOT the piece we're trying to ignore (e.g., for castling, the King/Rook might be on the start square during path check).
                // For a Bishop move, 'ignoring' will be nil, so any piece on the path blocks.
                let isPieceBeingIgnored = (ignoring != nil && piece == ignoring && intermediateSquare == start) // Refined check
                
                if !isPieceBeingIgnored {
                    return false // Path is blocked by another piece
                }
            }
            
            currentFile += fileDirection
            currentRank += rankDirection
        }
        return true // Path is clear
    }
}

