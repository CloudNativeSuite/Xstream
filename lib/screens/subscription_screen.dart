import 'package:flutter/material.dart';
import '../../utils/global_config.dart';
import '../../widgets/log_console.dart';
import '../../utils/app_logger.dart';
import '../../services/vpn_config_service.dart';
import '../l10n/app_localizations.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _nodeNameController = TextEditingController();
  final _domainController = TextEditingController();
  final _portController = TextEditingController(text: '443');
  final _uuidController = TextEditingController();
  String _message = '';
  String? _bundleId; // Start with null and load it asynchronously

  @override
  void initState() {
    super.initState();
    // Directly load bundleId when the state is initialized
    GlobalApplicationConfig.getBundleId().then((bundleId) {
      setState(() {
        _bundleId = bundleId;
      });
    }).catchError((_) {
      setState(() {
        _bundleId = 'com.xstream'; // Fallback value if error occurs
      });
    });
  }

  void _onCreateConfig() {
    final unlocked = GlobalState.isUnlocked.value;
    final password = GlobalState.sudoPassword.value;

    // Perform null/empty checks for required fields
    if (_nodeNameController.text.trim().isEmpty ||
        _domainController.text.trim().isEmpty ||
        _uuidController.text.trim().isEmpty ||
        _bundleId == null || _bundleId!.isEmpty) {
      setState(() {
        _message = '⚠️ 请填写所有必填项！';
      });
      addAppLog('缺少必填项或 Bundle ID', level: LogLevel.error); // Log missing fields or bundleId
      return;
    }

    if (!unlocked) {
      setState(() {
        _message = '🔒 请先点击右上角的解锁按钮。';
      });
      addAppLog('请先解锁后再创建配置', level: LogLevel.warning); // Log warning
    } else if (password.isNotEmpty) {
      // Call VpnConfigService to generate content
      VpnConfig.generateContent(
        nodeName: _nodeNameController.text.trim(),
        domain: _domainController.text.trim(),
        port: _portController.text.trim(),
        uuid: _uuidController.text.trim(),
        password: password,
        bundleId: _bundleId!,
        setMessage: (msg) {
          setState(() {
            _message = msg;
          });
        },
        logMessage: (msg) {
          addAppLog(msg);
        },
      );
    } else {
      setState(() {
        _message = '⚠️ 无法获取 sudo 密码。';
      });
      addAppLog('无法获取 sudo 密码', level: LogLevel.error); // Log error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.get('addNodeConfig')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nodeNameController,
              decoration: InputDecoration(labelText: context.l10n.get('nodeName')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _domainController,
              decoration: InputDecoration(labelText: context.l10n.get('serverDomain')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: InputDecoration(labelText: context.l10n.get('port')),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _uuidController,
              decoration: InputDecoration(labelText: context.l10n.get('uuid')),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _onCreateConfig,
              child: Text(context.l10n.get('generateSave')),
            ),
            const SizedBox(height: 16),
            Text(_message, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
