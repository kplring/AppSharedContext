//
//  AppSharedContextObserving.swift
//  
//
//  Created by zh89 on 2024/8/8.
//

import Foundation

public protocol AppSharedContextObserving {
    func observe<Value>(_ keyPath: KeyPath<AppSharedContextValues, Value>, onChanged: @escaping (_ oldValue: Value, _ newValue: Value)->Void) -> Void
}

