import 'dart:convert';
import 'dart:io';

class WindowsFirewallStatus {
  const WindowsFirewallStatus({
    required this.supported,
    required this.firewallEnabled,
    required this.tcpAllowed,
    required this.udpAllowed,
    required this.programAllowed,
    required this.localRulesAllowed,
    this.error,
    this.details,
  });

  final bool supported;
  final bool firewallEnabled;
  final bool tcpAllowed;
  final bool udpAllowed;
  final bool programAllowed;
  final bool localRulesAllowed;
  final String? error;
  final String? details;

  bool get needsRepair =>
      supported && (!tcpAllowed || !udpAllowed || !localRulesAllowed);
}

class WindowsFirewallService {
  const WindowsFirewallService();

  static const tcpRuleName = 'NearSend Inbound TCP 53317-57322';
  static const udpRuleName = 'NearSend Discovery UDP 53317-53322';
  static const programRuleName = 'NearSend App Inbound';
  static const debugProgramRuleName = 'NearSend App Inbound Debug';
  static const releaseProgramRuleName = 'NearSend App Inbound Release';
  static const oldTcpRuleName = 'NearSend Inbound TCP 53317-53322';
  static const ports = '53317-53322,54317-54322,55317-55322,57317-57322';
  static const _powerShellTcpPorts =
      "'53317-53322','54317-54322','55317-55322','57317-57322'";
  static const _powerShellUdpPorts = "'53317-53322'";
  static const discoveryPorts = '53317-53322';

  Future<WindowsFirewallStatus> checkStatus() async {
    if (!Platform.isWindows) {
      return const WindowsFirewallStatus(
        supported: false,
        firewallEnabled: false,
        tcpAllowed: false,
        udpAllowed: false,
        programAllowed: true,
        localRulesAllowed: true,
      );
    }

    final script =
        r'''
$ErrorActionPreference = 'Continue'
function Test-LocalRulesAllowed() {
  $profiles = netsh advfirewall show allprofiles
  $text = [string]::Join("`n", $profiles)
  if ($text -match 'LocalFirewallRules\s+Disable') {
    return $false
  }
  return $true
}
function Test-FirewallEnabled() {
  try {
    return [bool](Get-NetFirewallProfile | Where-Object { $_.Enabled -eq 'True' })
  } catch {
    $profiles = netsh advfirewall show allprofiles
    $text = [string]::Join("`n", $profiles)
    return ($text -match 'State\s+ON')
  }
}
function Test-NearSendRule($name, $protocol) {
  $expectedPorts = if ($protocol -eq 'TCP') { '__TCP_PORTS__' } else { '__UDP_PORTS__' }
  $expectedPortItems = $expectedPorts.Split(',')
  try {
    $rules = Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue
    foreach ($rule in $rules) {
      $portFilter = $rule | Get-NetFirewallPortFilter
      $localPort = [string]$portFilter.LocalPort
      $protocolText = $portFilter.Protocol.ToString()
      $protocolMatches = $protocolText -eq $protocol -or
        ($protocol -eq 'TCP' -and $protocolText -eq '6') -or
        ($protocol -eq 'UDP' -and $protocolText -eq '17')
      if ($protocolMatches -and ($localPort -eq 'Any' -or $localPort -eq $expectedPorts)) {
        return ($rule.Enabled.ToString() -eq 'True' -and
          $rule.Direction.ToString() -eq 'Inbound' -and
          $rule.Action.ToString() -eq 'Allow')
      }
    }
  } catch {
    # Fall back to netsh below.
  }
  $netsh = netsh advfirewall firewall show rule name="$name" verbose
  $text = [string]::Join("`n", $netsh)
  if ($text -notmatch [regex]::Escape($name)) { return $false }
  if ($text -notmatch $protocol) { return $false }
  foreach ($port in $expectedPortItems) {
    if ($text -notmatch [regex]::Escape($port)) { return $false }
  }
  return $true
}
function Normalize-ProgramPath($path) {
  if ([string]::IsNullOrWhiteSpace($path) -or $path -eq 'Any') {
    return $path
  }
  try {
    return [System.IO.Path]::GetFullPath($path).TrimEnd('\').ToLowerInvariant()
  } catch {
    return ([string]$path).TrimEnd('\').ToLowerInvariant()
  }
}
function Test-NearSendProgramRule($names, $expectedProgram) {
  $expectedProgramPath = Normalize-ProgramPath $expectedProgram
  try {
    $rules = Get-NetFirewallRule -DisplayName $names -ErrorAction SilentlyContinue |
      Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' }
    foreach ($rule in $rules) {
      $appFilter = $rule | Get-NetFirewallApplicationFilter
      $ruleProgram = [string]$appFilter.Program
      if ($ruleProgram -eq 'Any' -or (Normalize-ProgramPath $ruleProgram) -eq $expectedProgramPath) {
        return $true
      }
    }
  } catch {
  }
  foreach ($name in $names) {
    $netsh = netsh advfirewall firewall show rule name="$name" verbose
    $text = [string]::Join("`n", $netsh)
    if (($text -match [regex]::Escape($name)) -and
        ($text -match 'Enabled:\s+Yes') -and
        ($text -match 'Direction:\s+In') -and
        ($text -match 'Action:\s+Allow') -and
        ($text -match [regex]::Escape($expectedProgram))) {
      return $true
    }
  }
  return $false
}
$program = '__PROGRAM__'
$programRuleNames = @('__PROGRAM_RULE__','__DEBUG_PROGRAM_RULE__','__RELEASE_PROGRAM_RULE__')
$details = [pscustomobject]@{
  allProfiles = [string]::Join("`n", (netsh advfirewall show allprofiles))
  tcpRules = @(Get-NetFirewallRule -DisplayName @('__TCP_RULE__','__OLD_TCP_RULE__') -ErrorAction SilentlyContinue | ForEach-Object {
    $portFilter = $_ | Get-NetFirewallPortFilter
    [pscustomobject]@{
      enabled = $_.Enabled.ToString()
      direction = $_.Direction.ToString()
      action = $_.Action.ToString()
      protocol = $portFilter.Protocol.ToString()
      localPort = [string]$portFilter.LocalPort
      profile = $_.Profile.ToString()
    }
  })
  udpRules = @(Get-NetFirewallRule -DisplayName '__UDP_RULE__' -ErrorAction SilentlyContinue | ForEach-Object {
    $portFilter = $_ | Get-NetFirewallPortFilter
    [pscustomobject]@{
      enabled = $_.Enabled.ToString()
      direction = $_.Direction.ToString()
      action = $_.Action.ToString()
      protocol = $portFilter.Protocol.ToString()
      localPort = [string]$portFilter.LocalPort
      profile = $_.Profile.ToString()
    }
  })
  programRules = @(Get-NetFirewallRule -DisplayName $programRuleNames -ErrorAction SilentlyContinue | ForEach-Object {
    $appFilter = $_ | Get-NetFirewallApplicationFilter
    [pscustomobject]@{
      enabled = $_.Enabled.ToString()
      direction = $_.Direction.ToString()
      action = $_.Action.ToString()
      profile = $_.Profile.ToString()
      program = [string]$appFilter.Program
    }
  })
}
[pscustomobject]@{
  firewallEnabled = Test-FirewallEnabled
  localRulesAllowed = Test-LocalRulesAllowed
  tcpAllowed = Test-NearSendRule '__TCP_RULE__' 'TCP'
  udpAllowed = Test-NearSendRule '__UDP_RULE__' 'UDP'
  programAllowed = Test-NearSendProgramRule $programRuleNames $program
  details = ($details | ConvertTo-Json -Compress -Depth 5)
} | ConvertTo-Json -Compress'''
            .replaceAll('__TCP_PORTS__', ports)
            .replaceAll('__UDP_PORTS__', discoveryPorts)
            .replaceAll('__TCP_RULE__', tcpRuleName)
            .replaceAll('__OLD_TCP_RULE__', oldTcpRuleName)
            .replaceAll('__UDP_RULE__', udpRuleName)
            .replaceAll('__PROGRAM_RULE__', programRuleName)
            .replaceAll('__DEBUG_PROGRAM_RULE__', debugProgramRuleName)
            .replaceAll('__RELEASE_PROGRAM_RULE__', releaseProgramRuleName)
            .replaceAll(
              '__PROGRAM__',
              _escapePowerShellPath(Platform.resolvedExecutable),
            );

    try {
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ]);
      if (result.exitCode != 0) {
        return WindowsFirewallStatus(
          supported: true,
          firewallEnabled: false,
          tcpAllowed: false,
          udpAllowed: false,
          programAllowed: false,
          localRulesAllowed: false,
          error: result.stderr.toString().trim(),
          details: result.stdout.toString().trim(),
        );
      }

      final decoded = jsonDecode(result.stdout.toString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected firewall status output');
      }
      return WindowsFirewallStatus(
        supported: true,
        firewallEnabled: decoded['firewallEnabled'] == true,
        tcpAllowed: decoded['tcpAllowed'] == true,
        udpAllowed: decoded['udpAllowed'] == true,
        programAllowed: decoded['programAllowed'] == true,
        localRulesAllowed: decoded['localRulesAllowed'] != false,
        details: decoded['details']?.toString(),
      );
    } catch (error) {
      return WindowsFirewallStatus(
        supported: true,
        firewallEnabled: false,
        tcpAllowed: false,
        udpAllowed: false,
        programAllowed: false,
        localRulesAllowed: false,
        error: error.toString(),
      );
    }
  }

  Future<WindowsFirewallRepairResult> repair() async {
    if (!Platform.isWindows) {
      return const WindowsFirewallRepairResult(
        started: false,
        success: false,
        message: 'Only Windows is supported',
      );
    }

    final script =
        r'''
$ErrorActionPreference = 'Continue'
$tcpPorts = @(__TCP_PORTS__)
$udpPorts = @(__UDP_PORTS__)
$tcpPortsText = '__TCP_PORTS_TEXT__'
$udpPortsText = '__UDP_PORTS_TEXT__'
$tcpRule = '__TCP_RULE__'
$oldTcpRule = '__OLD_TCP_RULE__'
$udpRule = '__UDP_RULE__'
$programRule = '__PROGRAM_RULE__'
$debugProgramRule = '__DEBUG_PROGRAM_RULE__'
$releaseProgramRule = '__RELEASE_PROGRAM_RULE__'
$program = '__PROGRAM__'
$debugProgram = '__DEBUG_PROGRAM__'
$releaseProgram = '__RELEASE_PROGRAM__'
$log = Join-Path $env:TEMP 'nearsend_firewall_repair.log'
function Write-RepairLog($message) {
  Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format s), $message)
}
Remove-Item $log -ErrorAction SilentlyContinue
try {
  Write-RepairLog 'Starting firewall repair'
  Set-NetFirewallProfile -Profile Domain,Private,Public -AllowLocalFirewallRules True -AllowInboundRules True -ErrorAction Stop
  Write-RepairLog 'Enabled local firewall rules for all profiles'
  Get-NetFirewallRule -DisplayName $tcpRule -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
  Get-NetFirewallRule -DisplayName $oldTcpRule -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
  Get-NetFirewallRule -DisplayName $udpRule -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
  Get-NetFirewallRule -DisplayName $programRule -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
  Get-NetFirewallRule -DisplayName $debugProgramRule -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
  Get-NetFirewallRule -DisplayName $releaseProgramRule -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName $tcpRule -Direction Inbound -Action Allow -Protocol TCP -LocalPort $tcpPorts -Profile Any -Enabled True -ErrorAction Stop | Out-Null
  New-NetFirewallRule -DisplayName $udpRule -Direction Inbound -Action Allow -Protocol UDP -LocalPort $udpPorts -Profile Any -Enabled True -ErrorAction Stop | Out-Null
  New-NetFirewallRule -DisplayName $programRule -Direction Inbound -Action Allow -Program $program -Profile Any -Enabled True -ErrorAction Stop | Out-Null
  if (Test-Path $debugProgram) {
    New-NetFirewallRule -DisplayName $debugProgramRule -Direction Inbound -Action Allow -Program $debugProgram -Profile Any -Enabled True -ErrorAction Stop | Out-Null
  }
  if (Test-Path $releaseProgram) {
    New-NetFirewallRule -DisplayName $releaseProgramRule -Direction Inbound -Action Allow -Program $releaseProgram -Profile Any -Enabled True -ErrorAction Stop | Out-Null
  }
  Write-RepairLog 'New-NetFirewallRule succeeded'
  exit 0
} catch {
  Write-RepairLog ('New-NetFirewallRule failed: ' + $_.Exception.Message)
}
try {
  netsh advfirewall set allprofiles settings localfirewallrules enable | Out-Null
  netsh advfirewall firewall delete rule name="$tcpRule" | Out-Null
  netsh advfirewall firewall delete rule name="$oldTcpRule" | Out-Null
  netsh advfirewall firewall delete rule name="$udpRule" | Out-Null
  netsh advfirewall firewall delete rule name="$programRule" | Out-Null
  netsh advfirewall firewall delete rule name="$debugProgramRule" | Out-Null
  netsh advfirewall firewall delete rule name="$releaseProgramRule" | Out-Null
  netsh advfirewall firewall add rule name="$tcpRule" dir=in action=allow protocol=TCP localport=$tcpPortsText profile=any | Out-Null
  netsh advfirewall firewall add rule name="$udpRule" dir=in action=allow protocol=UDP localport=$udpPortsText profile=any | Out-Null
  netsh advfirewall firewall add rule name="$programRule" dir=in action=allow program="$program" profile=any | Out-Null
  if (Test-Path $debugProgram) {
    netsh advfirewall firewall add rule name="$debugProgramRule" dir=in action=allow program="$debugProgram" profile=any | Out-Null
  }
  if (Test-Path $releaseProgram) {
    netsh advfirewall firewall add rule name="$releaseProgramRule" dir=in action=allow program="$releaseProgram" profile=any | Out-Null
  }
  Write-RepairLog 'netsh fallback succeeded'
  exit 0
} catch {
  Write-RepairLog ('netsh fallback failed: ' + $_.Exception.Message)
  exit 1
}
'''
            .replaceAll('__TCP_PORTS__', _powerShellTcpPorts)
            .replaceAll('__UDP_PORTS__', _powerShellUdpPorts)
            .replaceAll('__TCP_PORTS_TEXT__', ports)
            .replaceAll('__UDP_PORTS_TEXT__', discoveryPorts)
            .replaceAll('__TCP_RULE__', tcpRuleName)
            .replaceAll('__OLD_TCP_RULE__', oldTcpRuleName)
            .replaceAll('__UDP_RULE__', udpRuleName)
            .replaceAll('__PROGRAM_RULE__', programRuleName)
            .replaceAll('__DEBUG_PROGRAM_RULE__', debugProgramRuleName)
            .replaceAll('__RELEASE_PROGRAM_RULE__', releaseProgramRuleName)
            .replaceAll(
              '__PROGRAM__',
              _escapePowerShellPath(Platform.resolvedExecutable),
            )
            .replaceAll(
              '__DEBUG_PROGRAM__',
              _escapePowerShellPath(_debugExecutablePath),
            )
            .replaceAll(
              '__RELEASE_PROGRAM__',
              _escapePowerShellPath(_releaseExecutablePath),
            );

    final tempDir = Directory.systemTemp.createTempSync('nearsend_firewall_');
    final scriptFile = File(
      '${tempDir.path}${Platform.pathSeparator}repair.ps1',
    );
    final outputFile = File(
      '${tempDir.path}${Platform.pathSeparator}repair_exit.txt',
    );
    await scriptFile.writeAsString(script, flush: true);

    final launcher =
        r'''
$script = '__SCRIPT__'
$exitFile = '__EXIT_FILE__'
$arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $script
$process = Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ArgumentList $arguments
if ($null -eq $process) {
  Set-Content -Path $exitFile -Value 'not-started'
} else {
  Set-Content -Path $exitFile -Value $process.ExitCode
}
'''
            .replaceAll('__SCRIPT__', _escapePowerShellPath(scriptFile.path))
            .replaceAll(
              '__EXIT_FILE__',
              _escapePowerShellPath(outputFile.path),
            );

    final launcherResult = await Process.run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      launcher,
    ]);

    final logFile = File(
      '${Platform.environment['TEMP']}'
      '${Platform.pathSeparator}nearsend_firewall_repair.log',
    );
    final log = await logFile.exists()
        ? (await logFile.readAsString()).trim()
        : '';
    final launcherOutput = [
      launcherResult.stdout.toString().trim(),
      launcherResult.stderr.toString().trim(),
    ].where((part) => part.isNotEmpty).join('\n');
    if (launcherResult.exitCode != 0) {
      return WindowsFirewallRepairResult(
        started: false,
        success: false,
        message: launcherResult.stderr.toString().trim().isEmpty
            ? 'Failed to request administrator permission'
            : launcherResult.stderr.toString().trim(),
        log: [
          log,
          launcherOutput,
        ].where((part) => part.trim().isNotEmpty).join('\n'),
      );
    }

    final exitText = await outputFile.exists()
        ? (await outputFile.readAsString()).trim()
        : '';
    final success = exitText == '0';
    return WindowsFirewallRepairResult(
      started: exitText.isNotEmpty && exitText != 'not-started',
      success: success,
      message: success
          ? 'Firewall rules were added'
          : 'Firewall repair exit code: ${exitText.isEmpty ? "unknown" : exitText}',
      log: [
        log,
        launcherOutput,
      ].where((part) => part.trim().isNotEmpty).join('\n'),
    );
  }

  String _escapePowerShellPath(String path) {
    return path.replaceAll("'", "''");
  }

  String get _debugExecutablePath {
    final executable = File(Platform.resolvedExecutable);
    final runnerDir = executable.parent.parent;
    return '${runnerDir.path}${Platform.pathSeparator}Debug'
        '${Platform.pathSeparator}nearsend.exe';
  }

  String get _releaseExecutablePath {
    final executable = File(Platform.resolvedExecutable);
    final runnerDir = executable.parent.parent;
    return '${runnerDir.path}${Platform.pathSeparator}Release'
        '${Platform.pathSeparator}nearsend.exe';
  }
}

class WindowsFirewallRepairResult {
  const WindowsFirewallRepairResult({
    required this.started,
    required this.success,
    required this.message,
    this.log,
  });

  final bool started;
  final bool success;
  final String message;
  final String? log;
}
