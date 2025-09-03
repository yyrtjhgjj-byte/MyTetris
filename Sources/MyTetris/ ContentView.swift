import SwiftUI

struct Position: Equatable {
    var col: Int
    var row: Int
}

struct ContentView: View {
    // --- State Properties ---
    @State private var gameBoard = GameBoard()
    @State private var currentTetrimino: Tetrimino?
    @State private var tetriminoPosition = Position(col: 4, row: 0)
    @State private var timer: Timer?
    @State private var score = 0
    @State private var isGameOver = false
    @State private var level = 1
    @State private var totalLinesCleared = 0
    @StateObject private var tetriminoFactory = TetriminoFactory()
    @State private var heldTetrimino: Tetrimino?
    @State private var hasHeldInTurn = false
    @State private var ghostPosition: Position?
    
    // --- Lock Down Properties ---
    @State private var lockDownTimer: Timer?
    @State private var lowestRowReached: Int = 0
    @State private var placementMoves: Int = 0
    
    // --- Pause Property ---
    @State private var isPaused = false
    
    // --- Gameplay Logic Properties ---
    @State private var lastMoveWasRotation = false
    @State private var clearMessage: String?
    @State private var renCounter = -1
    @State private var isBackToBackActive = false
    
    // --- Gesture Properties ---
    @State private var gameBoardSize: CGSize = .zero
    @State private var lastDragPosX: CGFloat = 0.0
    @State private var isDragging = false
    @State private var softDropTimer: Timer?
    @State private var isSoftDropping = false
    
    // --- Constants ---
    let cellSize: CGFloat = 18
    
    // `body` は下の View Components extension の中にあります
}

// MARK: - View Components
extension ContentView {
    
    var body: some View {
        VStack {
            scoreHeader
            
            HStack {
                Spacer()
                gameplayHStack
                Spacer()
            }
            
            controlButtons.padding(.top, -15)
            utilityButtonsHStack.padding(.bottom)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear(perform: startGame)
        .onChange(of: tetriminoPosition) { updateGhostPosition() }
        .onChange(of: currentTetrimino?.rotationState) { updateGhostPosition() }
    }
    
    var scoreHeader: some View {
        HStack {
            Text("Level: \(level)").font(.title2).fontWeight(.bold).foregroundColor(.white)
            Spacer()
            Text("Score: \(score)").font(.title2).fontWeight(.bold).foregroundColor(.white)
        }
        .padding(.horizontal)
    }
    
    var gameplayHStack: some View {
        HStack(alignment: .top, spacing: 15) {
            holdDisplay
            gameBoardView
            nextDisplay
        }
        .padding(.vertical)
    }
    
    var holdDisplay: some View {
        VStack {
            Text("Hold")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            TetriminoView(tetrimino: heldTetrimino)
                .frame(width: 80, height: 80)
                .border(Color.gray, width: 1)
            Spacer()
        }
        .frame(width: 80)
    }
    
    var nextDisplay: some View {
        VStack {
            Text("Next")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            ForEach(0..<tetriminoFactory.nextQueue.count, id: \.self) { index in
                if index < 4 {
                    TetriminoView(tetrimino: tetriminoFactory.nextQueue[index])
                        .frame(width: 80, height: 80)
                        .border(Color.gray, width: 1)
                }
            }
            Spacer()
        }
        .frame(width: 80)
    }
    
    var utilityButtonsHStack: some View {
        HStack(spacing: 20) {
            Button("Restart") {
                restartGame()
            }
            .padding(10).background(Color.white).foregroundColor(.black).cornerRadius(8)
            
            Button(isPaused ? "Resume" : "Pause") {
                togglePause()
            }
            .padding(10).background(Color.white).foregroundColor(.black).cornerRadius(8)
            
            Button(action: { hold() }) {
                Text("HOLD").font(.headline).padding(10)
                    .background(hasHeldInTurn ? Color.gray : Color.white)
                    .foregroundColor(.black).cornerRadius(8)
            }.disabled(hasHeldInTurn || isGameOver || isPaused)
        }
    }
    
    var gameBoardView: some View {
        ZStack {
            boardGrid
            ghostPiece
            activePiece
            
            if let message = clearMessage {
                VStack {
                    Text(message)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 5)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.top, 40)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                lastDragPosX = value.startLocation.x
                            }
                            handleDragChange(value)
                        }
                        .onEnded { value in
                            handleGestureEnd(value)
                        }
                )
            
            gameOverOverlay
        }
        .background(
            GeometryReader { geometry in
                Color.clear.onAppear { self.gameBoardSize = geometry.size }
            }
        )
    }
    
    var boardGrid: some View {
        VStack(spacing: 1) {
            ForEach(0..<gameBoard.rows, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<gameBoard.columns, id: \.self) { col in
                        Rectangle().frame(width: cellSize, height: cellSize)
                            .foregroundColor(colorForCell(cellType: gameBoard.grid[row][col]))
                    }
                }
            }
        }.background(Color.black)
    }
    
    var ghostPiece: some View {
        Group {
            if let tetrimino = currentTetrimino, let position = ghostPosition {
                pieceView(for: tetrimino, at: position, opacity: 0.3)
            }
        }
    }
    
    var activePiece: some View {
        Group {
            if let tetrimino = currentTetrimino {
                pieceView(for: tetrimino, at: tetriminoPosition, opacity: 1.0)
            }
        }
    }
    
    var gameOverOverlay: some View {
        Group {
            if isGameOver {
                Color.black.opacity(0.75)
                VStack(spacing: 20) {
                    Text("Game Over").font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    Text("Your Score: \(score)").font(.title2).foregroundColor(.white)
                    Button("Restart") { restartGame() }
                        .padding().background(Color.white).foregroundColor(.black).cornerRadius(10)
                }
            } else if isPaused {
                Color.black.opacity(0.75)
                VStack(spacing: 10) {
                    Text("Paused").font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    Text("Press 'Resume' to continue").foregroundColor(.white)
                }
            }
        }
    }
    
    var controlButtons: some View {
        VStack {
            Button(action: { hardDrop() }) { Image(systemName: "arrow.up.circle.fill").font(.largeTitle) }
            HStack(spacing: 40) {
                Button(action: { moveTetrimino(dx: -1) }) { Image(systemName: "arrow.left.circle.fill").font(.largeTitle) }
                Button(action: { rotateTetrimino(clockwise: true) }) { Image(systemName: "arrow.clockwise.circle.fill").font(.largeTitle) }
                Button(action: { moveTetrimino(dx: 1) }) { Image(systemName: "arrow.right.circle.fill").font(.largeTitle) }
            }
            Button(action: { moveTetriminoDown() }) { Image(systemName: "arrow.down.circle.fill").font(.largeTitle) }
        }.disabled(isGameOver || isPaused)
    }
    
    func pieceView(for tetrimino: Tetrimino, at position: Position, opacity: Double) -> some View {
        ForEach(0..<tetrimino.currentShape.count, id: \.self) { index in
            let block = tetrimino.currentShape[index]
            Rectangle().frame(width: cellSize, height: cellSize)
                .foregroundColor(tetrimino.color.opacity(opacity))
                .offset(
                    x: CGFloat(position.col + block.col - gameBoard.columns / 2) * (cellSize + 1) + (cellSize + 1)/2,
                    y: CGFloat(position.row + block.row - gameBoard.rows / 2) * (cellSize + 1) + (cellSize + 1)/2
                )
        }
    }
    
    struct TetriminoView: View {
        let tetrimino: Tetrimino?
        let cellSize: CGFloat = 12
        var body: some View {
            ZStack {
                if let tetrimino = tetrimino {
                    ForEach(0..<tetrimino.currentShape.count, id: \.self) { index in
                        let block = tetrimino.currentShape[index]
                        Rectangle().frame(width: cellSize, height: cellSize)
                            .foregroundColor(tetrimino.color)
                            .offset(x: CGFloat(block.col) * (cellSize + 1), y: CGFloat(block.row) * (cellSize + 1))
                    }
                } else {
                    Rectangle().foregroundColor(.clear)
                }
            }
        }
    }
}

// MARK: - Game Logic Functions
extension ContentView {
    
    func startGame() {
        spawnNewTetrimino()
        startTimer()
    }
    
    func restartGame() {
        gameBoard = GameBoard()
        score = 0
        level = 1
        totalLinesCleared = 0
        isGameOver = false
        isPaused = false
        currentTetrimino = nil
        heldTetrimino = nil
        hasHeldInTurn = false
        ghostPosition = nil
        clearMessage = nil
        timer?.invalidate()
        lockDownTimer?.invalidate(); lockDownTimer = nil
        softDropTimer?.invalidate(); softDropTimer = nil
        renCounter = -1
        isBackToBackActive = false
        tetriminoFactory.reset()
        startGame()
    }
    
    func togglePause() {
        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
            lockDownTimer?.invalidate()
            softDropTimer?.invalidate()
        } else {
            startTimer()
        }
    }
    
    func startTimer() {
        guard !isSoftDropping else { return }
        timer?.invalidate()
        let fallSpeed = calculateFallSpeed(for: level)
        timer = Timer.scheduledTimer(withTimeInterval: fallSpeed, repeats: true) { _ in
            moveTetriminoDown()
        }
    }
    
    func calculateFallSpeed(for level: Int) -> TimeInterval {
        return pow(0.8 - (Double(level - 1) * 0.007), Double(level - 1))
    }
    
    func levelUpIfNeeded(linesCleared: Int) {
        totalLinesCleared += linesCleared
        let newLevel = (totalLinesCleared / 10) + 1
        if newLevel > level {
            level = newLevel
            startTimer()
        }
    }
    
    func updateGhostPosition() {
        guard let current = currentTetrimino else {
            ghostPosition = nil
            return
        }
        var position = tetriminoPosition
        while !checkCollision(for: current, at: Position(col: position.col, row: position.row + 1)) {
            position.row += 1
        }
        ghostPosition = position
    }
    
    func moveTetriminoDown() {
        guard !isGameOver, !isPaused, let current = currentTetrimino else { return }
        let nextPosition = Position(col: tetriminoPosition.col, row: tetriminoPosition.row + 1)
        if !checkCollision(for: current, at: nextPosition) {
            tetriminoPosition = nextPosition
            lockDownTimer?.invalidate()
            lockDownTimer = nil
            if !isSoftDropping {
                lastMoveWasRotation = false
            }
        } else {
            if lockDownTimer == nil {
                startLockDownTimer()
            }
        }
    }
    
    func moveTetrimino(dx: Int) {
        guard !isGameOver, !isPaused, let current = currentTetrimino else { return }
        let nextPosition = Position(col: tetriminoPosition.col + dx, row: tetriminoPosition.row)
        if !checkCollision(for: current, at: nextPosition) {
            tetriminoPosition = nextPosition
            resetLockDownTimerIfNeeded()
            lastMoveWasRotation = false
        }
    }
    
    func rotateTetrimino(clockwise: Bool = true) {
        guard !isGameOver, !isPaused, let current = currentTetrimino else { return }
        guard current.color != .yellow else { return }
        
        let rotated = current.rotated(clockwise: clockwise)
        let from = current.rotationState
        let to = rotated.rotationState
        let kickData = (current.color == .cyan) ? WallKick.iOffsets : WallKick.jlstzOffsets
        
        if let offsets = kickData.first(where: { $0.0 == (from, to) })?.1 {
            for offset in offsets {
                let nextPos = Position(col: tetriminoPosition.col + offset.col,
                                       row: tetriminoPosition.row - offset.row)
                if !checkCollision(for: rotated, at: nextPos) {
                    currentTetrimino = rotated
                    tetriminoPosition = nextPos
                    resetLockDownTimerIfNeeded()
                    lastMoveWasRotation = true
                    return
                }
            }
        }
    }
    
    func hardDrop() {
        guard !isGameOver, !isPaused, let _ = currentTetrimino, let ghost = ghostPosition else { return }
        
        let linesDropped = ghost.row - tetriminoPosition.row
        if linesDropped > 0 {
            score += linesDropped * 2
        }
        
        tetriminoPosition = ghost
        lastMoveWasRotation = false
        finalizePlacement()
    }
    
    func startLockDownTimer() {
        lockDownTimer?.invalidate()
        lowestRowReached = tetriminoPosition.row
        placementMoves = 0
        lockDownTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            finalizePlacement()
        }
    }
    
    func resetLockDownTimerIfNeeded() {
        if lockDownTimer != nil {
            placementMoves += 1
            if placementMoves > 15 {
                finalizePlacement()
                return
            }
            if tetriminoPosition.row > lowestRowReached {
                lowestRowReached = tetriminoPosition.row
                placementMoves = 0
            }
            startLockDownTimer()
        }
    }
    
    func finalizePlacement() {
        lockDownTimer?.invalidate()
        lockDownTimer = nil
        placeTetrimino()
        spawnNewTetrimino()
    }
    
    func hold() {
        guard !isGameOver, !isPaused, !hasHeldInTurn else { return }
        if let current = currentTetrimino {
            hasHeldInTurn = true
            var toHold = current
            toHold.rotationState = 0
            
            if let held = heldTetrimino {
                heldTetrimino = toHold
                currentTetrimino = held
            } else {
                heldTetrimino = toHold
                spawnNewTetrimino()
            }
            tetriminoPosition = Position(col: 4, row: 0)
            lockDownTimer?.invalidate(); lockDownTimer = nil
            updateGhostPosition()
        }
    }
    
    func placeTetrimino() {
        guard !isGameOver, let tetrimino = currentTetrimino else { return }
        
        let wasTSpin = isTSpin(position: tetriminoPosition)
        
        for block in tetrimino.currentShape {
            let col = tetriminoPosition.col + block.col
            let row = tetriminoPosition.row + block.row
            if row >= 0 && row < gameBoard.rows && col >= 0 && col < gameBoard.columns {
                gameBoard.grid[row][col] = .filled(tetrimino.color)
            }
        }
        hasHeldInTurn = false
        clearLines(wasTSpin: wasTSpin)
    }
    
    func spawnNewTetrimino() {
        currentTetrimino = tetriminoFactory.getNext()
        tetriminoPosition = Position(col: 4, row: 0)
        lockDownTimer?.invalidate(); lockDownTimer = nil
        updateGhostPosition()
        if let current = currentTetrimino, checkCollision(for: current, at: tetriminoPosition) {
            isGameOver = true
            timer?.invalidate()
            timer = nil
        }
    }
    
    func clearLines(wasTSpin: Bool) {
        var clearedRowIndices: [Int] = []
        for i in 0..<gameBoard.rows {
            if !gameBoard.grid[i].contains(where: { if case .empty = $0 { return true } else { return false } }) {
                clearedRowIndices.append(i)
            }
        }
        
        if clearedRowIndices.isEmpty {
            renCounter = -1
            return
        }
        
        renCounter += 1
        
        for rowIndex in clearedRowIndices {
            for colIndex in 0..<gameBoard.columns {
                gameBoard.grid[rowIndex][colIndex] = .clearing
            }
        }
        
        let linesCleared = clearedRowIndices.count
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            gameBoard.grid.removeAll { row in
                if case .clearing = row.first { return true }
                return false
            }
            
            for _ in 0..<linesCleared {
                let newRow = Array(repeating: CellType.empty, count: gameBoard.columns)
                gameBoard.grid.insert(newRow, at: 0)
            }
            
            addScore(lines: linesCleared, wasTSpin: wasTSpin, ren: renCounter)
            levelUpIfNeeded(linesCleared: linesCleared)
        }
    }
    
    func isTSpin(position: Position) -> Bool {
        guard let tetrimino = currentTetrimino, tetrimino.color == .purple, lastMoveWasRotation else {
            return false
        }
        
        let corners = [
            Position(col: position.col - 1, row: position.row - 1),
            Position(col: position.col + 1, row: position.row - 1),
            Position(col: position.col - 1, row: position.row + 1),
            Position(col: position.col + 1, row: position.row + 1)
        ]
        
        var occupiedCorners = 0
        for corner in corners {
            if corner.col < 0 || corner.col >= gameBoard.columns || corner.row >= gameBoard.rows {
                occupiedCorners += 1
            } else if corner.row >= 0 {
                if case .filled = gameBoard.grid[corner.row][corner.col] {
                    occupiedCorners += 1
                }
            }
        }
        
        return occupiedCorners >= 3
    }
    
    func addScore(lines: Int, wasTSpin: Bool, ren: Int) {
        var baseScore = 0
        var clearMessageText = ""
        var messageComponents: [String] = []
        
        if wasTSpin {
            switch lines {
            case 1: baseScore = 800; clearMessageText = "T-Spin Single"
            case 2: baseScore = 1200; clearMessageText = "T-Spin Double"
            case 3: baseScore = 1600; clearMessageText = "T-Spin Triple"
            default: break
            }
        } else {
            switch lines {
            case 1: baseScore = 100; clearMessageText = "Single"
            case 2: baseScore = 300; clearMessageText = "Double"
            case 3: baseScore = 500; clearMessageText = "Triple"
            case 4: baseScore = 800; clearMessageText = "Tetris"
            default: break
            }
        }
        
        let isDifficultClear = (lines == 4 && !wasTSpin) || (wasTSpin && lines > 0)
        var b2bMultiplier = 1.0
        
        if isDifficultClear {
            if isBackToBackActive {
                b2bMultiplier = 1.5
                messageComponents.append("Back-to-Back")
            }
            isBackToBackActive = true
        } else if lines > 0 {
            isBackToBackActive = false
        }
        
        var renBonus = 0
        if ren > 0 {
            let renBonusTable = [0, 50, 100, 200, 400, 800, 1200, 1600, 2000]
            renBonus = ((ren < renBonusTable.count) ? renBonusTable[ren] : 2000) * level
            messageComponents.append("\(ren) REN")
        }
        
        let finalScore = Int(Double(baseScore * level) * b2bMultiplier) + renBonus
        score += finalScore
        
        messageComponents.sort()
        messageComponents.insert(clearMessageText, at: 0)
        
        let finalMessage = messageComponents.joined(separator: "\n")
        if !finalMessage.isEmpty {
            withAnimation {
                self.clearMessage = finalMessage
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    self.clearMessage = nil
                }
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

// MARK: - Gesture Handler Functions
extension ContentView {
    
    func handleDragChange(_ value: DragGesture.Value) {
        guard !isGameOver, !isPaused else { return }
        
        if abs(value.translation.width) > abs(value.translation.height) {
            let dragDistanceX = value.location.x - lastDragPosX
            let moveThresholdX = cellSize * 1.5
            
            if abs(dragDistanceX) > moveThresholdX {
                let direction = dragDistanceX > 0 ? 1 : -1
                moveTetrimino(dx: direction)
                lastDragPosX = value.location.x
                lastMoveWasRotation = false
            }
            
            if isSoftDropping {
                stopSoftDrop()
            }
            
        } else {
            if value.translation.height > cellSize && !isSoftDropping {
                isSoftDropping = true
                startSoftDrop()
            }
            
            if value.translation.height < cellSize && isSoftDropping {
                stopSoftDrop()
            }
        }
    }
    
    func handleGestureEnd(_ value: DragGesture.Value) {
        guard !isGameOver, !isPaused else { return }
        
        stopSoftDrop()
        
        let horizontalMove = value.translation.width
        let verticalMove = value.translation.height
        let tapThreshold: CGFloat = 25
        let swipeThreshold: CGFloat = 50
        
        if abs(horizontalMove) < tapThreshold && abs(verticalMove) < tapThreshold {
            if value.startLocation.x < gameBoardSize.width / 2 {
                rotateTetrimino(clockwise: false)
            } else {
                rotateTetrimino(clockwise: true)
            }
            
        } else if abs(verticalMove) > abs(horizontalMove) && verticalMove < -swipeThreshold {
            hardDrop()
        }
        
        lastDragPosX = 0.0
        isDragging = false
    }
    
    func startSoftDrop() {
        timer?.invalidate()
        softDropTimer?.invalidate()
        
        softDropTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            score += 1
            moveTetriminoDown()
        }
    }
    
    func stopSoftDrop() {
        if isSoftDropping {
            isSoftDropping = false
        }
        softDropTimer?.invalidate()
        softDropTimer = nil
        
        startTimer()
    }
}
