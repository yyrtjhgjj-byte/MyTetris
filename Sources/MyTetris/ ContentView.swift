import TokamakShim
// JavaScriptの機能を呼び出すために必要
import JavaScriptKit

extension Color {
    static let cyan = Color(red: 0.0, green: 1.0, blue: 1.0)
    static let purple = Color(red: 0.5, green: 0, blue: 0.5)
}

// Timerの代わりに使う変数を定義
var timer: JSValue? = nil

struct ContentView: View {
    @State private var gameBoard = GameBoard()
    @State private var score = 0
    @State private var level = 1
    @State private var currentTetrimino: Tetrimino?
    @State private var tetriminoPosition = Position(col: 4, row: 0)
    @State private var isGameOver = false
    @StateObject private var tetriminoFactory = TetriminoFactory()

    // CGFloatをDoubleに修正
    let cellSize: Double = 18
    
    var body: some View {
        VStack {
            scoreHeader
            gameBoardView
        }
        .onAppear(perform: setupTimer) // .onReceiveの代わりに.onAppearと.onDisappearを使う
        .onDisappear(perform: clearTimer)
    }
    
    // Webブラウザのタイマー機能をセットアップする関数
    func setupTimer() {
        startGame()
        // 1000ミリ秒（1秒）ごとに moveTetriminoDown を呼び出す
        timer = JSObject.global.setInterval.function?(
            JSClosure { _ in
                moveTetriminoDown()
                return .undefined
            }, 1000)
    }
    
    // タイマーを停止する関数
    func clearTimer() {
        guard let timer = timer else { return }
        _ = JSObject.global.clearInterval.function?(timer)
    }
    
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
            
            if let tetrimino = currentTetrimino {
                ForEach(0..<tetrimino.currentShape.count, id: \.self) { index in
                    let block = tetrimino.currentShape[index]
                    Rectangle()
                        .frame(width: cellSize, height: cellSize)
                        .foregroundColor(tetrimino.color)
                        .position(
                            // CGFloatをDoubleにキャスト変換
                            x: (Double(tetriminoPosition.col + block.col) + 0.5) * (cellSize + 1),
                            y: (Double(tetriminoPosition.row + block.row) + 0.5) * (cellSize + 1)
                        )
                }
            }
        }
        // CGFloatをDoubleにキャスト変換
        .frame(width: Double(gameBoard.columns) * (cellSize + 1), height: Double(gameBoard.rows) * (cellSize + 1))
        .background(Color.black)
    }
    
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
