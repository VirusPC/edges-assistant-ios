# Edges 小助手

索引 [VirusPC/edges](https://github.com/VirusPC/edges) 框架仓的原生 iOS 客户端。输入问题，向公开接口提问，看回答和引用。

建议的仓库发布名：`edges-assistant-ios` 或 `EdgesAssistant`。Xcode 工程名是 `EdgesAssistant`。

这个仓库只有客户端。没有后端，也不依赖 VirusPC/edges-rag 的代码。

## 要求

- Mac
- Xcode 15 或更新版本
- iOS 17 或更新的模拟器，或一台 iPhone / iPad

不使用 Swift Package、CocoaPods 或 WKWebView。

## 打开并运行

1. 用 Xcode 打开 `EdgesAssistant.xcodeproj`。
2. 左上角 scheme 选 **EdgesAssistant**。
3. 目标选一台 iOS 17+ 模拟器，按 Run。

模拟器通常不需要登录 Apple ID。如果 Xcode 提示要选择 Team，用下面「免费 Apple ID」里的 Signing 步骤选一次 Personal Team 即可。

## 用免费 Apple ID 在真机调试

不需要付费的 Apple Developer Program。

1. 在 Mac App Store 安装 Xcode，用免费 Apple ID 登录：Xcode → Settings → Accounts → 加入你的 Apple ID。
2. iPhone 用数据线连上 Mac。手机弹出「要信任此电脑吗？」时选择信任，并按提示输入手机锁屏密码。
3. 打开 `EdgesAssistant.xcodeproj`。左上角设备选你的 iPhone，不要选模拟器。
4. 点工程里的 **EdgesAssistant** target → **Signing & Capabilities**。勾选 **Automatically manage signing**，Team 选你的 **Personal Team**。
5. 如果提示 Bundle Identifier 不能用，把 `tech.viruspc.edges.assistant` 改成你自己的，例如 `com.yourname.edges-assistant`。
6. 按 Run。第一次在 iOS 16 及以上安装开发版 App 时，手机要打开开发者模式：设置 → 隐私与安全性 → 开发者模式，按提示重启。
7. 如果 App 装上了但打不开：设置 → 通用 → VPN 与设备管理，信任你的开发者证书。
8. 免费个人证书签名的 App 大约 7 天后会过期。过期后用同一台 Mac 再 Run 一次即可。

这个 App 只用网络请求和本机保存的接口地址，不开推送、Associated Domains 或其他需要付费账号的能力。

## 本仓库不负责上架

这里没有 App Store 账号、分发证书、截图、隐私政策或审核材料。需要上架时请自行处理。

## 接口

默认请求：

```http
POST https://edges-rag.viruspc.tech/api/ask
Content-Type: application/json

{"question":"Edges 是什么？"}
```

成功时响应：

```json
{
  "answer": "……",
  "citations": [
    {"path": "README.md", "snippet": "……", "score": 0.86}
  ]
}
```

`citations` 缺省时按空列表处理。公网地址是 HTTPS，Info.plist 里没有 ATS 例外，默认可以直接问。请求最多等待约 90 秒。

界面上的「看示例回答」只展示写在 `AskAPI.swift` 里的本地短示例，不会发请求。

## 改接口地址

两处，都只改 base，不要自己拼 `/api/ask`（如果粘贴的地址已经以 `/api/ask` 结尾，App 不会再加一遍）。

- 编译进 App 的默认值：`AskAPI.swift` 里的 `APIConfig.defaultBaseURL`。
- 某一台设备上的覆盖：App 底部「接口地址」。会记在本机，点「恢复默认」回到上面的常量。留空再提问也使用默认公网地址。

要改走 Tailscale 时，把网页「备用入口」里当时的地址填进来，去掉末尾斜杠。App 不写死内网 IP。

### 明文 HTTP 和 ATS

公网 `https://edges-rag.viruspc.tech` 不需要 ATS 例外。

iOS 默认拒绝明文 `http://`。网页上的 Tailscale 入口如果是 `http://100.x.x.x:8001` 这种地址：

- `NSExceptionDomains` 只对主机名有效，对纯 IP 常常放行不了。
- 不建议打开 `NSAllowsArbitraryLoads`。能用 HTTPS，或能用带证书的主机名时，优先那样做。
- 若暂时必须访问某个明文主机名，在 target → Info 增加 App Transport Security Settings，只放行那个主机，例如：

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
    <key>example.tailnet.ts.net</key>
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key>
      <true/>
      <key>NSIncludesSubdomains</key>
      <false/>
    </dict>
  </dict>
</dict>
```

工程没有自带 Info.plist，上面的键是生成出来的。在 target → Info 里添加即可，Xcode 会写进生成的 Info.plist。

## 工程打不开时

用 Xcode 新建一个 App，再把源码拖进去：

1. File → New → Project → iOS → App。
2. Product Name 填 `EdgesAssistant`，Interface 选 **SwiftUI**，Language 选 **Swift**，Storage 选 **None**。最低版本选 **iOS 17.0**。
3. 把本仓库 `EdgesAssistant/` 里的三个 Swift 文件和 `Assets.xcassets` 拖进新工程。勾选 **Copy items if needed** 和这个 App target。
4. 删掉模板自带的 `ContentView.swift` 和 `…App.swift`，只留拖进去的那份。整个 target 里只能有一个 `@main`。
5. target → General：Display Name 填 `Edges 小助手`，Minimum Deployments 选 iOS 17.0。
6. 不要加 WKWebView，也不要为公网 HTTPS 加 ATS 例外。

## 目录

```
EdgesAssistant.xcodeproj    用 Xcode 打开的工程
EdgesAssistant/
  EdgesAssistantApp.swift   入口
  ContentView.swift         问题、提问、加载、回答、引用、接口地址
  AskAPI.swift              请求、解码、本地示例、默认 base URL
  Assets.xcassets           图标和强调色
```
