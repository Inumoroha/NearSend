# 如果要手敲 NearSend，需要学什么

NearSend 不是一个初学者练手 demo。它横跨 UI、状态管理、局域网网络、HTTP 服务、文件传输、Windows 防火墙、Android 权限和打包发布。

不需要一次学完，建议按下面顺序补。

## 1. Dart 和 Flutter 基础

先能独立写 UI、页面状态、按钮交互、列表、弹窗、文件选择和响应式布局。

重点：

- `StatelessWidget`
- `StatefulWidget`
- `setState`
- `Future`
- `async` / `await`
- `Stream`
- `StreamController`
- `ListView`
- `TextField`
- `SelectableText`
- Android 和 Windows 构建

## 2. Flutter 状态管理和架构

NearSend 里有消息、设备、传输任务、防火墙状态、设置状态。它不是只有一个按钮的应用。

重点：

- 状态如何拆分。
- 页面组件如何传 callback。
- 数据模型 class 怎么设计。
- UI 和网络逻辑如何分层。
- 后续可以学习 Riverpod 或 Bloc。

## 3. 局域网网络编程

这是 NearSend 的核心。

重点：

- IP、端口、TCP、UDP。
- HTTP server 和 HTTP client。
- JSON 协议。
- 局域网设备发现。
- UDP multicast / broadcast。
- 超时、重试、fallback 端口。
- 为什么 `127.0.0.1` 只能本机访问。
- 为什么平板要访问电脑的局域网 IP。

## 4. 文件传输

文字消息相对简单，文件和图片才是真正复杂的部分。

重点：

- multipart upload。
- 文件流读取。
- 大文件分块。
- 传输进度。
- 取消传输。
- 接收确认。
- 临时文件和保存目录。
- MIME type。

## 5. 平台能力

跨平台应用最大的坑通常不是业务代码，而是系统行为。

Windows 重点：

- 防火墙规则。
- 程序路径放行。
- 管理员权限和 UAC。
- PowerShell / netsh。
- Debug 和 Release 路径区别。
- 端口占用和端口保留。

Android 重点：

- 局域网权限。
- 存储和文件选择。
- 后台限制。
- 热点网络下的 IP 行为。
- 长按选择和触控交互。

## 6. 协议设计

两台设备之间必须有一套稳定的说话方式。

重点：

- 设备身份。
- 注册接口。
- 发送文本接口。
- 文件传输准备接口。
- 文件上传接口。
- 取消接口。
- 错误码。
- LocalSend 协议兼容。

## 7. 调试能力

这次很多问题不是一眼看代码能看出来的，而是靠诊断缩小范围。

重点：

- 打日志。
- 显示本机 endpoint。
- 本地 HTTP 自检。
- 浏览器访问测试。
- `curl`。
- `netstat`。
- 防火墙规则检查。
- 区分服务没启动、端口不通、协议失败、UI 误报。

## 推荐路线

1. 用 Flutter 写一个单机聊天界面。
2. 写一个本机 HTTP server，让浏览器能打开。
3. 让另一台设备访问电脑 HTTP server。
4. 加发送文字。
5. 加 UDP 发现设备。
6. 加文件上传。
7. 加传输进度和取消。
8. 加历史记录、设备列表、收藏设备。
9. 最后处理 Windows 防火墙、Android 权限、Release 打包。

最该优先补的四块：

```text
Dart/Flutter 异步编程
HTTP + TCP/UDP 网络基础
文件流和上传下载
Windows/Android 平台权限与调试
```

Rust 不是关键。Rust 可以让底层网络或文件处理更强，但这个应用的主要门槛是跨平台 Flutter、局域网协议、系统权限和调试能力。
