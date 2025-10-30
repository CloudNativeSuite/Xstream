import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../utils/app_logger.dart';
import '../../utils/global_config.dart' show GlobalState, buildVersion;
import '../../utils/native_bridge.dart';
import '../session/session_manager.dart';
import 'device_fingerprint.dart';
import 'sync_crypto.dart';
import 'sync_payload.dart';
import 'sync_state.dart';
import 'xray_config_writer.dart';

class DesktopSyncResult {
  final bool success;
  final String message;
  final SyncResponseStatus? status;

  const DesktopSyncResult({
    required this.success,
    required this.message,
    this.status,
  });
}

class DesktopSyncService {
  DesktopSyncService._();

  static final DesktopSyncService instance = DesktopSyncService._();

  static const _syncPath = '/api/config/sync';
  static const _requestVersion = 1;
  static const _autoInterval = Duration(minutes: 10);
  static const _nodeName = 'Desktop Sync';

  final ValueNotifier<bool> syncing = ValueNotifier<bool>(false);

  Timer? _timer;
  bool _initialized = false;
  bool _syncing = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await SessionManager.instance.init();
    await SyncStateStore.instance.init();
    SessionManager.instance.status.addListener(_handleSessionChange);
    _handleSessionChange();
  }

  void dispose() {
    _timer?.cancel();
    SessionManager.instance.status.removeListener(_handleSessionChange);
    _initialized = false;
  }

  Future<DesktopSyncResult> syncNow({bool manual = false}) async {
    if (!SessionManager.instance.isLoggedIn) {
      return const DesktopSyncResult(success: false, message: '请先登录');
    }
    if (_syncing) {
      return const DesktopSyncResult(success: false, message: '同步进行中');
    }

    _syncing = true;
    syncing.value = true;
    try {
      const maxAttempts = 3;
      var attempt = 0;
      DesktopSyncResult? finalResult;
      while (attempt < (manual ? 1 : maxAttempts)) {
        attempt += 1;
        final result = await _performSync();
        finalResult = result;
        if (result.success || result.status == SyncResponseStatus.noPrivilege) {
          break;
        }
        final delay = Duration(seconds: pow(2, attempt).toInt());
        await Future.delayed(delay);
      }
      return finalResult ??
          const DesktopSyncResult(success: false, message: '同步失败');
    } finally {
      _syncing = false;
      syncing.value = false;
    }
  }

  void _handleSessionChange() {
    _timer?.cancel();
    if (SessionManager.instance.isLoggedIn) {
      _timer = Timer.periodic(_autoInterval, (_) {
        unawaited(syncNow(manual: false));
      });
      // 初次登录后立即同步
      unawaited(syncNow(manual: false));
    }
  }

  Future<DesktopSyncResult> _performSync() async {
    final session = SessionManager.instance;
    final cookie = session.cookie;
    final secret = session.syncSecret;
    if (cookie == null || secret == null) {
      final message = '缺少会话信息，请重新登录';
      await SyncStateStore.instance.recordError(message);
      await session.logout();
      return DesktopSyncResult(success: false, message: message);
    }

    try {
      final fingerprint = await DeviceFingerprint.loadOrCreate();
      final nonce = _generateNonce();
      final request = SyncRequest(
        version: _requestVersion,
        deviceFingerprint: fingerprint,
        clientVersion: buildVersion,
        nonce: nonce,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        lastConfigVersion: SyncStateStore.instance.lastConfigVersion,
      );
      final plaintext = request.toBytes();
      final encrypted = await SyncCrypto.encrypt(
        secret: secret,
        nonce: nonce,
        plaintext: plaintext,
      );
      final payload = BytesBuilder()
        ..add(nonce)
        ..add(encrypted);

      final response = await http.post(
        session.buildEndpoint(_syncPath),
        headers: {
          'Content-Type': 'application/octet-stream',
          'Accept': 'application/octet-stream',
          'Cookie': cookie,
        },
        body: payload.toBytes(),
      );

      if (response.statusCode == 404) {
        const message = '桌面同步未启用 (404)';
        await SyncStateStore.instance.recordError(message);
        return const DesktopSyncResult(success: false, message: message);
      }

      if (response.statusCode == 401) {
        const message = '会话已过期，请重新登录';
        await SyncStateStore.instance.recordError(message);
        await session.logout();
        return const DesktopSyncResult(success: false, message: message);
      }

      if (response.statusCode != 200) {
        final message = '同步接口返回 ${response.statusCode}';
        await SyncStateStore.instance.recordError(message);
        return DesktopSyncResult(success: false, message: message);
      }

      final bodyBytes = response.bodyBytes;
      if (bodyBytes.length < 24) {
        const message = '响应体长度不足';
        await SyncStateStore.instance.recordError(message);
        return const DesktopSyncResult(success: false, message: message);
      }
      final responseNonce = Uint8List.sublistView(bodyBytes, 0, 24);
      final cipherText = Uint8List.sublistView(bodyBytes, 24);
      final decrypted = await SyncCrypto.decrypt(
        secret: secret,
        nonce: responseNonce,
        cipherText: cipherText,
      );
      final syncResponse = parseSyncResponse(decrypted);

      switch (syncResponse.status) {
        case SyncResponseStatus.ok:
          return await _handleSuccess(syncResponse);
        case SyncResponseStatus.noPrivilege:
          const message = '账号没有桌面同步权限';
          await SyncStateStore.instance.recordError(message);
          return const DesktopSyncResult(
            success: false,
            message: message,
            status: SyncResponseStatus.noPrivilege,
          );
        case SyncResponseStatus.error:
          const message = '服务器返回错误状态';
          await SyncStateStore.instance.recordError(message);
          return const DesktopSyncResult(success: false, message: message);
      }
    } catch (e) {
      final message = '同步失败: $e';
      await SyncStateStore.instance.recordError(message);
      return DesktopSyncResult(success: false, message: message);
    }
  }

  Future<DesktopSyncResult> _handleSuccess(SyncResponse response) async {
    try {
      final gzipData = response.xrayConfigGzip;
      final configJson = gzipData.isEmpty
          ? '{}'
          : utf8.decode(GZipCodec().decode(gzipData));
      final configPath = await XrayConfigWriter.writeConfig(configJson);
      await XrayConfigWriter.registerNode(configPath);
      await SyncStateStore.instance.recordSuccess(
        configVersion: response.configVersion,
        metadata: response.subscriptionMetadata,
      );
      addAppLog('桌面配置已同步至 $configPath (版本 ${response.configVersion})');
      await _restartNodeIfPossible();
      return DesktopSyncResult(
        success: true,
        message: '同步成功 (版本 ${response.configVersion})',
        status: SyncResponseStatus.ok,
      );
    } catch (e) {
      final message = '处理同步配置失败: $e';
      await SyncStateStore.instance.recordError(message);
      return DesktopSyncResult(success: false, message: message);
    }
  }

  Future<void> _restartNodeIfPossible() async {
    try {
      if (!GlobalState.isUnlocked.value) {
        addAppLog('同步成功，等待解锁后手动重启服务');
        return;
      }
      await NativeBridge.stopNodeService(_nodeName);
      await Future.delayed(const Duration(seconds: 1));
      await NativeBridge.startNodeService(_nodeName);
      addAppLog('已重启 $_nodeName 服务');
    } catch (e) {
      addAppLog('重启 $_nodeName 失败: $e');
    }
  }

  Uint8List _generateNonce() {
    final random = Random.secure();
    final nonce = Uint8List(24);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = random.nextInt(256);
    }
    return nonce;
  }
}
