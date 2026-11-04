import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/core/config/backend_config.dart';

void main() {
  const json = {'host': 'localhost', 'port': 8080, 'autoStartBackend': true};

  test('the main PC uses its own server and no key', () {
    final c = BackendConfig.fromJson(json, const {});
    expect(c.baseUrl, 'http://localhost:8080');
    expect(c.autoStartBackend, isTrue);
    expect(c.accessKey, '');
  });

  test('another PC connects to the main PC and never starts a server', () {
    final c = BackendConfig.fromJson(json, const {'NMS_SERVER_HOST': '172.16.0.50', 'NMS_SERVER_KEY': 'k1'});
    expect(c.baseUrl, 'http://172.16.0.50:8080');
    expect(c.wsBaseUrl, 'ws://172.16.0.50:8080');
    expect(c.autoStartBackend, isFalse);
    expect(c.accessKey, 'k1');
  });
}
