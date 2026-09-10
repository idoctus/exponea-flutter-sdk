import 'package:exponea/exponea.dart';
import 'package:exponea/src/data/encoder/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExponeaConfiguration.flushMode', () {
    const encode = ExponeaConfigurationEncoder.encode;
    const decode = ExponeaConfigurationEncoder.decode;

    const integrationConfig = ProjectIntegrationConfig(
      projectToken: 'mock-project-token',
      authorizationToken: 'mock-auth-token',
    );

    test('encode omits flushMode when not set', () async {
      const config = ExponeaConfiguration(
        integrationConfig: integrationConfig,
      );
      expect(encode(config).containsKey('flushMode'), false);
    });

    test('encode manual', () async {
      const config = ExponeaConfiguration(
        integrationConfig: integrationConfig,
        flushMode: FlushMode.manual,
      );
      expect(encode(config)['flushMode'], 'MANUAL');
    });

    test('decode manual', () async {
      final config = decode({
        'integrationConfig': {
          'projectToken': 'mock-project-token',
          'authorizationToken': 'mock-auth-token',
        },
        'flushMode': 'MANUAL',
      });
      expect(config.flushMode, FlushMode.manual);
    });

    test('decode no flushMode', () async {
      final config = decode({
        'integrationConfig': {
          'projectToken': 'mock-project-token',
          'authorizationToken': 'mock-auth-token',
        },
      });
      expect(config.flushMode, null);
    });
  });
}
