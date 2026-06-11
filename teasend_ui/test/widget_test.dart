// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nearsend/main.dart';
import 'package:nearsend/models/discovered_device.dart';

void main() {
  setUp(() {
    // Seed a persisted conversation so the NearSendApp smoke tests have a
    // conversation to operate on (the app no longer ships a placeholder one).
    // This also exercises the Conversation JSON round-trip on load.
    final helper = Conversation(
      title: '文件传输助手',
      subtitle: '已保存 3 个文件到本地',
      status: '常用工具',
      time: '周五',
      initials: '文',
      messages: [
        ChatMessage('周五 14:22', system: true),
        ChatMessage('文件会暂时保留在本地下载目录', sender: '文'),
      ],
      files: [
        TransferFile('invoice.pdf', '680 KB', 100, FileKind.pdf),
        TransferFile('photo-set.zip', '42.6 MB', 100, FileKind.archive),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'device_conversations': jsonEncode({'helper': helper.toJson()}),
    });
  });

  testWidgets('chat prototype smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    expect(find.text('文件传输助手'), findsWidgets);
    expect(find.text('输入消息...'), findsOneWidget);
    expect(find.text('发送'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '你好，NearSend');
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();

    expect(find.text('你好，NearSend'), findsWidgets);
    expect(find.byIcon(Icons.done_all_rounded), findsWidgets);
  });

  testWidgets('can delete selected chat messages', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('文件会暂时保留在本地下载目录'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 条'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('文件会暂时保留在本地下载目录'), findsNothing);
    expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);
  });

  testWidgets('can select all chat messages', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pumpAndSettle();

    tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.select_all_rounded),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('已选择 2 条'), findsOneWidget);
    expect(find.byIcon(Icons.deselect_rounded), findsOneWidget);

    tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.deselect_rounded),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('已选择 0 条'), findsOneWidget);
  });

  testWidgets('conversation context menu can clear a conversation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('文件传输助手').first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('清空会话'), findsOneWidget);
    expect(find.text('删除会话'), findsOneWidget);

    await tester.tap(find.text('清空会话'));
    await tester.pumpAndSettle();

    expect(find.text('文件会暂时保留在本地下载目录'), findsNothing);
    expect(find.text('暂无聊天记录'), findsOneWidget);
  });

  testWidgets('can delete the only conversation without crashing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('文件传输助手').first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('删除会话'));
    await tester.pumpAndSettle();

    // Removing the last conversation must empty the list and show the empty
    // state rather than throwing on the index clamp.
    expect(tester.takeException(), isNull);
    expect(find.text('文件传输助手'), findsNothing);
    expect(find.text('暂无会话，等待局域网设备…'), findsOneWidget);
  });

  testWidgets('shows conversation detail page in chat area', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('详细信息'), findsOneWidget);
    expect(find.text('当前会话没有设备信息'), findsOneWidget);
    expect(find.text('输入消息...'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('输入消息...'), findsOneWidget);
  });

  testWidgets('shows connection qr dialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.qr_code_rounded));
    await tester.pumpAndSettle();

    expect(find.text('连接二维码'), findsOneWidget);
    expect(find.text('127.0.0.1:53317'), findsOneWidget);
  });

  testWidgets('shows manual connect dialog with editable fields', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_link_rounded));
    await tester.pumpAndSettle();

    expect(find.text('手动连接'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('127.0.0.1'), findsNothing);
  });

  testWidgets('cancelling manual connect dialog does not throw', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_link_rounded));
    await tester.pumpAndSettle();
    expect(find.text('手动连接'), findsOneWidget);

    await tester.tap(find.text('取消'));
    // Pump through the dialog's exit animation: a controller disposed too early
    // would surface "used after being disposed" while the fields fade out.
    await tester.pumpAndSettle();

    expect(find.text('手动连接'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows local device info dialog with editable alias', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('本设备信息'));
    await tester.pumpAndSettle();

    expect(find.text('本设备信息'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('设备指纹'), findsOneWidget);
  });

  testWidgets('cancelling device info dialog does not throw', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('本设备信息'));
    await tester.pumpAndSettle();
    expect(find.text('本设备信息'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('本设备信息'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling conversation rename dialog does not throw', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    // Open the conversation context menu and pick rename ("重命名").
    await tester.tap(find.text('文件传输助手').first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('uses device icons for discovered conversations', (
    WidgetTester tester,
  ) async {
    final mobileConversation = Conversation(
      title: 'Android Phone',
      subtitle: 'Online',
      status: 'Android 在线',
      time: '在线',
      initials: 'A',
      messages: [],
      files: [],
      device: DiscoveredDevice(
        alias: 'Android Phone',
        ip: '192.168.1.10',
        version: '2.1',
        port: 53317,
        https: false,
        fingerprint: 'mobile-id',
        deviceType: DiscoveredDeviceType.mobile,
        download: false,
        lastSeen: DateTime(2026, 6, 9),
        deviceModel: 'Android',
      ),
    );
    final desktopConversation = Conversation(
      title: 'Windows PC',
      subtitle: 'Online',
      status: 'Windows 在线',
      time: '在线',
      initials: 'W',
      messages: [],
      files: [],
      device: DiscoveredDevice(
        alias: 'Windows PC',
        ip: '192.168.1.11',
        version: '2.1',
        port: 53317,
        https: false,
        fingerprint: 'desktop-id',
        deviceType: DiscoveredDeviceType.desktop,
        download: false,
        lastSeen: DateTime(2026, 6, 9),
        deviceModel: 'Windows',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Column(
            children: [
              ConversationAvatar(conversation: mobileConversation, size: 44),
              ConversationAvatar(conversation: desktopConversation, size: 44),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.android_rounded), findsOneWidget);
    expect(find.byIcon(Icons.desktop_windows_rounded), findsOneWidget);
  });

  testWidgets('device conversation shows green wifi status icon', (
    WidgetTester tester,
  ) async {
    final conversation = Conversation(
      title: 'Windows PC',
      subtitle: 'Online',
      status: 'Windows 在线',
      time: '在线',
      initials: 'W',
      messages: [],
      files: [],
      device: DiscoveredDevice(
        alias: 'Windows PC',
        ip: '192.168.1.11',
        version: '2.1',
        port: 53317,
        https: false,
        fingerprint: 'desktop-id',
        deviceType: DiscoveredDeviceType.desktop,
        download: false,
        lastSeen: DateTime(2026, 6, 9),
        deviceModel: 'Windows',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ConversationTile(
            conversation: conversation,
            selected: false,
            onTap: () {},
            onContextMenu: (_) {},
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_rounded));
    expect(icon.color, const Color(0xFF27A95D));
    expect(find.text('在线'), findsNothing);
  });

  testWidgets('settings page toggles auto save', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('自动保存'), findsOneWidget);
    expect(find.text('覆盖同名文件'), findsOneWidget);
    expect(find.text('最小化到托盘'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
    expect(find.text('产品设计'), findsNothing);

    final switches = find.byType(ShadSwitch);
    expect(switches, findsNWidgets(3));

    var autoSaveSwitch = tester.widget<ShadSwitch>(switches.first);
    expect(autoSaveSwitch.value, isFalse);

    await tester.tap(switches.first);
    await tester.pumpAndSettle();

    autoSaveSwitch = tester.widget<ShadSwitch>(switches.first);
    expect(autoSaveSwitch.value, isTrue);
  });

  testWidgets('theme page switches mode and accent color', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NearSendApp(enableDiscovery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('主题'));
    await tester.pumpAndSettle();

    expect(find.text('显示模式'), findsOneWidget);
    expect(find.text('主题色'), findsOneWidget);
    expect(find.text('日间'), findsOneWidget);
    expect(find.text('夜间'), findsOneWidget);

    await tester.tap(find.text('夜间'));
    await tester.pumpAndSettle();

    final nightButton = tester.widget<ShadButton>(
      find.ancestor(of: find.text('夜间'), matching: find.byType(ShadButton)),
    );
    expect(nightButton.backgroundColor, const Color(0xFF2563EB));

    expect(find.byTooltip('切换主题色'), findsWidgets);
  });

  testWidgets('failed outgoing file message shows retry button', (
    WidgetTester tester,
  ) async {
    final attachment = MessageAttachment(
      path: 'C:\\tmp\\photo.png',
      name: 'photo.png',
      size: 128,
      kind: FileKind.image,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Column(
            children: [
              MessageBubble(
                message: ChatMessage(
                  '',
                  isMe: true,
                  attachment: attachment,
                  status: MessageSendStatus.failed,
                ),
                selectionMode: false,
                selected: false,
                onToggleSelected: () {},
                onRetrySend: () {},
                onCancelTransfer: () {},
                onCopyAttachment: (_) {},
                onPreviewImage: (_) {},
              ),
              MessageBubble(
                message: ChatMessage(
                  '文字失败',
                  isMe: true,
                  status: MessageSendStatus.failed,
                ),
                selectionMode: false,
                selected: false,
                onToggleSelected: () {},
                onRetrySend: () {},
                onCancelTransfer: () {},
                onCopyAttachment: (_) {},
                onPreviewImage: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byTooltip('重试发送'), findsOneWidget);
  });

  testWidgets('attachment messages are not wrapped by bubble border', (
    WidgetTester tester,
  ) async {
    final attachment = MessageAttachment(
      path: 'C:\\tmp\\archive.zip',
      name: 'archive.zip',
      size: 128,
      kind: FileKind.archive,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: MessageBubble(
            message: ChatMessage('', isMe: true, attachment: attachment),
            selectionMode: false,
            selected: false,
            onToggleSelected: () {},
            onRetrySend: () {},
            onCancelTransfer: () {},
            onCopyAttachment: (_) {},
            onPreviewImage: (_) {},
          ),
        ),
      ),
    );

    final wrapper = tester.widget<Padding>(
      find.ancestor(
        of: find.byType(AttachmentTile),
        matching: find.byWidgetPredicate(
          (widget) => widget is Padding && widget.padding == EdgeInsets.zero,
        ),
      ),
    );

    expect(wrapper.padding, EdgeInsets.zero);
  });

  testWidgets('attachment messages show copy button', (
    WidgetTester tester,
  ) async {
    final attachment = MessageAttachment(
      path: 'C:\\tmp\\archive.zip',
      name: 'archive.zip',
      size: 128,
      kind: FileKind.archive,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Column(
            children: [
              MessageBubble(
                message: ChatMessage('', isMe: true, attachment: attachment),
                selectionMode: false,
                selected: false,
                onToggleSelected: () {},
                onRetrySend: () {},
                onCancelTransfer: () {},
                onCopyAttachment: (_) {},
                onPreviewImage: (_) {},
              ),
              MessageBubble(
                message: ChatMessage('文字消息', isMe: true),
                selectionMode: false,
                selected: false,
                onToggleSelected: () {},
                onRetrySend: () {},
                onCancelTransfer: () {},
                onCopyAttachment: (_) {},
                onPreviewImage: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CopyAttachmentButton), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });

  testWidgets('image message can open and close preview overlay', (
    WidgetTester tester,
  ) async {
    final attachment = MessageAttachment(
      path: 'C:\\tmp\\photo.png',
      name: 'photo.png',
      size: 128,
      kind: FileKind.image,
    );
    MessageAttachment? previewImage;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Material(
              child: Stack(
                children: [
                  MessageBubble(
                    message: ChatMessage(
                      '',
                      isMe: true,
                      attachment: attachment,
                    ),
                    selectionMode: false,
                    selected: false,
                    onToggleSelected: () {},
                    onRetrySend: () {},
                    onCancelTransfer: () {},
                    onCopyAttachment: (_) {},
                    onPreviewImage: (value) {
                      setState(() {
                        previewImage = value;
                      });
                    },
                  ),
                  if (previewImage != null)
                    ImagePreviewOverlay(
                      attachment: previewImage!,
                      onClose: () {
                        setState(() {
                          previewImage = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );

    tester
        .widget<InkWell>(find.byKey(const ValueKey('image-preview-button')))
        .onTap!();
    await tester.pumpAndSettle();

    expect(find.byType(ImagePreviewOverlay), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    expect(find.byType(ImagePreviewOverlay), findsNothing);
  });
}
