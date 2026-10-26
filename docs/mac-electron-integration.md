# Mac / Electron 设备信息接入

适用版本：**AppleDeviceInfo 0.1.1**。提供 Mac 机型标识和用户设定的电脑名称，Electron 通过随应用打包的命令行程序读取 JSON。

程序包含 arm64 / x86_64，终端用户无需安装 Swift。Apple Silicon 已运行验证，Intel 已交叉编译，待客户端实机验收。最低系统版本还需满足所用 Electron 的要求。

## 1. 准备文件

- 从 [0.1.1 Release](https://github.com/fanjiashu/AppleDeviceInfo/releases/tag/0.1.1) 下载 Mac universal 压缩包，将其中的 `device-info` 放到 `vendor/device-info`。
- 将 [electron 适配器](https://github.com/fanjiashu/AppleDeviceInfo/tree/0.1.1/electron) 中的 `index.cjs`、`index.d.ts` 复制到 `vendor/apple-device-info/`。适配器要求 Node.js 18+，以 Electron 内置的 Node.js 为准。
- 仓库为私有，需要有访问权限的 GitHub 账号。

以下示例假设主进程入口位于项目根目录：

```text
project/
├── main.cjs
├── preload.cjs
└── vendor/
    ├── device-info
    └── apple-device-info/
        ├── index.cjs
        └── index.d.ts
```

```sh
chmod +x vendor/device-info
./vendor/device-info --pretty
```

第二条命令应输出当前 Mac 的设备信息 JSON。

## 2. 主进程与页面调用

主进程 `main.cjs`，将注册函数合并到现有主窗口初始化流程：

```js
const { app, ipcMain } = require('electron')
const path = require('node:path')
const { getDeviceInfo } = require('./vendor/apple-device-info/index.cjs')

function registerDeviceInfoIPC(mainWindow) {
  ipcMain.removeHandler('device-info:get')
  ipcMain.handle('device-info:get', (event) => {
    if (event.sender !== mainWindow.webContents ||
        event.senderFrame !== mainWindow.webContents.mainFrame) {
      throw new Error('不允许的设备信息请求来源')
    }
    const helperPath = app.isPackaged
      ? path.join(process.resourcesPath, 'device-info')
      : path.join(app.getAppPath(), 'vendor', 'device-info')
    return getDeviceInfo(helperPath)
  })
}

// 在现有可信主窗口创建后调用；重建窗口时重新注册：
// registerDeviceInfoIPC(mainWindow)
```

此接口只提供给可信客户端页面。若主窗口允许导航到远程网页，还应接入项目已有的 URL 白名单校验；不要向轻应用开放设备名称或任意可执行路径。

preload `preload.cjs`：

```js
const { contextBridge, ipcRenderer } = require('electron')
contextBridge.exposeInMainWorld('deviceInfo', {
  get: () => ipcRenderer.invoke('device-info:get'),
})
```

页面在异步函数中调用 `await window.deviceInfo.get()`；调用失败时按现有错误处理流程捕获异常。窗口需加载上述 preload，并启用 `contextIsolation`。

## 3. 打包与签名

将以下配置合并到 `package.json` 的 `build` 字段。示例适用于 **electron-builder v27**：

```json
{
  "extraResources": [
    { "from": "vendor/device-info", "to": "device-info" }
  ],
  "mac": {
    "sign": {
      "binaries": ["Contents/Resources/device-info"]
    }
  }
}
```

electron-builder **v26** 将签名配置写为 `mac.binaries`，其余路径相同，参见 [v26 文档](https://www.electron.build/v26/docs/mac/) 与 [v27 文档](https://www.electron.build/mac/)。

`device-info` 必须在 ASAR 外；适配器 JS 则随应用代码打包。项目若已有 `files` 白名单，需要包含 `vendor/apple-device-info/**`。Release 附件使用 ad-hoc 签名，正式分发时应以应用的 Developer ID 重新签名，并随整个应用完成公证。

## 4. 返回数据与异常

示例数据仅用于说明字段：

```json
{
  "modelIdentifier": "Mac14,2",
  "modelName": null,
  "deviceName": "工作 Mac",
  "userAssignedName": "工作 Mac",
  "isSimulator": false,
  "displayModel": "Mac14,2",
  "displayName": "工作 Mac"
}
```

| 字段 | 含义 |
| --- | --- |
| `modelIdentifier` | 原始机型标识，读取失败为 `unknown` |
| `modelName` | 友好机型名称；当前未收录 Mac 映射，为 `null` |
| `deviceName` / `userAssignedName` | 系统设置中的电脑名称，读取失败为 `null` |
| `displayModel` | 展示机型：`modelName ?? modelIdentifier` |
| `displayName` | 展示名称：`userAssignedName ?? deviceName ?? displayModel` |
| `isSimulator` | Mac 命令行固定为 `false` |

机型通过 `hw.model` 获取，名称通过 `SCDynamicStoreCopyComputerName` 获取。电脑名称与网络 hostname、登录用户名不同，每次调用都会重新读取。

适配器使用 `execFile`，不启动 shell，设置 5 秒超时、64 KiB 输出上限，并校验 JSON。进程启动失败、超时或 JSON 无效会使 Promise reject；单个系统字段读取失败仍返回带 `null` / `unknown` 的有效对象。名称按需读取，避免高频启动进程。

## 5. 客户端验收

- 开发环境和打包后的 `.app` 均能调用，机型、电脑名称与本机系统一致。
- 修改系统电脑名称后，再次调用返回新名称。
- 在 Apple Silicon、Intel 上分别运行，并完成签名、公证后的启动验收；Mac App Store / sandbox 分发需在实际宿主内另行验证。
