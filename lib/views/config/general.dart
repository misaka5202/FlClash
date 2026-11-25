import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _defaultUaValue = '';
const _customUaValue = '__custom_ua__';
const _presetUas = ['clash-verge/v2.4.2', 'ClashforWindows/0.19.23'];

class LogLevelItem extends ConsumerWidget {
  const LogLevelItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final logLevel = ref.watch(
      patchClashConfigProvider.select((state) => state.logLevel),
    );
    return ListItem<LogLevel>.options(
      leading: const Icon(Icons.info_outline),
      title: Text(appLocalizations.logLevel),
      subtitle: Text(logLevel.name),
      delegate: OptionsDelegate<LogLevel>(
        title: appLocalizations.logLevel,
        options: LogLevel.values,
        onChanged: (LogLevel? value) {
          if (value == null) {
            return;
          }
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith(logLevel: value));
        },
        textBuilder: (logLevel) => logLevel.name,
        value: logLevel,
      ),
    );
  }
}

class UaItem extends ConsumerWidget {
  const UaItem({super.key});

  Future<void> _handleShowUaDialog(WidgetRef ref) async {
    final result = await globalState.showCommonDialog<_UaDialogResult>(
      child: _UaDialog(
        value: ref.read(patchClashConfigProvider).globalUa,
        customValue: ref.read(appSettingProvider).customUserAgent,
      ),
    );
    if (result == null) {
      return;
    }
    final userAgent = result.value.trim();
    if (result.isCustom) {
      ref
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(customUserAgent: userAgent));
    }
    ref
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) =>
              state.copyWith(globalUa: userAgent.isEmpty ? null : userAgent),
        );
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final globalUa = ref.watch(
      patchClashConfigProvider.select((state) => state.globalUa),
    );
    return ListItem(
      leading: const Icon(Icons.computer_outlined),
      title: Text(appLocalizations.userAgent),
      subtitle: Text(globalUa ?? appLocalizations.defaultText),
      onTap: () => _handleShowUaDialog(ref),
    );
  }
}

class _UaDialogResult {
  final String value;
  final bool isCustom;

  const _UaDialogResult({required this.value, required this.isCustom});
}

class _UaDialog extends StatefulWidget {
  final String? value;
  final String customValue;

  const _UaDialog({this.value, required this.customValue});

  @override
  State<_UaDialog> createState() => _UaDialogState();
}

class _UaDialogState extends State<_UaDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _customController;
  late String _groupValue;

  @override
  void initState() {
    super.initState();
    final value = widget.value ?? _defaultUaValue;
    _groupValue = _presetUas.contains(value) || value.isEmpty
        ? value
        : _customUaValue;
    _customController = TextEditingController(
      text: _groupValue == _customUaValue ? value : widget.customValue,
    );
  }

  void _handleChanged(String? value) {
    if (value == null) {
      return;
    }
    if (value == _customUaValue) {
      setState(() {
        _groupValue = value;
      });
      return;
    }
    Navigator.of(context).pop(_UaDialogResult(value: value, isCustom: false));
  }

  void _handleSubmit() {
    if (_groupValue == _customUaValue &&
        _formKey.currentState?.validate() == false) {
      return;
    }
    Navigator.of(context).pop(
      _UaDialogResult(
        value: _groupValue == _customUaValue
            ? _customController.text
            : _groupValue,
        isCustom: _groupValue == _customUaValue,
      ),
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.userAgent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: _handleSubmit,
          child: Text(appLocalizations.submit),
        ),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: RadioGroup<String>(
          groupValue: _groupValue,
          onChanged: _handleChanged,
          child: Wrap(
            runSpacing: 8,
            children: [
              ListItem.radio(
                delegate: RadioDelegate(
                  value: _defaultUaValue,
                  onTab: () {
                    Navigator.of(context).pop(
                      const _UaDialogResult(
                        value: _defaultUaValue,
                        isCustom: false,
                      ),
                    );
                  },
                ),
                title: Text(appLocalizations.defaultText),
              ),
              for (final ua in _presetUas)
                ListItem.radio(
                  delegate: RadioDelegate(
                    value: ua,
                    onTab: () {
                      Navigator.of(
                        context,
                      ).pop(_UaDialogResult(value: ua, isCustom: false));
                    },
                  ),
                  title: Text(ua),
                ),
              ListItem.radio(
                delegate: RadioDelegate(
                  value: _customUaValue,
                  onTab: () {
                    setState(() {
                      _groupValue = _customUaValue;
                    });
                  },
                ),
                title: Builder(
                  builder: (context) {
                    final titleStyle = DefaultTextStyle.of(context).style;
                    return TextFormField(
                      enabled: _groupValue == _customUaValue,
                      style: titleStyle,
                      maxLength: TextInputLimits.userAgent,
                      inputFormatters: TextInputLimits.limit(
                        TextInputLimits.userAgent,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        counterText: '',
                        hintStyle: titleStyle,
                        hintText: appLocalizations.custom,
                      ),
                      keyboardType: TextInputType.url,
                      maxLines: 1,
                      controller: _customController,
                      onChanged: (value) {
                        setState(() {
                          _groupValue = _customUaValue;
                        });
                      },
                      onFieldSubmitted: (_) {
                        _handleSubmit();
                      },
                      validator: (value) {
                        if (_groupValue == _customUaValue &&
                            (value == null || value.trim().isEmpty)) {
                          return appLocalizations.emptyTip(
                            appLocalizations.userAgent,
                          );
                        }
                        return null;
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KeepAliveIntervalItem extends ConsumerWidget {
  const KeepAliveIntervalItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final keepAliveInterval = ref.watch(
      patchClashConfigProvider.select((state) => state.keepAliveInterval),
    );
    return ListItem.input(
      leading: const Icon(Icons.timer_outlined),
      title: Text(appLocalizations.keepAliveIntervalDesc),
      subtitle: Text(appLocalizations.secondsCount(keepAliveInterval)),
      delegate: InputDelegate(
        title: appLocalizations.keepAliveIntervalDesc,
        suffixText: appLocalizations.seconds,
        resetValue: '$defaultKeepAliveInterval',
        value: '$keepAliveInterval',
        maxLength: TextInputLimits.interval,
        validator: (String? value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.interval);
          }
          final intValue = int.tryParse(value);
          if (intValue == null) {
            return appLocalizations.numberTip(appLocalizations.interval);
          }
          return null;
        },
        onChanged: (String? value) {
          if (value == null) {
            return;
          }
          final intValue = int.parse(value);
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith(keepAliveInterval: intValue));
        },
      ),
    );
  }
}

class TestUrlItem extends ConsumerWidget {
  const TestUrlItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final testUrl = ref.watch(
      appSettingProvider.select((state) => state.testUrl),
    );
    return ListItem.input(
      leading: const Icon(Icons.timeline),
      title: Text(appLocalizations.testUrl),
      subtitle: Text(testUrl),
      delegate: InputDelegate(
        resetValue: defaultTestUrl,
        title: appLocalizations.testUrl,
        value: testUrl,
        maxLength: TextInputLimits.url,
        validator: (String? value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.testUrl);
          }
          if (!value.isUrl) {
            return appLocalizations.urlTip(appLocalizations.testUrl);
          }
          return null;
        },
        onChanged: (String? value) {
          if (value == null) {
            return;
          }
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(testUrl: value));
        },
      ),
    );
  }
}

class PortItem extends ConsumerWidget {
  const PortItem({super.key});

  Future<void> handleShowPortDialog() async {
    await globalState.showCommonDialog(child: const _PortDialog());
    // inputDelegate.onChanged(value);
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final mixedPort = ref.watch(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    return ListItem(
      leading: const Icon(Icons.adjust_outlined),
      title: Text(appLocalizations.port),
      subtitle: Text('$mixedPort'),
      onTap: () {
        handleShowPortDialog();
      },
      // delegate: InputDelegate(
      //   title: appLocalizations.port,
      //   value: "$mixedPort",
      //   validator: (String? value) {
      //     if (value == null || value.isEmpty) {
      //       return appLocalizations.emptyTip(appLocalizations.proxyPort);
      //     }
      //     final mixedPort = int.tryParse(value);
      //     if (mixedPort == null) {
      //       return appLocalizations.numberTip(appLocalizations.proxyPort);
      //     }
      //     if (mixedPort < 1024 || mixedPort > 49151) {
      //       return appLocalizations.proxyPortTip;
      //     }
      //     return null;
      //   },
      //   onChanged: (String? value) {
      //     if (value == null) {
      //       return;
      //     }
      //     final mixedPort = int.parse(value);
      //     ref.read(patchClashConfigProvider.notifier).update(
      //           (state) => state.copyWith(
      //             mixedPort: mixedPort,
      //           ),
      //         );
      //   },
      //   resetValue: "$defaultMixedPort",
      // ),
    );
  }
}

class HostsItem extends ConsumerWidget {
  const HostsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final hosts = ref.watch(
      patchClashConfigProvider.select((state) => state.hosts),
    );
    return ListItem.open(
      leading: const Icon(Icons.view_list_outlined),
      title: const Text('Hosts'),
      subtitle: Text(appLocalizations.hostsDesc),
      delegate: OpenDelegate(
        blur: false,
        widget: MapInputPage(
          title: 'Hosts',
          map: hosts,
          keyMaxLength: TextInputLimits.domain,
          valueMaxLength: TextInputLimits.hostValue,
          titleBuilder: (item) => Text(item.key),
          subtitleBuilder: (item) => Text(item.value),
        ),
        onChanged: (value) {
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith(hosts: value));
        },
      ),
    );
  }
}

/// Parses bulk SNI mimic rules from pasted text. Each non-comment line is
/// "<domain><sep><alias>", where sep may be whitespace, '=', ',' or ':'.
/// YAML-ish lines such as `"a.com": "b.com"` are accepted too; blank lines and
/// lines starting with '#' are ignored.
Map<String, String> parseSniMimicRules(String text) {
  final rules = <String, String>{};
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    var line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    if (line.startsWith('- ')) {
      line = line.substring(2).trim();
    }
    line = line.replaceAll('"', '').replaceAll("'", '').trim();
    if (line.isEmpty) {
      continue;
    }
    String? domain;
    String? alias;
    for (final sep in const [':', '=', ',']) {
      final i = line.indexOf(sep);
      if (i > 0 && i < line.length - 1) {
        domain = line.substring(0, i).trim();
        alias = line.substring(i + 1).trim();
        break;
      }
    }
    if (domain == null || alias == null) {
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        domain = parts.first;
        alias = parts.sublist(1).join(' ');
      }
    }
    if (domain == null || alias == null || domain.isEmpty || alias.isEmpty) {
      continue;
    }
    rules[domain] = alias;
  }
  return rules;
}

class SniMimicItem extends ConsumerWidget {
  const SniMimicItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final sniMimic = ref.watch(
      patchClashConfigProvider.select((state) => state.sniMimic),
    );
    return ListItem.open(
      leading: const Icon(Icons.dns_outlined),
      title: const Text('SNI Mimic'),
      subtitle: const Text('Map a blocked domain to a benign SNI'),
      delegate: OpenDelegate(
        blur: false,
        widget: MapInputPage(
          title: 'SNI Mimic',
          map: sniMimic,
          keyMaxLength: TextInputLimits.domain,
          valueMaxLength: TextInputLimits.domain,
          titleBuilder: (item) => Text(item.key),
          subtitleBuilder: (item) => Text(item.value),
        ),
        onChanged: (value) {
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith(sniMimic: value));
          ref
              .read(setupActionProvider.notifier)
              .applyProfileDebounce(force: true);
        },
      ),
    );
  }
}

class SniMitmItem extends ConsumerWidget {
  const SniMitmItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final sniMitm = ref.watch(
      patchClashConfigProvider.select((state) => state.sniMitm),
    );
    return ListItem.switchItem(
      leading: const Icon(Icons.security_outlined),
      title: const Text('SNI MITM'),
      subtitle: const Text('Re-sign leaf certs so apps skip cert errors'),
      delegate: SwitchDelegate(
        value: sniMitm,
        onChanged: (bool value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith(sniMitm: value));
          ref
              .read(setupActionProvider.notifier)
              .applyProfileDebounce(force: true);
        },
      ),
    );
  }
}

class SniMimicImportItem extends ConsumerWidget {
  const SniMimicImportItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final current = ref.watch(
      patchClashConfigProvider.select((state) => state.sniMimic),
    );
    return ListItem.open(
      leading: const Icon(Icons.playlist_add_outlined),
      title: const Text('批量导入 SNI 规则'),
      subtitle: const Text('粘贴多行「域名 别名」，仅改 SNI；整包规则请用上面的 Cealing 导入'),
      delegate: OpenDelegate(
        blur: false,
        widget: EditorPage(
          title: '批量导入 SNI 规则',
          content: current.entries.map((e) => '${e.key} ${e.value}').join('\n'),
          onSave: (context, _, content) {
            final parsed = parseSniMimicRules(content);
            if (parsed.isEmpty) {
              context.showSnackBar('未解析到有效规则（格式：域名 别名）');
              return;
            }
            ref
                .read(patchClashConfigProvider.notifier)
                .update(
                  (state) =>
                      state.copyWith(sniMimic: {...state.sniMimic, ...parsed}),
                );
            ref
                .read(setupActionProvider.notifier)
                .applyProfileDebounce(force: true);
            context.showSnackBar('已导入 ${parsed.length} 条规则');
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class CealingRulesItem extends ConsumerWidget {
  const CealingRulesItem({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    String content,
  ) async {
    var text = content.trim();
    if (text.isEmpty) {
      _applyCealingRules(ref, const []);
      if (!context.mounted) {
        return;
      }
      context.showSnackBar('已清空 Cealing 规则');
      Navigator.of(context).pop();
      return;
    }
    if (text.startsWith('http://') || text.startsWith('https://')) {
      final fetched = await request.getText(text);
      if (fetched == null || fetched.trim().isEmpty) {
        if (context.mounted) {
          context.showSnackBar('下载失败，请检查网络或改用粘贴');
        }
        return;
      }
      text = fetched.trim();
    }
    final imported = parseCealingRules(text);
    if (imported == null) {
      if (context.mounted) {
        context.showSnackBar('未识别：需要 Cealing-Host JSON 或一个 raw 链接');
      }
      return;
    }
    final rules = mergeCealingRules(
      ref.read(patchClashConfigProvider).cealingRules,
      imported,
    );
    _applyCealingRules(ref, rules);
    if (!context.mounted) {
      return;
    }
    context.showSnackBar('已导入，当前共 ${rules.length} 条');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      patchClashConfigProvider.select((state) => state.cealingRules),
    );
    return ListItem.open(
      leading: const Icon(Icons.bolt_outlined),
      title: const Text('导入 Cealing-Host 规则'),
      subtitle: Text(
        current.isEmpty
            ? '粘贴 Cealing-Host JSON 或其 raw 链接，SNI 与解析 IP 同时生效'
            : '已加载 ${current.length} 条，清空文本后保存即可移除',
      ),
      delegate: OpenDelegate(
        blur: false,
        widget: EditorPage(
          title: '导入 Cealing-Host 规则',
          content: current.isEmpty ? '' : encodeCealingRules(current),
          onSave: (context, _, content) async {
            await _save(context, ref, content);
          },
        ),
      ),
    );
  }
}

void _applyCealingRules(WidgetRef ref, List<Object?> rules) {
  ref
      .read(patchClashConfigProvider.notifier)
      .update((state) => state.copyWith(cealingRules: rules));
  ref.read(setupActionProvider.notifier).applyProfileDebounce(force: true);
}

class SniCertInstallItem extends ConsumerWidget {
  const SniCertInstallItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ListItem(
      leading: const Icon(Icons.verified_user_outlined),
      title: const Text('安装 SNI MITM 根证书'),
      subtitle: const Text('装入系统信任库，App 不再提示证书错误'),
      onTap: () async {
        final home = await appPath.homeDirPath;
        final certPath = '$home/sni-mitm/root.crt';
        if (!await File(certPath).exists()) {
          if (context.mounted) {
            context.showSnackBar('证书未生成：请先在 SNI Mimic 中添加规则并应用');
          }
          return;
        }
        ProcessResult result;
        try {
          if (system.isWindows) {
            result = await Process.run('certutil', [
              '-addstore',
              '-user',
              'Root',
              certPath,
            ]);
          } else if (system.isMacOS) {
            final homeDir = Platform.environment['HOME'] ?? '';
            result = await Process.run('security', [
              'add-trusted-cert',
              '-d',
              '-r',
              'trustRoot',
              '-k',
              '$homeDir/Library/Keychains/login.keychain-db',
              certPath,
            ]);
          } else {
            if (context.mounted) {
              context.showSnackBar('请手动信任证书：$certPath');
            }
            return;
          }
        } catch (e) {
          if (context.mounted) {
            context.showSnackBar('安装失败：$e');
          }
          return;
        }
        if (!context.mounted) {
          return;
        }
        context.showSnackBar(
          result.exitCode == 0
              ? '根证书已安装，重启浏览器/App 后生效'
              : '安装失败：${result.stderr}',
        );
      },
    );
  }
}

class Ipv6Item extends ConsumerWidget {
  const Ipv6Item({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final ipv6 = ref.watch(
      patchClashConfigProvider.select((state) => state.ipv6),
    );
    return ListItem.switchItem(
      leading: const Icon(Icons.water_outlined),
      title: const Text('IPv6'),
      subtitle: Text(appLocalizations.ipv6Desc),
      delegate: SwitchDelegate(
        value: ipv6,
        onChanged: (bool value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith(ipv6: value));
        },
      ),
    );
  }
}

class AppendSystemDNSItem extends ConsumerWidget {
  const AppendSystemDNSItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final appendSystemDNS = ref.watch(
      networkSettingProvider.select((state) => state.appendSystemDns),
    );
    return ListItem.switchItem(
      leading: const Icon(Icons.dns_outlined),
      title: Text(appLocalizations.appendSystemDns),
      subtitle: Text(appLocalizations.appendSystemDnsTip),
      delegate: SwitchDelegate(
        value: appendSystemDNS,
        onChanged: (bool value) async {
          ref
              .read(networkSettingProvider.notifier)
              .update((state) => state.copyWith(appendSystemDns: value));
        },
      ),
    );
  }
}

class AllowLanItem extends ConsumerWidget {
  const AllowLanItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final allowLan = ref.watch(
      patchClashConfigProvider.select((state) => state.allowLan),
    );
    return ListItem.switchItem(
      leading: const Icon(Icons.device_hub),
      title: Text(appLocalizations.allowLan),
      subtitle: Text(appLocalizations.allowLanDesc),
      delegate: SwitchDelegate(
        value: allowLan,
        onChanged: (bool value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith(allowLan: value));
        },
      ),
    );
  }
}

class UnifiedDelayItem extends ConsumerWidget {
  const UnifiedDelayItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final unifiedDelay = ref.watch(
      patchClashConfigProvider.select((state) => state.unifiedDelay),
    );

    return ListItem.switchItem(
      leading: const Icon(Icons.compress_outlined),
      title: Text(appLocalizations.unifiedDelay),
      subtitle: Text(appLocalizations.unifiedDelayDesc),
      delegate: SwitchDelegate(
        value: unifiedDelay,
        onChanged: (bool value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith(unifiedDelay: value));
        },
      ),
    );
  }
}

class FindProcessItem extends ConsumerWidget {
  const FindProcessItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final findProcess = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.findProcessMode == FindProcessMode.always,
      ),
    );

    return ListItem.switchItem(
      leading: const Icon(Icons.polymer_outlined),
      title: Text(appLocalizations.findProcessMode),
      subtitle: Text(appLocalizations.findProcessModeDesc),
      delegate: SwitchDelegate(
        value: findProcess,
        onChanged: (bool value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .update(
                (state) => state.copyWith(
                  findProcessMode: value
                      ? FindProcessMode.always
                      : FindProcessMode.off,
                ),
              );
        },
      ),
    );
  }
}

class TcpConcurrentItem extends ConsumerWidget {
  const TcpConcurrentItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final tcpConcurrent = ref.watch(
      patchClashConfigProvider.select((state) => state.tcpConcurrent),
    );
    return ListItem.switchItem(
      leading: const Icon(Icons.double_arrow_outlined),
      title: Text(appLocalizations.tcpConcurrent),
      subtitle: Text(appLocalizations.tcpConcurrentDesc),
      delegate: SwitchDelegate(
        value: tcpConcurrent,
        onChanged: (value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith(tcpConcurrent: value));
        },
      ),
    );
  }
}

class GeodataLoaderItem extends ConsumerWidget {
  const GeodataLoaderItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final isMemconservative = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.geodataLoader == GeodataLoader.memconservative,
      ),
    );
    return ListItem.switchItem(
      leading: const Icon(Icons.memory),
      title: Text(appLocalizations.geodataLoader),
      subtitle: Text(appLocalizations.geodataLoaderDesc),
      delegate: SwitchDelegate(
        value: isMemconservative,
        onChanged: (bool value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .update(
                (state) => state.copyWith(
                  geodataLoader: value
                      ? GeodataLoader.memconservative
                      : GeodataLoader.standard,
                ),
              );
        },
      ),
    );
  }
}

class ExternalControllerItem extends ConsumerWidget {
  const ExternalControllerItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final hasExternalController = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.externalController == ExternalControllerStatus.open,
      ),
    );
    return ListItem.switchItem(
      leading: const Icon(Icons.api_outlined),
      title: Text(appLocalizations.externalController),
      subtitle: Text(appLocalizations.externalControllerDesc),
      delegate: SwitchDelegate(
        value: hasExternalController,
        onChanged: (bool value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .update(
                (state) => state.copyWith(
                  externalController: value
                      ? ExternalControllerStatus.open
                      : ExternalControllerStatus.close,
                ),
              );
        },
      ),
    );
  }
}

final generalItems = <Widget>[
  const LogLevelItem(),
  const UaItem(),
  if (system.isDesktop) const KeepAliveIntervalItem(),
  const TestUrlItem(),
  const PortItem(),
  const HostsItem(),
  const SniMimicItem(),
  const CealingRulesItem(),
  const SniMimicImportItem(),
  const SniMitmItem(),
  const SniCertInstallItem(),
  const Ipv6Item(),
  const AllowLanItem(),
  const UnifiedDelayItem(),
  const AppendSystemDNSItem(),
  const FindProcessItem(),
  const TcpConcurrentItem(),
  const GeodataLoaderItem(),
  const ExternalControllerItem(),
].separated(const Divider(height: 0)).toList();

class _PortDialog extends ConsumerStatefulWidget {
  const _PortDialog();

  @override
  ConsumerState<_PortDialog> createState() => _PortDialogState();
}

class _PortDialogState extends ConsumerState<_PortDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isMore = false;

  late final TextEditingController _mixedPortController;
  late final TextEditingController _portController;
  late final TextEditingController _socksPortController;
  late final TextEditingController _redirPortController;
  late final TextEditingController _tProxyPortController;

  @override
  void initState() {
    super.initState();
    final vm5 = ref.read(
      patchClashConfigProvider.select((state) {
        return VM5(
          state.mixedPort,
          state.port,
          state.socksPort,
          state.redirPort,
          state.tproxyPort,
        );
      }),
    );
    _mixedPortController = TextEditingController(text: vm5.a.toString());
    _portController = TextEditingController(text: vm5.b.toString());
    _socksPortController = TextEditingController(text: vm5.c.toString());
    _redirPortController = TextEditingController(text: vm5.d.toString());
    _tProxyPortController = TextEditingController(text: vm5.e.toString());
  }

  Future<void> _handleReset() async {
    final res = await globalState.showMessage(
      message: TextSpan(text: context.appLocalizations.resetTip),
    );
    if (res != true) {
      return;
    }
    ref
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            mixedPort: 7890,
            port: 0,
            socksPort: 0,
            redirPort: 0,
            tproxyPort: 0,
          ),
        );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleUpdate() {
    if (_formKey.currentState?.validate() == false) return;
    ref
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            mixedPort: int.parse(_mixedPortController.text),
            port: int.parse(_portController.text),
            socksPort: int.parse(_socksPortController.text),
            redirPort: int.parse(_redirPortController.text),
            tproxyPort: int.parse(_tProxyPortController.text),
          ),
        );
    Navigator.of(context).pop();
  }

  void _handleMore() {
    setState(() {
      _isMore = !_isMore;
    });
  }

  @override
  void dispose() {
    _mixedPortController.dispose();
    _portController.dispose();
    _socksPortController.dispose();
    _redirPortController.dispose();
    _tProxyPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.port,
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filledTonal(
              onPressed: _handleMore,
              icon: CommonExpandIcon(expand: _isMore),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: _handleReset,
                  child: Text(appLocalizations.reset),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _handleUpdate,
                  child: Text(appLocalizations.submit),
                ),
              ],
            ),
          ],
        ),
      ],
      child: Form(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AnimatedSize(
            duration: midDuration,
            curve: Curves.easeOutQuad,
            alignment: Alignment.topCenter,
            child: Column(
              spacing: 24,
              children: [
                TextFormField(
                  keyboardType: TextInputType.number,
                  maxLines: 1,
                  minLines: 1,
                  inputFormatters: TextInputLimits.digitsOnly(
                    TextInputLimits.port,
                  ),
                  controller: _mixedPortController,
                  onFieldSubmitted: (_) {
                    _handleUpdate();
                  },
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: appLocalizations.mixedPort,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.emptyTip(
                        appLocalizations.mixedPort,
                      );
                    }
                    final port = int.tryParse(value);
                    if (port == null) {
                      return appLocalizations.numberTip(
                        appLocalizations.mixedPort,
                      );
                    }
                    if (port < 1024 || port > 49151) {
                      return appLocalizations.portTip(
                        appLocalizations.mixedPort,
                      );
                    }
                    final ports = [
                      _portController.text,
                      _socksPortController.text,
                      _tProxyPortController.text,
                      _redirPortController.text,
                    ].map((item) => item.trim());
                    if (ports.contains(value.trim())) {
                      return appLocalizations.portConflictTip;
                    }
                    return null;
                  },
                ),
                if (_isMore) ...[
                  TextFormField(
                    keyboardType: TextInputType.number,
                    maxLines: 1,
                    minLines: 1,
                    inputFormatters: TextInputLimits.digitsOnly(
                      TextInputLimits.port,
                    ),
                    controller: _portController,
                    onFieldSubmitted: (_) {
                      _handleUpdate();
                    },
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: appLocalizations.port,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return appLocalizations.emptyTip(appLocalizations.port);
                      }
                      final port = int.tryParse(value);
                      if (port == null) {
                        return appLocalizations.numberTip(
                          appLocalizations.port,
                        );
                      }
                      if (port == 0) {
                        return null;
                      }
                      if (port < 1024 || port > 49151) {
                        return appLocalizations.portTip(appLocalizations.port);
                      }
                      final ports = [
                        _mixedPortController.text,
                        _socksPortController.text,
                        _tProxyPortController.text,
                        _redirPortController.text,
                      ].map((item) => item.trim());
                      if (ports.contains(value.trim())) {
                        return appLocalizations.portConflictTip;
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    maxLines: 1,
                    minLines: 1,
                    inputFormatters: TextInputLimits.digitsOnly(
                      TextInputLimits.port,
                    ),
                    controller: _socksPortController,
                    onFieldSubmitted: (_) {
                      _handleUpdate();
                    },
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: appLocalizations.socksPort,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return appLocalizations.emptyTip(
                          appLocalizations.socksPort,
                        );
                      }
                      final port = int.tryParse(value);
                      if (port == null) {
                        return appLocalizations.numberTip(
                          appLocalizations.socksPort,
                        );
                      }
                      if (port == 0) {
                        return null;
                      }
                      if (port < 1024 || port > 49151) {
                        return appLocalizations.portTip(
                          appLocalizations.socksPort,
                        );
                      }
                      final ports = [
                        _portController.text,
                        _mixedPortController.text,
                        _tProxyPortController.text,
                        _redirPortController.text,
                      ].map((item) => item.trim());
                      if (ports.contains(value.trim())) {
                        return appLocalizations.portConflictTip;
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    maxLines: 1,
                    minLines: 1,
                    inputFormatters: TextInputLimits.digitsOnly(
                      TextInputLimits.port,
                    ),
                    controller: _redirPortController,
                    onFieldSubmitted: (_) {
                      _handleUpdate();
                    },
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: appLocalizations.redirPort,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return appLocalizations.emptyTip(
                          appLocalizations.redirPort,
                        );
                      }
                      final port = int.tryParse(value);
                      if (port == null) {
                        return appLocalizations.numberTip(
                          appLocalizations.redirPort,
                        );
                      }
                      if (port == 0) {
                        return null;
                      }
                      if (port < 1024 || port > 49151) {
                        return appLocalizations.portTip(
                          appLocalizations.redirPort,
                        );
                      }
                      final ports = [
                        _portController.text,
                        _socksPortController.text,
                        _tProxyPortController.text,
                        _mixedPortController.text,
                      ].map((item) => item.trim());
                      if (ports.contains(value.trim())) {
                        return appLocalizations.portConflictTip;
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    maxLines: 1,
                    minLines: 1,
                    inputFormatters: TextInputLimits.digitsOnly(
                      TextInputLimits.port,
                    ),
                    controller: _tProxyPortController,
                    onFieldSubmitted: (_) {
                      _handleUpdate();
                    },
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: appLocalizations.tproxyPort,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return appLocalizations.emptyTip(
                          appLocalizations.tproxyPort,
                        );
                      }
                      final port = int.tryParse(value);
                      if (port == null) {
                        return appLocalizations.numberTip(
                          appLocalizations.tproxyPort,
                        );
                      }
                      if (port == 0) {
                        return null;
                      }
                      if (port < 1024 || port > 49151) {
                        return appLocalizations.portTip(
                          appLocalizations.tproxyPort,
                        );
                      }
                      final ports = [
                        _portController.text,
                        _socksPortController.text,
                        _mixedPortController.text,
                        _redirPortController.text,
                      ].map((item) => item.trim());
                      if (ports.contains(value.trim())) {
                        return appLocalizations.portConflictTip;
                      }

                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
