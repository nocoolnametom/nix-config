import Cocoa
import Foundation

let screens = NSScreen.screens

let maxInset = screens.map { Int(ceil($0.safeAreaInsets.top)) }.max() ?? 0

// Built-in heuristic: any screen reporting a non-zero top safe area is the
// built-in (only notched MBP built-ins do this). Fallback to localizedName
// match for older notchless built-ins.
let builtinIndex: Int? = screens.enumerated().first { (_, screen) in
    screen.safeAreaInsets.top > 0
        || screen.localizedName.localizedCaseInsensitiveContains("built-in")
}.map { $0.offset + 1 }

let externals = screens.enumerated()
    .filter { (i, _) in (i + 1) != (builtinIndex ?? -1) }
    .map { String($0.offset + 1) }
    .joined(separator: ",")

print("NOTCH_INSET=\(maxInset)")
print("BUILTIN_DISPLAY=\(builtinIndex.map(String.init) ?? "")")
print("EXTERNAL_DISPLAYS=\(externals)")
