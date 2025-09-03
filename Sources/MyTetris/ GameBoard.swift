import SwiftUI

// マス（セル）の種類を定義します
// enum（イーナム）は「いくつかの種類の中から一つを選ぶ」形式のデータを定義するときに便利です
enum CellType {
    case empty        // 何もない空の状態
    case filled(Color) // 色付きのブロックで埋まっている状態
    case clearing
}

// struct（ストラクト）は、関連するデータを一つにまとめる「箱」のようなものです
struct GameBoard {
    let rows = 20
    let columns = 10
    
    // 2次元配列。盤面のすべてのマスの状態を保存します
    var grid: [[CellType]]
    
    // GameBoardが作られたときに、最初に実行される処理
    init() {
        // すべてのマスを「.empty（空っぽ）」で初期化します
        grid = Array(repeating: Array(repeating: .empty, count: columns), count: rows)
    }
}
