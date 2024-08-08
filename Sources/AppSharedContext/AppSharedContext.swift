// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@propertyWrapper
public struct AppSharedContext<Value> {
    
    // 声明为 KeyPath 可以限制写入
    private let keyPath: KeyPath<AppSharedContextValues, Value>
    
    public var wrappedValue: Value {
        get {
            AppSharedContextValues.shared[keyPath: keyPath]
        }
    }
    
    public init(_ keyPath: KeyPath<AppSharedContextValues, Value>) {
        self.keyPath = keyPath
    }
    
}

fileprivate func observedKeyPathDictKey<Value>(_ keyPath: KeyPath<AppSharedContextValues, Value>) -> String {
    // 一个字符串而已，实际上什么格式无所谓的...
    return "obs.\(String(reflecting: keyPath))"
}

fileprivate final class AppSharedContextObservableWrapper {
    var subscribers: [Subscriber<AnyObject>]
    
    init(subscribers: [Subscriber<AnyObject>] = []) {
        self.subscribers = subscribers
    }
    
    class Subscriber<Target: AnyObject> {
        let action: (Any?, Any?) -> Void
        weak var target: Target?
        
        init(action: @escaping (Any?, Any?) -> Void, target: Target?) {
            self.action = action
            self.target = target
        }
    }
}

/**
 context values 本质是存储全局属性的挂载点
 我们可以将所有模块用到属性都挂载到这里，可以明确数据源
 */
public final class AppSharedContextValues {
    
    // 字典的 key 要求 Hashable，不能直接用 keyPath 的类型做 key，简单点用 string 吧...
    // the key type use string because the dict's key require to compliant Hashable protocol
    private var contextValueDict: [String: Any] = [:]
    
    private var observedKeyPathValueDict: [String: AppSharedContextObservableWrapper] = [:]

    // 设置为 fileprivate 只允许 AppShareContext 读取
    // 所有的全局变量都会放到这里
    // all global values will sotre here
    fileprivate static let shared = AppSharedContextValues()
    
    private let lock = NSRecursiveLock()

    private init() {}
    
    private func observedWrapper(_ forKey: String) -> AppSharedContextObservableWrapper? {
        return observedKeyPathValueDict[forKey]
    }
    
    fileprivate func updateObservedWrapper(_ forKey: String, 
                                           subscriber: AppSharedContextObservableWrapper.Subscriber<AnyObject>) -> Void {
        
        self.lock.lock()
        
        if let wrapper = observedWrapper(forKey) {
            wrapper.subscribers.append(subscriber)
        }
        else {
            let wrapper = AppSharedContextObservableWrapper()
            wrapper.subscribers.append(subscriber)
            observedKeyPathValueDict[forKey] = wrapper
        }
        
        self.lock.unlock()
    }
    
    fileprivate func doNotifyIfNeeded<Value>(_ oldVal: Value, _ newVal: Value, forKey key: String) -> Void {
        if let wrapper = observedWrapper(key) {
            var releasedCount = 0
            wrapper.subscribers.filter { sub in
                // 过滤已经释放了的
                let notNil = sub.target != nil
                if !notNil {
                    releasedCount += 1
                }
                return notNil
            }
            .map { sub in
                autoreleasepool {
                    sub.action(oldVal, newVal)
                }
            }
            
            // 释放的 >= 10 时，处理一下，每次都调用就太频繁了，不至于不至于...
            if releasedCount >= 10 {
                wrapper.subscribers = wrapper.subscribers.filter( { $0.target != nil } )
            }
        }
    }
    

    public subscript<K>(key: K.Type) -> K.Value where K : AppSharedContextKey {
        get {
            let keyStr = String(reflecting: key)
            self.lock.lock()
            let value = Self.shared.contextValueDict[keyStr] as? K.Value ?? key.defaultValue
            self.lock.unlock()
            return value
        }
        
        set {
            let keyStr = String(reflecting: key)
            self.lock.lock()
            Self.shared.contextValueDict[keyStr] = newValue
            self.lock.unlock()
        }
    }
}


public extension AppSharedContextUpdating {
    func sharedContext<Value>(_ keyPath: ReferenceWritableKeyPath<AppSharedContextValues, Value>, _ value: Value) -> Void {
        let old = AppSharedContextValues.shared[keyPath: keyPath]
        AppSharedContextValues.shared[keyPath: keyPath] = value
        // notify
        AppSharedContextValues.shared.doNotifyIfNeeded(old, value, forKey: observedKeyPathDictKey(keyPath))
    }
}

public extension AppSharedContextObserving where Self: AnyObject {
    func observe<Value>(_ keyPath: KeyPath<AppSharedContextValues, Value>, onChanged: @escaping (_ oldValue: Value, _ newValue: Value)->Void) -> Void {
        
        let key = observedKeyPathDictKey(keyPath)
        
        let wrappedAction: (Any?, Any?) -> Void = { old, new in
            if let oldVal = old as? Value, let newVal = new as? Value {
                onChanged(oldVal, newVal)
            }
        }
        
        AppSharedContextValues
            .shared
            .updateObservedWrapper(key, subscriber: .init(action: wrappedAction, target: self))
    }
}

