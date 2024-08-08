//
//  AppSharedContextUpdating.swift
//  
//
//  Created by zh89 on 2024/8/8.
//

import Foundation

public protocol AppSharedContextUpdating {
    func sharedContext<Value>(_ keyPath: ReferenceWritableKeyPath<AppSharedContextValues, Value>, _ value: Value) -> Void
}
