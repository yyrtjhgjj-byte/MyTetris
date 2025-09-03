import SwiftUI

// テトリミノの基本となる構造体（データの箱）
struct Tetrimino {
    // 形状データ。4つの回転パターンを格納する
    let shapes: [[(col: Int, row: Int)]]
    // テトリミノの色
    let color: Color
    // 現在の回転状態 (0: North, 1: East, 2: South, 3: West)
    var rotationState: Int = 0
    
    // 現在の回転状態に応じた形状を返す
    var currentShape: [(col: Int, row: Int)] {
        // Oミノなど回転パターンが1つの場合でも安全に動作するように
        if shapes.count > rotationState {
            return shapes[rotationState]
        }
        return shapes[0]
    }
    
    // 回転後のテトリミノを返す関数
    func rotated(clockwise: Bool = true) -> Tetrimino {
        var newTetrimino = self
        if clockwise {
            // 時計回り
            newTetrimino.rotationState = (rotationState + 1) % shapes.count
        } else {
            // 反時計回り
            newTetrimino.rotationState = (rotationState + shapes.count - 1) % shapes.count
        }
        return newTetrimino
    }
}

// 各テトリミノを生成するためのクラス（バッグシステムとNextキューを管理）
class TetriminoFactory: ObservableObject {
    // バッグ（テトリミノの袋）
    private var tetriminoBag: [Tetrimino] = []
    
    // 7種類のテトリミノの原型
    private let tetriminoBlueprints: [Tetrimino] = [
        Tetrimino(shapes: [[(0, -1), (0, 0), (0, 1), (0, 2)], [(-1, 0), (0, 0), (1, 0), (2, 0)], [(0, -1), (0, 0), (0, 1), (0, 2)], [(-1, 0), (0, 0), (1, 0), (2, 0)]], color: .cyan), // I
        Tetrimino(shapes: [[(0, 0), (1, 0), (0, 1), (1, 1)]], color: .yellow), // O
        Tetrimino(shapes: [[(-1, 0), (0, 0), (1, 0), (0, 1)], [(0, -1), (0, 0), (0, 1), (-1, 0)], [(-1, 0), (0, 0), (1, 0), (0, -1)], [(0, -1), (0, 0), (0, 1), (1, 0)]], color: .purple), // T
        Tetrimino(shapes: [[(0, -1), (0, 0), (0, 1), (1, 1)], [(-1, 0), (0, 0), (1, 0), (-1, 1)], [(0, -1), (0, 0), (0, 1), (-1, -1)], [(-1, 0), (0, 0), (1, 0), (1, -1)]], color: .orange), // L
        Tetrimino(shapes: [[(0, -1), (0, 0), (0, 1), (-1, 1)], [(-1, 0), (0, 0), (1, 0), (1, 1)], [(0, -1), (0, 0), (0, 1), (1, -1)], [(-1, -1), (-1, 0), (0, 0), (1, 0)]], color: .blue), // J
        Tetrimino(shapes: [[(-1, 1), (0, 1), (0, 0), (1, 0)], [(0, -1), (0, 0), (1, 0), (1, 1)], [(-1, 1), (0, 1), (0, 0), (1, 0)], [(0, -1), (0, 0), (1, 0), (1, 1)]], color: .green), // S
        Tetrimino(shapes: [[(-1, 0), (0, 0), (0, 1), (1, 1)], [(1, -1), (1, 0), (0, 0), (0, 1)], [(-1, 0), (0, 0), (0, 1), (1, 1)], [(1, -1), (1, 0), (0, 0), (0, 1)]], color: .red) // Z
    ]
    
    @Published var nextQueue: [Tetrimino] = []
    private let queueSize = 5 // Nextに表示する数
    
    init() {
        refillBag()
        fillNextQueue()
    }
    
    // バッグを補充してシャッフルする
    private func refillBag() {
        tetriminoBag = tetriminoBlueprints.shuffled()
    }
    
    // 次のテトリミノをバッグから取り出す
    func getNext() -> Tetrimino {
        let nextTetrimino = nextQueue.removeFirst()
        fillNextQueue()
        return nextTetrimino
    }
    
    // Nextキューを常に満たすようにする
    private func fillNextQueue() {
        while nextQueue.count < queueSize {
            if tetriminoBag.isEmpty {
                refillBag()
            }
            nextQueue.append(tetriminoBag.removeFirst())
        }
    }
    
    // ゲームリスタート時に状態をリセットする
    func reset() {
        tetriminoBag = []
        nextQueue = []
        refillBag()
        fillNextQueue()
    }
}

struct WallKick {
    // J, L, S, T, Z テトリミノ用のオフセットデータ
    // (回転前の状態, 回転後の状態) -> [オフセットのリスト]
    static let jlstzOffsets: [((Int, Int), [(col: Int, row: Int)])] = [
        ((0, 1), [(0, 0), (-1, 0), (-1, 1), (0, -2), (-1, -2)]), // 0->1
        ((1, 0), [(0, 0), (1, 0), (1, -1), (0, 2), (1, 2)]),    // 1->0
        ((1, 2), [(0, 0), (1, 0), (1, -1), (0, 2), (1, 2)]),    // 1->2
        ((2, 1), [(0, 0), (-1, 0), (-1, 1), (0, -2), (-1, -2)]), // 2->1
        ((2, 3), [(0, 0), (1, 0), (1, 1), (0, -2), (1, -2)]),    // 2->3
        ((3, 2), [(0, 0), (-1, 0), (-1, -1), (0, 2), (-1, 2)]), // 3->2
        ((3, 0), [(0, 0), (-1, 0), (-1, -1), (0, 2), (-1, 2)]), // 3->0
        ((0, 3), [(0, 0), (1, 0), (1, 1), (0, -2), (1, -2)])     // 0->3 (反時計回り用)
    ]
    
    // I テトリミノ用のオフセットデータ
    static let iOffsets: [((Int, Int), [(col: Int, row: Int)])] = [
        ((0, 1), [(0, 0), (-2, 0), (1, 0), (-2, -1), (1, 2)]),  // 0->1
        ((1, 0), [(0, 0), (2, 0), (-1, 0), (2, 1), (-1, -2)]),   // 1->0
        ((1, 2), [(0, 0), (-1, 0), (2, 0), (-1, 2), (2, -1)]),  // 1->2
        ((2, 1), [(0, 0), (1, 0), (-2, 0), (1, -2), (-2, 1)]),   // 2->1
        ((2, 3), [(0, 0), (2, 0), (-1, 0), (2, 1), (-1, -2)]),   // 2->3
        ((3, 2), [(0, 0), (-2, 0), (1, 0), (-2, -1), (1, 2)]),  // 3->2
        ((3, 0), [(0, 0), (1, 0), (-2, 0), (1, -2), (-2, 1)]),   // 3->0
        ((0, 3), [(0, 0), (-1, 0), (2, 0), (-1, 2), (2, -1)])    // 0->3 (反時計回り用)
    ]
}
