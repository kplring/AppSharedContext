//
//  AppSharedContextKey.swift
//
//
//  Created by zh89 on 2024/8/8.
//

import Foundation

public protocol AppSharedContextKey {
    
    associatedtype Value
    
    static var defaultValue: Self.Value { get }
    
}
