import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:draft_ai/core/security/secure_store.dart';
import 'package:draft_ai/features/ai/data/gateway_ai.dart';
import 'package:draft_ai/features/ai/presentation/connection_dialog.dart';
import 'package:draft_ai/features/auth/data/profile_vaults.dart';
import 'package:draft_ai/features/notes/data/local/database.dart'
    show AppDatabase;
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/ports.dart';
import 'package:draft_ai/features/notes/presentation/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'ai_adapter_test.dart' show IdentityStub;
import 'support/memory_notes.dart';

final _appFailure = throwsA(isA<AppFailure>());

http.Response _completion([String model = 'modelo-prueba']) => http.Response(
  jsonEncode({
    'model': model,
    'choices': [
      {
        'message': {'content': 'OK'},
      },
    ],
  }),
  200,
);

class _Identity extends IdentityStub implements AccountIdentityService {
  @override
  String? userId;
  @override
  Future<void> signOut() async => userId = null;
}

void main() {
  test(
    'Conserva la clave antigua de Invitado y no la envía a otra URL',
    () async {
      final store = MemorySecureStore();
      final profiles = MemoryProfiles();
      const storageKey = 'guest_ai_config_v1';
      final legacy = jsonEncode({
        'endpoint': 'https://example.test/v1/',
        'apiKey': 'clave-invitado-de-prueba',
        'model': 'modelo-antiguo',
      });
      await store.write(storageKey, legacy);
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 403);
      });
      addTearDown(client.close);
      final ai = GatewayAi(store, client, profiles);
      await ai.loadProfile();

      expect(ai.configured, isTrue);
      expect(ai.provider, AiProvider.custom);
      expect(ai.model, 'modelo-antiguo');
      await expectLater(
        ai.connect(AiProvider.custom, 'https://other.test/v1/', '', 'nuevo'),
        _appFailure,
      );
      await expectLater(
        ai.connect(
          AiProvider.custom,
          'http://example.test/v1/',
          'otra-clave',
          'nuevo',
        ),
        _appFailure,
      );
      expect(requests, isEmpty);
      await expectLater(
        ai.connect(AiProvider.custom, 'https://example.test/v1', '', 'nuevo'),
        _appFailure,
      );
      expect(
        requests.single.headers['authorization'],
        'Bearer clave-invitado-de-prueba',
      );
      expect(await store.read(storageKey), legacy);
      expect(ai.model, 'modelo-antiguo');
      await ai.disconnect();
      expect(await store.read(storageKey), isNull);
      expect(ai.configured, isFalse);
    },
  );

  test('Los proveedores conocidos fijan la URL y el modelo', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return _completion();
    });
    addTearDown(client.close);
    final ai = GatewayAi(MemorySecureStore(), client, MemoryProfiles());
    await ai.loadProfile();
    for (final (provider, destination, model) in const [
      (
        AiProvider.openAi,
        'https://api.openai.com/v1/chat/completions',
        'gpt-6-luna',
      ),
      (
        AiProvider.claude,
        'https://api.anthropic.com/v1/chat/completions',
        'claude-haiku-5-5',
      ),
      (
        AiProvider.gemini,
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
        'gemini-3.1-flash-lite',
      ),
    ]) {
      const key = 'clave-falsa';
      await ai.connect(provider, 'https://other.test/', key, 'modelo-ignorado');
      final request = requests.last;
      expect(request.url.toString(), destination);
      expect(request.headers['authorization'], 'Bearer $key');
      final body = jsonDecode(request.body) as Map;
      expect(body['model'], model);
      expect(body['messages'], [
        {'role': 'user', 'content': 'Responde únicamente OK.'},
      ]);
    }
  });

  test(
    'Google A, Google B e Invitado abren sus bibliotecas y claves propias',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'draftai-ai-profiles-',
      );
      final databases = <AppDatabase>{};
      addTearDown(() async {
        for (final database in databases) {
          await database.close();
        }
        await root.delete(recursive: true);
      });
      final store = MemorySecureStore();
      final profiles = ProfileVaultManager(
        root: root,
        cache: root,
        secure: store,
        newId: () => 'test-id',
      );
      await profiles.activate(guestProfileId);
      final notes = ProfiledNotesRepository(profiles);
      Future<void> saveNote(String title) async {
        databases.add(profiles.activeNotes.db);
        final now = DateTime.now();
        await notes.saveFolder(const Folder('f', 'Carpeta', 0xFFFFFFFF));
        await notes.save(
          Note(
            id: 'n',
            folderId: 'f',
            title: title,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return _completion('gpt-6-luna');
      });
      addTearDown(client.close);
      final ai = GatewayAi(store, client, profiles);
      await ai.loadProfile();
      final identity = _Identity();
      final container = ProviderContainer(
        overrides: [
          notesPort.overrideWithValue(notes),
          profileVaultPort.overrideWithValue(profiles),
          identityPort.overrideWithValue(identity),
          aiPort.overrideWithValue(ai),
        ],
      );
      addTearDown(container.dispose);
      await container.read(controllerProvider.future);
      final controller = container.read(controllerProvider.notifier);

      await saveNote('Nota Invitado');
      await ai.connect(AiProvider.openAi, '', 'clave-guest', '');
      identity.userId = 'a';
      await controller.enterGoogle(moveGuestNotes: false);
      expect(ai.configured, isFalse);
      await saveNote('Nota A');
      await ai.connect(AiProvider.openAi, '', 'clave-google-a', '');

      final reopened = GatewayAi(store, client, profiles);
      await reopened.loadProfile();
      expect(reopened.configured, isTrue);
      expect((await notes.load()).active.single.title, 'Nota A');
      await controller.transform('Texto de A', AiAction.summarize);
      expect(requests.last.headers['authorization'], 'Bearer clave-google-a');

      identity.userId = 'b';
      await controller.enterGoogle(moveGuestNotes: false);
      expect(ai.configured, isFalse);
      expect(await store.read('account_ai_config_v1_a'), isNull);
      expect((await notes.load()).active, isEmpty);
      await saveNote('Nota B');
      await ai.connect(AiProvider.openAi, '', 'clave-google-b', '');
      await controller.leave();
      expect(await store.read('account_ai_config_v1_b'), isNull);
      expect((await notes.load()).active.single.title, 'Nota Invitado');
      await controller.transform('Texto de Invitado', AiAction.improve);
      expect(requests.last.headers['authorization'], 'Bearer clave-guest');

      identity.userId = 'a';
      await controller.enterGoogle(moveGuestNotes: false);
      expect(ai.configured, isFalse);
      expect((await notes.load()).active.single.title, 'Nota A');
    },
  );

  test(
    'Una comprobación tardía no vuelve a guardar la clave tras salir',
    () async {
      final started = Completer<void>();
      final reply = Completer<http.Response>();
      final client = MockClient((_) {
        started.complete();
        return reply.future;
      });
      addTearDown(client.close);
      final profiles = MemoryProfiles();
      await profiles.activate('a');
      final store = MemorySecureStore();
      final ai = GatewayAi(store, client, profiles);
      await ai.loadProfile();

      final verification = expectLater(
        ai.connect(AiProvider.openAi, '', 'clave-transitoria', ''),
        _appFailure,
      );
      await started.future;
      await ai.endProfileSession();
      await profiles.activate('b');
      await ai.loadProfile();
      reply.complete(_completion());
      await verification;
      expect(await store.read('account_ai_config_v1_a'), isNull);
      expect(await store.read('account_ai_config_v1_b'), isNull);
      expect(ai.configured, isFalse);
    },
  );

  for (final language in ['es', 'en']) {
    testWidgets(
      'OpenAI pide solo la clave y explica un error de permisos ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 620);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final save = language == 'es' ? 'Probar y guardar' : 'Check and save';
        final permissions = language == 'es'
            ? 'Revisa los permisos de la clave y su acceso al modelo.'
            : 'Check the key permissions and model access.';
        var allowed = false;
        final client = MockClient(
          (_) async => allowed ? _completion() : http.Response('{}', 403),
        );
        addTearDown(client.close);
        final profiles = MemoryProfiles();
        await profiles.activate('a');
        final ai = GatewayAi(MemorySecureStore(), client, profiles);
        await ai.loadProfile();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => connectAiDialog(context, ai),
                  child: const Text('Abrir conexión'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir conexión'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('OpenAI'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue,
        );
        await tester.enterText(find.byType(TextField), 'clave-solo-pruebas');
        await tester.tap(find.text(save));
        await tester.pumpAndSettle();
        expect(find.text(permissions), findsOneWidget);
        expect(ai.configured, isFalse);
        allowed = true;
        await tester.tap(find.text(save));
        await tester.pumpAndSettle();
        expect(ai.configured, isTrue);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
