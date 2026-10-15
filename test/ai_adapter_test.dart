import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:draft_ai/features/ai/data/ai_services.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/ports.dart';

class IdentityStub implements IdentityService {
  @override
  bool get configured => true;
  @override
  String? get displayName => 'Prueba';
  @override
  Future<String?> idToken() async => 'simulated-test-token';
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  test(
    'remote transform uses HTTPS, bearer token and stable payload',
    () async {
      final service = RemoteAi(
        Uri.parse('https://example.test/api/'),
        IdentityStub(),
        MockClient((request) async {
          expect(request.url.path, '/api/v1/transform');
          expect(
            request.headers['Authorization'],
            'Bearer simulated-test-token',
          );
          expect(jsonDecode(request.body)['action'], 'summarize');
          return http.Response('{"text":"Síntesis"}', 200);
        }),
      );
      expect(
        await service.transform('Material', AiAction.summarize),
        'Síntesis',
      );
      expect(
        () => RemoteAi(
          Uri.parse('http://example.test'),
          IdentityStub(),
          http.Client(),
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test('provider quota and invalid responses become neutral errors', () async {
    for (final response in [
      http.Response('limit', 429),
      http.Response('{}', 200),
      http.Response('invalid json', 200),
    ]) {
      final service = RemoteAi(
        Uri.parse('https://example.test/'),
        IdentityStub(),
        MockClient((_) async => response),
      );
      await expectLater(
        service.transform('text', AiAction.summarize),
        throwsA(isA<AppFailure>()),
      );
    }
  });
  test('demo OCR explicitly states it did not read the image', () async {
    final proposal = await DemonstrationAi().analyze([
      PickedFile('image.jpg', 'image/jpeg', Uint8List(0)),
    ], const Library([], [], []));
    expect(proposal.demonstration, true);
    expect(proposal.text, contains('No se ha ejecutado OCR'));
  });
}
