import 'dart:io';

import 'project_paths.dart';

class BackendEnvLoader {
  static Future<Map<String, String>> load() async {
    final env = Map<String, String>.from(Platform.environment);
    env.addAll(await _readDotEnvFile(ProjectPaths.resolve('backend/.env')));
    env.putIfAbsent(
      'JWT_ACCESS_SECRET',
      () => 'dev-secret-key-change-in-production-123456',
    );
    env.putIfAbsent(
      'JWT_REFRESH_SECRET',
      () => 'dev-refresh-secret-key-change-in-production-789012',
    );
    env.putIfAbsent('ENVIRONMENT', () => 'development');
    return env;
  }

  static Future<Map<String, String>> _readDotEnvFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return const {};
    }

    final env = <String, String>{};
    for (final line in await file.readAsLines()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      final separatorIndex = trimmed.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      final key = trimmed.substring(0, separatorIndex).trim();
      var value = trimmed.substring(separatorIndex + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      env[key] = value;
    }
    return env;
  }
}
