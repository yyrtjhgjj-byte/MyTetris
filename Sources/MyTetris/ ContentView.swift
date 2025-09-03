import TokamakShim

// Color.cyan など一部の色はTokamakにないので、ここで定義
extension Color {
    static let cyan = Color.blue
    static let purple = Color(red: 0.5, green: 0, blue: 0.5)
}

// Timerを管理しやすくするためのPublisher
let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

struct ContentView: View {
    // --- State Properties ---
    @State private var gameBoard = GameBoard()
    @State private var score = 0
    @State private var level = 1
    
    // --- 簡略化のため、一旦多くのStateをコメントアウト ---
    @State private var currentTetrimino: Tetrimino?
    @State private var tetriminoPosition = Position(col: 4, row: 0)
    //@State private var timer: Timer? // TokamakのTimerに置き換え
    @State private var isGameOver = false
    @State private var totalLinesCleared = 0
    @StateObject private var tetriminoFactory = TetriminoFactory()
    @State private var heldTetrimino: Tetrimino?
    @State private var hasHeldInTurn = false
    
    // --- Constants ---
    let cellSize: CGFloat = 18
    
    var body: some View {
        VStack {
            scoreHeader
            gameBoardView
        }
        .onAppear(perform: startGame)
        // TokamakのTimerで自動落下を処理
        .onReceive(timer) { _ in
            moveTetriminoDown()
        }
    }
    
    // MARK: - View Components
    
    var scoreHeader: some View {
        HStack {
            Text("Level: \(level)").font(.title2).fontWeight(.bold)
            Spacer()
            Text("Score: \(score)").font(.title2).fontWeight(.bold)
        }
        .padding(.horizontal)
    }

    var gameBoardView: some View {
        VStack(spacing: 1) {
            ForEach(0..<gameBoard.rows, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<gameBoard.columns, id: \.self) { col in
                        Rectangle().frame(width: cellSize, height: cellSize)
                            .foregroundColor(colorForCell(cellType: gameBoard.grid[row][col]))
                    }
                }
            }
        }
        .background(Color.black)
    }
    
    // MARK: - Game Logic
    
    func startGame() {
        gameBoard = GameBoard()
        score = 0
        level = 1
        tetriminoFactory.reset()
        spawnNewTetrimino()
    }
    
    func spawnNewTetrimino() {
        currentTetrimino = tetriminoFactory.getNext()
        tetriminoPosition = Position(col: 4, row: 0)
    }
    
    func moveTetriminoDown() {
        guard !isGameOver, let current = currentTetrimino else { return }
        let nextPosition = Position(col: tetriminoPosition.col, row: tetriminoPosition.row + 1)
        
        if !checkCollision(for: current, at: nextPosition) {
            tetriminoPosition.row += 1
        } else {
            placeTetrimino()
            spawnNewTetrimino()
        }
    }
    
    func placeTetrimino() {
        guard let tetrimino = currentTetrimino else { return }
        for block in tetrimino.currentShape {
            let col = tetriminoPosition.col + block.col
            let row = tetriminoPosition.row + block.row
            if row >= 0 && row < gameBoard.rows && col >= 0 && col < gameBoard.columns {
                gameBoard.grid[row][col] = .filled(tetrimino.color)
            }
        }
    }
    
    func checkCollision(for tetrimino: Tetrimino, at position: Position) -> Bool {
        for block in tetrimino.currentShape {
            let col = position.col + block.col
            let row = position.row + block.row
            if col < 0 || col >= gameBoard.columns || row >= gameBoard.rows { return true }
            if row < 0 { continue }
            if case .filled = gameBoard.grid[row][col] { return true }
        }
        return false
    }

    func colorForCell(cellType: CellType) -> Color {
        switch cellType {
        case .empty: return Color.gray.opacity(0.3)
        case .filled(let color): return color
        case .clearing: return Color.white
        }
    }
}
