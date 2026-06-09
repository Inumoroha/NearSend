# LocalSend 原版功能差距记录

当前 NearSend 已经实现了：

- Windows 桌面 UI
- 局域网发现
- 手动连接
- 二维码连接
- LocalSend 兼容的基础发文件/收文件
- 多文件选择和缩略图预览
- 截图/图片粘贴
- 图片放大预览
- 自动保存
- 覆盖同名文件
- 最小化到托盘
- 主题模式和主题色

但原版 LocalSend 仍然完整很多，主要还有以下功能当前没有实现或只实现了一部分。

## 协议和安全

- HTTPS/TLS 加密传输，运行时证书生成。
- 接收 PIN 校验。
- 更完整的 LocalSend v1/v2 协议状态处理。
- 收文件前的确认/拒绝流程，而不是直接接收或自动保存。
- 忙碌、取消、失败、重试、超时等协议级状态。

## 传输流程

- 独立的传输进度页：速度、剩余时间、单文件/总进度、取消传输。
- 发送模式：单设备发送、多设备发送、通过链接分享。
- Web Share：浏览器打开链接上传/下载文件。
- 接收选项页：接收时临时选择保存位置、文件处理方式。
- 更完整的传输队列和会话管理。

## 设备和网络

- 收藏设备。
- 收藏设备自动扫描。
- 网络接口白名单/黑名单。
- 自定义端口、HTTPS 开关、Multicast 设置、超时时间等高级网络配置。
- 故障排查页面，比如防火墙、发现不到设备、连接失败提示。

## 历史和文件管理

- 接收历史页。
- 历史记录清空、删除单条、打开所在文件夹。
- 快速保存和仅收藏设备快速保存。
- 更完整的文件选择页、已选文件编辑页。

## 系统集成

- 开机自启。
- 启动后最小化。
- 记住窗口位置和大小。
- Windows 右键菜单“用 LocalSend 发送”。
- Portable 模式，也就是 exe 旁边放 `settings.json`。
- 命令行 `--hidden` 隐藏启动。

## 跨平台能力

- Android/iOS/macOS/Linux 支持。
- Android APK 选择器。
- 移动端保存到相册。
- 系统分享入口，比如手机从相册/文件管理器直接分享到 LocalSend。

## 产品级页面

- 多语言切换。
- 关于页、更新日志、捐赠页、贡献者页。
- Debug 页面、HTTP 日志、Discovery 调试、安全调试。

## 原项目参考文件

- `localsend/app/lib/pages/tabs/settings_tab.dart`
- `localsend/app/lib/pages/tabs/send_tab.dart`
- `localsend/app/lib/pages/receive_page.dart`
- `localsend/app/lib/pages/progress_page.dart`
- `localsend/app/lib/pages/web_send_page.dart`
- `localsend/app/lib/pages/receive_history_page.dart`
- `localsend/app/lib/pages/settings/network_interfaces_page.dart`

## 建议下一步优先级

建议下一步先补这三件：

1. 传输进度和取消。
2. 接收前确认/拒绝。
3. 接收历史。

这三项最能把当前应用从“聊天式文件传输原型”推进到“真正可用的文件传输工具”。
