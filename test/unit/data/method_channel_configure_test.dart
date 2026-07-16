import 'package:exponea/exponea.dart';
import 'package:exponea/src/platform/method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelExponeaPlatform.configure', () {
    const channel = MethodChannel('com.exponea');
    late MethodChannelExponeaPlatform platform;
    late List<MethodCall> calls;
    late bool nativeConfigured;

    setUp(() {
      platform = MethodChannelExponeaPlatform();
      calls = [];
      nativeConfigured = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'configure':
            final wasConfigured = nativeConfigured;
            nativeConfigured = true;
            return !wasConfigured;
          case 'isConfigured':
            return nativeConfigured;
          case 'anonymize':
            return null;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('returns true on first call and false on subsequent call', () async {
      const configuration = ExponeaConfiguration(
        projectToken: 'mock-project-token',
        authorizationToken: 'mock-auth-token',
      );

      final firstResult = await platform.configure(configuration);
      expect(firstResult, isTrue);

      final secondResult = await platform.configure(configuration);
      expect(secondResult, isFalse);

      expect(
        calls.where((c) => c.method == 'configure'),
        hasLength(2),
        reason:
            'Both calls must reach the native side so platform-side delegates can be rebound.',
      );
    });

    test(
      'anonymize succeeds after configure returns false on a fresh engine',
      () async {
        const configuration = ExponeaConfiguration(
          projectToken: 'mock-project-token',
          authorizationToken: 'mock-auth-token',
        );

        nativeConfigured = true;

        final result = await platform.configure(configuration);
        expect(
          result,
          isFalse,
          reason: 'Native SDK was already initialized by the previous engine; '
              'configure must report false rather than throwing.',
        );

        await expectLater(platform.anonymize(), completes);
      },
    );

    test(
      'anonymize with configurationChange reaches native after configure returns false',
      () async {
        const originalConfiguration = ExponeaConfiguration(
          projectToken: 'original-project-token',
          authorizationToken: 'original-auth-token',
          baseUrl: 'https://api.original.exponea.com',
        );

        final firstResult = await platform.configure(originalConfiguration);
        expect(firstResult, isTrue);

        // Second configure with different credentials while native SDK is still
        // running (e.g. engine reattach with mismatched credentials).
        const differentConfiguration = ExponeaConfiguration(
          projectToken: 'different-project-token',
          authorizationToken: 'different-auth-token',
          baseUrl: 'https://api.different.exponea.com',
        );
        final secondResult = await platform.configure(differentConfiguration);
        expect(
          secondResult,
          isFalse,
          reason: 'Native SDK was already initialized; configure must return false.',
        );

        // anonymize() with a project that omits baseUrl must still reach the
        // native side. The native layer resolves the default baseUrl from its
        // own cache, which must remain aligned with the original credentials.
        const configChange = ExponeaConfigurationChange(
          project: ExponeaProject(
            projectToken: 'new-project-token',
            authorizationToken: 'new-auth-token',
          ),
        );
        await expectLater(platform.anonymize(configChange), completes);

        expect(
          calls.where((c) => c.method == 'anonymize'),
          hasLength(1),
          reason:
              'anonymize must reach the native side even when configure returned false.',
        );
      },
    );

    test('passes flushMode to the native configure call', () async {
      const configuration = ExponeaConfiguration(
        projectToken: 'mock-project-token',
        authorizationToken: 'mock-auth-token',
        flushMode: FlushMode.manual,
      );

      await platform.configure(configuration);

      final configureCall = calls.singleWhere((c) => c.method == 'configure');
      final arguments = configureCall.arguments as Map;
      expect(
        arguments['flushMode'],
        'MANUAL',
        reason:
            'The native side must receive the flush mode inside the configure '
            'payload so the SDK starts in that mode; applying it after '
            'configure is too late to stop the first auto-tracked flush.',
      );
    });

    test('omits flushMode from the native configure call when not set',
        () async {
      const configuration = ExponeaConfiguration(
        projectToken: 'mock-project-token',
        authorizationToken: 'mock-auth-token',
      );

      await platform.configure(configuration);

      final configureCall = calls.singleWhere((c) => c.method == 'configure');
      final arguments = configureCall.arguments as Map;
      expect(arguments.containsKey('flushMode'), isFalse);
    });
  });
}
