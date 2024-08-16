# AppSharedContext
模仿 SwiftUI Environment 的一个小工具

# 为什么？
用了 SwiftUI 的 Enviroment 之后，觉得特别好用，于是想模仿实现一个。

SwiftUI 主要场景用在 View 内，但是这个小工具不仅能用在 View 中，可以用在任何地方，虽然还不够完美，但是它简单 & 功能够用。

# 模块化
模块化是什么？各人有各人的理解，实现方式也多种多样，但不管什么样的理解和实现，都离不开一件事情：模块间数据的交流。

这个小玩意，笔者目前主要用于做模块化的工作，特别好用，它很好地充当了模块间的胶水，也可以理解为事件总线。缺点就是所有模块都要依赖它，但这并不是什么大问题，因为不管模块化程度如何高，总会有一两个全局核心依赖，而这个小工具恰好就是其中一个核心依赖。


# Example
假如我们有一个模块，需要公开给外部使用，但是又希望把修改的权限限制在模块内。

### User
``` Swift
// 如果是单纯的 entity 对象，只用来传达数据，不希望被外部修改，也不希望引起其他副作用的
// 请务必使用 Sendable 协议！
public struct User: Sendable, Identifiable {
    
    public init(id: String, name: String, nickName: String?) {
        self.id = id
        self.name = name
        self.nickName = nickName
    }
    
    public let id: String
    public let name: String
    public let nickName: String?
}

```
 
 ### UserService
 > 遵循 AppSharedContextUpdating 协议以获得更新 sharedContext 的权限
``` Swift
import AppSharedContext

public protocol UserServiceProtocol {
    func login(_ userId: String) -> Void
    func logout() -> Void
}


public class MockUserService: UserServiceProtocol, AppSharedContextUpdating {
    
    @AppSharedContext(\.currentUser)
    var currentUser
    
    public func login(_ userId: String) {
        self.sharedContext(\.currentUser, User(id: userId, name: "UserName", nickName: nil))
    }
    
    public func logout() {
        // 我们通常限制登出为唯一可以将 user 置 nil 的方法
        self.sharedContext(\.currentUser, nil)
    }
}

// 对外公开的 UserService，UserModule 的唯一操作接口
struct UserServiceCtxKey: AppSharedContextKey {
    static var defaultValue: UserServiceProtocol = MockUserService()
}

// 对外公开的当前用户信息，限制为只能在 UserModule 中写入
struct CurrentUserCtxKey: AppSharedContextKey {
    static var defaultValue: User? = User(id: "0", name: "", nickName: nil)
}


extension AppSharedContextValues {
    //
    // 用这个组件有个好处，可以权限限制
    // 我们限制 service 只在 UserModule 内可写，但随处可读
    // 这样我们可以保证所有用户相关的数据源都只有一个出口，方便维护 & 排查问题
    //
    public internal(set) var userService: UserServiceProtocol {
        get {
            self[UserServiceCtxKey.self]
        }
        
        set {
            self[UserServiceCtxKey.self] = newValue
        }
    }
    
    //
    // 模块内可写，模块外可读，防止在某人在某个地方修改了导致不明问题
    //
    public internal(set) var currentUser: User? {
        get {
            self[CurrentUserCtxKey.self]
        }
        
        set {
            self[CurrentUserCtxKey.self] = newValue
        }
    }
}
```
