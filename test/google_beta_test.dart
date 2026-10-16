import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draft_ai/features/notes/domain/ports.dart';
import 'package:draft_ai/features/notes/domain/use_cases.dart';
import 'package:draft_ai/features/notes/presentation/controller.dart';
import 'package:draft_ai/features/settings/presentation/settings_pages.dart';

import 'support/memory_notes.dart';

class RecordingIdentity implements IdentityService {
  int calls = 0;
  @override
  bool get configured => true;
  @override
  String? get displayName => null;
  @override
  Future<String?> idToken() async => null;
  @override
  Future<void> signIn() async {
    calls++;
    throw StateError('Real Google must not run in beta');
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets(
    'Google beta warns, cancellation stays out, and test entry never calls Google',
    (tester) async {
      final repo = MemoryNotes(), identity = RecordingIdentity();
      addTearDown(repo.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesPort.overrideWithValue(repo),
            identityPort.overrideWithValue(identity),
            policyPort.overrideWithValue(AiPolicy(repo, DateTime.now)),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const WelcomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar sesión con Google'));
      await tester.pumpAndSettle();
      expect(find.text('Google · Beta'), findsOneWidget);
      expect(repo.prefs['entered'], isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repo.prefs['entered'], isNull);
      await tester.tap(find.text('Iniciar sesión con Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar como usuario de prueba'));
      await tester.pumpAndSettle();
      expect(repo.prefs['entered'], 'true');
      expect(repo.prefs['beta_user'], 'true');
      expect(identity.calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
