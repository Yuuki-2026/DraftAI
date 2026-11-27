import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draft_ai/features/notes/domain/ports.dart';
import 'package:draft_ai/features/ai/data/ai_services.dart';
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
    'El acceso de Invitado abre la biblioteca sin autenticar con Google',
    (tester) async {
      final repo = MemoryNotes(), identity = RecordingIdentity();
      addTearDown(repo.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesPort.overrideWithValue(repo),
            identityPort.overrideWithValue(identity),
            profileVaultPort.overrideWithValue(MemoryProfiles()),
            aiPort.overrideWithValue(DemonstrationAi()),
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
      expect(find.text('Iniciar sesión con Google'), findsOneWidget);
      expect(repo.prefs['entered'], isNull);
      await tester.tap(find.byKey(const Key('guest-enter')));
      await tester.pumpAndSettle();
      expect(repo.prefs['entered'], 'true');
      expect(identity.calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
