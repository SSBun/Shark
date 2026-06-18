//
//  CodexSessionRuntimeState.swift
//  Shark
//

import Foundation

enum CodexSessionRuntimeState: Hashable {
    case inactive
    case runningInTerminal(tty: String?, pid: Int32?, iTermSessionID: String?)

    var terminalTTY: String? {
        if case let .runningInTerminal(tty, _, _) = self {
            return tty
        }
        return nil
    }

    var iTermSessionID: String? {
        if case let .runningInTerminal(_, _, iTermSessionID) = self {
            return iTermSessionID
        }
        return nil
    }

    var isRunningInTerminal: Bool {
        if case .runningInTerminal = self {
            return true
        }
        return false
    }
}
