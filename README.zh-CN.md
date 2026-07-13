# NearSend

[English documentation](README.md)

NearSend 是一个受 LocalSend 启发的 Flutter 应用。目前主要面向 Windows，
同时提供初步的 Android 支持，用于局域网设备发现、聊天消息和兼容
LocalSend 的文件传输。

## 功能

- 局域网设备发现、IP 手动连接和二维码连接信息。
- 基础 LocalSend v1/v2 文件传输，支持 HTTPS 和证书指纹校验。
- 多文件选择、缩略图、图片预览、剪贴板图片和截图发送。
- 传输任务进度、速度、剩余时间、取消、重试和接收确认。
- 自动保存、自定义保存目录和同名文件处理。
- 接收历史搜索、打开文件/文件夹、删除、清空和失效记录清理。
- 收藏设备、收藏设备自动接收和可选的剪贴板自动发送。
- Windows 系统托盘以及防火墙/网络诊断。
- 明暗主题和主题色切换。

仍待补齐的 LocalSend 功能记录在
[`localsend_feature_gap.md`](localsend_feature_gap.md) 中。

## 项目结构

```text
.
├── .github/workflows/       发布工作流
├── android/                 Android 平台代码
├── docs/                    开发和故障排查文档
├── lib/                     Dart 应用代码
├── test/                    测试
├── windows/                 Windows 平台代码
├── fonts/                   应用字体
├── pubspec.yaml             Flutter 依赖和项目元数据
├── README.md                英文文档
├── README.zh-CN.md          中文文档
└── localsend_feature_gap.md
```

## 开发

```powershell
flutter pub get
flutter run -d windows
```

运行检查：

```powershell
flutter analyze
flutter test
flutter build windows --debug
```

Debug 可执行文件生成在：

```text
build/windows/x64/runner/Debug/nearsend.exe
```

`localsend/` 目录可以在本地作为只读参考项目保留，并且已被 Git 忽略。
