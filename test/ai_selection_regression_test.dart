import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:draft_ai/core/security/secure_store.dart';
import 'package:draft_ai/features/ai/data/gateway_ai.dart';
import 'package:draft_ai/features/ai/presentation/ai_pages.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/presentation/controller.dart';
import 'package:draft_ai/features/notes/presentation/rich_ai_text.dart';

import 'support/memory_notes.dart';

void main() {
  test('an endpoint without a pairing token is not an AI connection; expired tokens are ignored', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 401);
    });
    final secure = MemorySecureStore();
    secure.values['test_ai_endpoint'] = 'https://example.test/';
    final service = GatewayAi(secure, client);
    await service.initialize();
    expect(service.configured, false);
    secure.values['test_ai_device_token'] = 'a' * 64;
    secure.values['test_ai_expires'] = '1';
    await service.initialize();
    expect(service.configured, false);
    expect(requests, 0);
    client.close();
  });
  testWidgets(
    'date mode keeps note selection and sends no unselected note to external context',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = MemoryNotes();
      Note make(String id, String title, String body) => Note(
        id: id,
        folderId: 'f',
        title: title,
        plainText: body,
        createdAt: DateTime(2026, 10, 15),
        updatedAt: DateTime(2026, 10, 15),
      );
      final chosen = make('a', 'Sistemas operativos', 'PAGINACION_ELEGIDA');
      repo.notes['a'] = chosen;
      repo.notes['b'] = make('b', 'Otra asignatura', 'CONTENIDO_NO_ELEGIDO');
      final client = MockClient((_) async => http.Response('{}', 401));
      final service = GatewayAi(MemorySecureStore(), client);
      await service.initialize();
      addTearDown(repo.close);
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesPort.overrideWithValue(repo),
            aiPort.overrideWithValue(service),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: AiPage(initialNotes: [chosen]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('IA conectada'), findsNothing);
      await tester.tap(find.text('IA externa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleccionar fechas'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preparar contexto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preparar contexto'));
      await tester.pumpAndSettle();
      final result = tester.widget<RichAiText>(find.byType(RichAiText)).text;
      expect(result, contains('PAGINACION_ELEGIDA'));
      expect(result, isNot(contains('CONTENIDO_NO_ELEGIDO')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
