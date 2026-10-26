# AppleDeviceInfo

一个零第三方依赖的 Swift 包，统一读取 iOS 与 macOS 的机型和设备名称。

- iOS：通过 SPM 引入 `AppleDeviceInfo` library。
- macOS / Electron：将同一份核心编译为 `device-info`，主进程通过标准输出读取 JSON。
- 最低版本：iOS 13、macOS 10.15、Swift 5.9。支持 arm64 / x86_64 Mac。
- 按需查询，没有常驻服务、遥测、名称落盘或轮询。

## iOS：SPM

Xcode 的 Add Package Dependencies 中添加仓库 URL，选择 `AppleDeviceInfo` product：

```text
https://github.com/fanjiashu/AppleDeviceInfo.git
```

也可以在 `Package.swift` 中声明：

```swift
.package(url: "https://github.com/fanjiashu/AppleDeviceInfo.git", from: "0.1.0")
// 对应 target.dependencies：
.product(name: "AppleDeviceInfo", package: "AppleDeviceInfo")
```

私有仓库需要在 Xcode / Git 中配置有访问权限的 GitHub 账号。

```swift
import AppleDeviceInfo

@MainActor
func readDevice() {
    let info = AppleDevice.current()
    print(info.modelIdentifier)  // iPhone15,2
    print(info.displayModel)     // iPhone 14 Pro
    print(info.userAssignedName as Any)
    print(info.displayName)
}

// 从其他 actor / 后台任务调用：
// let info = await AppleDevice.current()
```

`current()` 的 iOS 实现遵守 UIKit 的 MainActor 隔离。只读取机型时，下面的同步接口不访问 UIKit：

```swift
let identifier = AppleDevice.modelIdentifier
let model = AppleDevice.modelName(for: identifier) ?? identifier
```

已有平台适配器如果自行读取系统名称，也可将值交给纯数据接口，保留统一的字段和回退规则：

```swift
let snapshot = AppleDevice.snapshot(systemDeviceName: systemName)
```

该接口不会替调用方切换线程；调用方应在 UIKit 的正确 actor 上取得 `systemName`。不要在同步 Go / 原生回调中用 `DispatchQueue.main.sync` 等待主线程。

### iOS 用户设定名称的授权

iOS 15 及以前，`UIDevice.current.name` 可返回用户设定名称。iOS 16 起默认返回通用名称，例如 `iPhone`；此时 `userAssignedName` 为 `nil`，原始结果保留在 `deviceName`。

只有 Apple 已批准 `com.apple.developer.device-information.user-assigned-device-name`，且应用实际签名 / provisioning 已包含该权限时，才使用：

```swift
let info = AppleDevice.current(nameAccess: .grantedByApple)
```

`.grantedByApple` 是调用方对有效权限的明确声明，不会请求、自动检测或授予权限。包不会比较名称字符串猜测授权，也不会调用私有 API。模拟器始终不声称取得用户设定名称。未授权时可以使用 `displayName` 展示回退名称。

[Apple 的名称权限说明](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.device-information.user-assigned-device-name)

## macOS：构建与 JSON

```sh
./scripts/build-macos.sh             # arm64 + x86_64 universal
./dist/universal/device-info         # 一行 JSON + 换行
./dist/universal/device-info --pretty
```

只构建特定架构时：`./scripts/build-macos.sh arm64` 或 `./scripts/build-macos.sh x86_64`。

```json
{
  "deviceName": "工作 Mac",
  "displayModel": "Mac999,1",
  "displayName": "工作 Mac",
  "isSimulator": false,
  "modelIdentifier": "Mac999,1",
  "modelName": null,
  "userAssignedName": "工作 Mac"
}
```

示例中的型号仅用于说明字段。Mac 的标识通过 `hw.model` 读取，电脑名称通过 `SCDynamicStoreCopyComputerName` 读取，名称每次重新查询。电脑名称和网络 hostname、登录用户名是不同的概念。

| 字段 | 含义 |
| --- | --- |
| `modelIdentifier` | 原始机型标识；读取失败时为 `unknown` |
| `modelName` | 映射表中的机型名称；未知机型为 `null` |
| `deviceName` | 系统名称原值；iOS 16+ 可能为通用名称；失败为 `null` |
| `userAssignedName` | 确认可取得的用户设定名称；不可获取为 `null` |
| `isSimulator` | 是否运行在 iOS 模拟器；通过编译目标判断 |
| `displayModel` | `modelName ?? modelIdentifier` |
| `displayName` | `userAssignedName ?? deviceName ?? displayModel` |

当前映射表继承原 iOS 客户端的 96 组 iPhone / iPad / iPod 型号。Mac 及其他未收录机型保留真实标识，`modelName` 为 `null`，不猜测营销名称。模拟器优先使用 `SIMULATOR_MODEL_IDENTIFIER`，兼容 Apple Silicon 模拟器。

无参数时 stdout 只输出 JSON；`--help` 显示帮助，`--pretty` 输出格式化 JSON。未知参数以 64 退出，写入失败以 1 退出，诊断写 stderr。字段读取失败以 `unknown` / `null` 表达，程序仍输出有效 JSON。

## Electron

仓库中的 `electron/` 是不依赖 Electron 版本的 CommonJS + TypeScript 声明适配器。可复制到工程或以本地 package 方式引入；未发布到 npm registry。

将预编译的 `device-info` 放在应用资源目录的 `device-info/device-info`，通过 app-owned 绝对路径调用：

```js
const { app, ipcMain } = require('electron')
const path = require('node:path')
const { getDeviceInfo } = require('./vendor/apple-device-info/index.cjs')

app.whenReady().then(() => {
  const helperPath = path.join(process.resourcesPath, 'device-info', 'device-info')
  ipcMain.handle('device-info:get', () => getDeviceInfo(helperPath))
})
```

preload：

```js
const { contextBridge, ipcRenderer } = require('electron')
contextBridge.exposeInMainWorld('deviceInfo', {
  get: () => ipcRenderer.invoke('device-info:get'),
})
// renderer: const info = await window.deviceInfo.get()
```

如果窗口加载远程或不受信任的内容，按应用既有策略校验 IPC 来源，再返回设备名称。不要向页面开放任意可执行路径或完整 IPC 对象。

electron-builder 配置示例：

```json
{
  "extraResources": [
    { "from": "vendor/AppleDeviceInfo/dist/universal/device-info", "to": "device-info/device-info" }
  ],
  "mac": { "binaries": ["Contents/Resources/device-info/device-info"] }
}
```

路径按工程调整。helper 应在 ASAR 外，发布前以应用的 Developer ID 签名，再完成整个应用的签名和公证；构建脚本的 ad-hoc 签名只用于本地验证。终端用户无需安装 Swift。Mac App Store / sandbox 分发需要在实际宿主中另外验收。

适配器使用 `execFile`，不启动 shell，设置 5 秒超时和 64 KiB 输出上限，并校验 JSON 字段。名称查询应在需要时调用，避免高频创建进程；机型可以由宿主缓存。

## 验证

```sh
swift test --jobs 4 -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
./scripts/build-macos.sh
node --test electron/test.cjs
```

测试覆盖已知 / 未知机型、iOS 15 / 16+ 名称权限、模拟器、空名称、Unicode、显式 JSON null，以及 Electron 到预编译 helper 的调用。iOS 真机上的权限结果取决于该应用实际获批和签名状态。
