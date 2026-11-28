import 'dart:convert';

import 'package:draft_ai/core/presentation/design.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/note_document.dart';
import 'package:draft_ai/features/notes/presentation/controller.dart';
import 'package:draft_ai/features/notes/presentation/note_page.dart';
import 'package:draft_ai/features/notes/presentation/paper_pattern.dart';
import 'package:draft_ai/features/settings/presentation/settings_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ai_adapter_test.dart' show IdentityStub;
import 'support/memory_notes.dart';

const _paragraph =
    'Un párrafo largo que se reparte en varias líneas y sigue '
    'el renglón incluso al llegar al borde de la hoja.';

class _PaperPaintingContext extends TestRecordingPaintingContext {
  _PaperPaintingContext(super.canvas);

  @override
  void paintChild(RenderObject child, Offset offset) {}
}

Future<void> _openPage(
  WidgetTester tester,
  Widget page,
  MemoryNotes repo,
) async {
  tester.view.physicalSize = const Size(390, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(repo.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notesPort.overrideWithValue(repo),
        identityPort.overrideWithValue(IdentityStub()),
        profileVaultPort.overrideWithValue(MemoryProfiles()),
      ],
      child: MaterialApp(
        theme: appTheme(Brightness.light),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          q.FlutterQuillLocalizations.delegate,
        ],
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Invocation> _strokes(TestRecordingCanvas canvas) =>
    canvas.invocations.map((record) => record.invocation).toList();

List<double> _horizontalRules(List<Invocation> strokes) => [
  for (final stroke in strokes)
    if (stroke.memberName == #drawLine)
      if ((stroke.positionalArguments[0] as Offset).dy ==
          (stroke.positionalArguments[1] as Offset).dy)
        (stroke.positionalArguments[0] as Offset).dy,
];

List<double> _paperRules(RenderBox paper) {
  final canvas = TestRecordingCanvas();
  paper.paint(_PaperPaintingContext(canvas), Offset.zero);
  return _horizontalRules(_strokes(canvas));
}

List<double> _checkRulesUnderText(WidgetTester tester, String text) {
  final textFinder = find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
  );
  final paragraph = tester.renderObject<RenderParagraph>(textFinder);
  final paper = tester.renderObject<RenderBox>(find.byType(NotePaper));
  final top = paragraph.localToGlobal(Offset.zero, ancestor: paper).dy;
  final textBottoms =
      paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: text.length),
          )
          .map((box) => top + box.bottom)
          .toSet()
          .toList()
        ..sort();
  expect(textBottoms, isNotEmpty);
  final rules = _paperRules(paper);
  for (final bottom in textBottoms) {
    expect(rules, contains(closeTo(bottom + 1, .1)));
  }
  return textBottoms;
}

({Note note, MemoryNotes repo}) _fixture() {
  final date = DateTime(2026, 11, 27);
  final content = [
    _paragraph,
    '## Un encabezado',
    ...List.generate(18, (index) => 'Párrafo ${index + 1}'),
  ].join('\n');
  final note = Note(
    id: 'n',
    folderId: 'f',
    title: 'Mi cuaderno',
    plainText: content,
    document: jsonEncode(NoteDocument.formatted(content)),
    createdAt: date,
    updatedAt: date,
  );
  final repo = MemoryNotes()
    ..folders['f'] = const Folder('f', 'Clases', 0xffffffff)
    ..notes[note.id] = note
    ..prefs['paper_style'] = 'lines';
  return (note: note, repo: repo);
}

Future<void> _selectWideSpacing(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(NotePage)),
  );
  await container.read(controllerProvider.notifier).paperStyle(widePaperStyle);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Preferencias muestra cinco patrones distinguibles', (
    tester,
  ) async {
    final repo = MemoryNotes();
    await _openPage(tester, const PreferencesPage(), repo);
    List<Invocation> sample(String style) {
      final finder = find.byWidgetPredicate((widget) {
        if (widget is! CustomPaint) return false;
        final painter = widget.painter;
        return painter is PaperPatternPainter && painter.style == style;
      });
      final painter = tester.widget<CustomPaint>(finder).painter!;
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, tester.getSize(finder));
      return _strokes(canvas);
    }

    expect(sample('plain'), isEmpty);
    expect(
      sample('dots').map((stroke) => stroke.memberName),
      everyElement(#drawCircle),
    );
    expect(sample('dots'), isNotEmpty);
    final grid = sample('grid');
    expect(grid.length, greaterThan(_horizontalRules(grid).length));
    final ruled = _horizontalRules(sample('lines'));
    final wide = _horizontalRules(sample(widePaperStyle));
    expect(wide.length, greaterThan(1));
    expect(ruled.length, greaterThan(wide.length));

    await tester.tap(find.text('Interlineado amplio'));
    await tester.pumpAndSettle();
    expect(repo.prefs['paper_style'], widePaperStyle);
  });

  testWidgets(
    'los renglones siguen el texto en lectura al ampliar y desplazar',
    (tester) async {
      final (:note, :repo) = _fixture();
      await _openPage(tester, NotePage(note: note), repo);
      expect(_checkRulesUnderText(tester, _paragraph).length, greaterThan(1));
      _checkRulesUnderText(tester, 'Un encabezado');

      await tester.tap(find.byTooltip('Lectura'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ampliar texto'));
      await tester.pumpAndSettle();
      final normal = _checkRulesUnderText(tester, _paragraph);
      final paper = tester.renderObject<RenderBox>(find.byType(NotePaper));
      final firstRule = paper
          .localToGlobal(Offset(0, _paperRules(paper).first))
          .dy;
      final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
      scroll.jumpTo(12);
      await tester.pumpAndSettle();
      _checkRulesUnderText(tester, _paragraph);
      final scrolled = paper
          .localToGlobal(Offset(0, _paperRules(paper).first))
          .dy;
      expect(scrolled - firstRule, closeTo(-12, .1));

      await _selectWideSpacing(tester);
      final wide = _checkRulesUnderText(tester, _paragraph);
      expect(wide[1] - wide[0], greaterThan(normal[1] - normal[0]));
    },
  );

  testWidgets(
    'al editar, los renglones siguen líneas añadidas e interlineado amplio',
    (tester) async {
      final (:note, :repo) = _fixture();
      await _openPage(tester, NotePage(note: note, edit: true), repo);
      final normal = _checkRulesUnderText(tester, _paragraph);
      expect(normal.length, greaterThan(1));

      await _selectWideSpacing(tester);
      final wide = _checkRulesUnderText(tester, _paragraph);
      expect(wide[1] - wide[0], greaterThan(normal[1] - normal[0]));

      const extra = ' Un fragmento añadido que cambia el número de renglones.';
      final editor = tester
          .widget<q.QuillEditor>(find.byType(q.QuillEditor))
          .controller;
      editor.replaceText(_paragraph.length, 0, extra, null);
      await tester.pumpAndSettle();
      expect(
        _checkRulesUnderText(tester, '$_paragraph$extra').length,
        greaterThan(wide.length),
      );
    },
  );
}
