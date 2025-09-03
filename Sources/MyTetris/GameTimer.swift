// このファイルも新しく作成します
import TokamakShim
import JavaScriptKit

// ContentViewからこのクラスを丸ごと移動します
class GameTimer: ObservableObject {
    var timer: JSValue? = nil

    func start(action: @escaping () -> Void) {
        stop()
        timer = JSObject.global.setInterval.function?(
            JSClosure { _ in
                action()
                return .undefined
            }, 1000)
    }

    func stop() {
        if let timer = timer {
            _ = JSObject.global.clearInterval.function?(timer)
            self.timer = nil
        }
    }
}
