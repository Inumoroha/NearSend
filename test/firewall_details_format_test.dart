import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearsend/main.dart';
import 'package:nearsend/services/windows_firewall_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const _userJson =
    '{"allProfiles":"\\n域配置文件 设置: \\n----------------------------------------------------------------------\\n状态                                  启用\\n...(此处省略大段 netsh 原始输出)...\\n确定。\\n","tcpRules":[],"udpRules":[],"programRules":[]}';

const _richJson =
    '{"allProfiles":"...big netsh dump...","tcpRules":[{"enabled":"True","direction":"Inbound","action":"Allow","protocol":"6","localPort":"53317-53322,54317-54322,55317-55322,57317-57322","profile":"Private"}],"udpRules":[{"enabled":"True","direction":"Inbound","action":"Allow","protocol":"17","localPort":"53317-53322","profile":"Private"}],"programRules":[{"enabled":"False","direction":"Inbound","action":"Allow","profile":"Any","program":"C:\\\\app\\\\nearsend.exe"}]}';

WindowsFirewallStatus _status(String details) => WindowsFirewallStatus(
      supported: true,
      firewallEnabled: true,
      tcpAllowed: false,
      udpAllowed: false,
      programAllowed: false,
      localRulesAllowed: false,
      details: details,
    );

Future<void> _pump(WidgetTester tester, String details) async {
  await tester.pumpWidget(
    ShadApp(
      home: Scaffold(
        body: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: FirewallRepairCard(
            status: _status(details),
            lastRepair: null,
            lastInboundRequest: null,
            localEndpoints: const [],
            localHttpStatus: null,
            checking: false,
            repairing: false,
            onRefresh: () {},
            onRepair: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

String _diagnostic(WidgetTester tester) {
  final texts = tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((w) => w.data ?? '')
      .where((s) => s.contains('检测详情'))
      .toList();
  return texts.isEmpty ? '' : texts.first;
}

void main() {
  testWidgets('empty rules -> clean summary, no raw JSON', (tester) async {
    await _pump(tester, _userJson);
    final out = _diagnostic(tester);
    debugPrint('--- 用户实际数据渲染结果 ---\n$out\n--------------------------');
    expect(out, contains('检测详情'));
    expect(out, contains('TCP 规则：未找到'));
    expect(out, contains('UDP 规则：未找到'));
    expect(out, contains('程序规则：未找到'));
    // 不应再出现原始 JSON / netsh 噪音
    expect(out, isNot(contains('allProfiles')));
    expect(out, isNot(contains('netsh')));
    expect(out, isNot(contains('{')));
  });

  testWidgets('rules present -> readable per-rule summary', (tester) async {
    await _pump(tester, _richJson);
    final out = _diagnostic(tester);
    debugPrint('--- 含规则数据渲染结果 ---\n$out\n--------------------------');
    expect(out, contains('TCP 规则：1 条'));
    expect(out, contains('TCP')); // protocol 6 -> TCP
    expect(out, contains('UDP')); // protocol 17 -> UDP
    expect(out, contains('已启用'));
    expect(out, contains('已禁用'));
    expect(out, contains('允许'));
    expect(out, contains('nearsend.exe'));
    expect(out, isNot(contains('allProfiles')));
  });
}
