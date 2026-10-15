import 'package:flutter_test/flutter_test.dart';
import 'package:draft_ai/core/presentation/design.dart';

void main() {
  test('adaptive layout has explicit breakpoints', () {
    expect(Breakpoints.columns(390), 1);
    expect(Breakpoints.columns(1000), 2);
  });
}
