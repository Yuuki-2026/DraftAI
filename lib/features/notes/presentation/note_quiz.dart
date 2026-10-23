import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../domain/entities.dart';
import '../domain/note_document.dart';
import '../domain/ports.dart';
import 'controller.dart';

class NoteQuizPage extends ConsumerStatefulWidget {
  final Note note;
  const NoteQuizPage({super.key, required this.note});

  @override
  ConsumerState<NoteQuizPage> createState() => _NoteQuizPageState();
}

class _NoteQuizPageState extends ConsumerState<NoteQuizPage> {
  List<AiQuizQuestion> questions = const [];
  var loading = true;
  var current = 0;
  var score = 0;
  int? selected;
  var answered = false;
  var finished = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  String _sourceText() {
    final stored = widget.note.plainText.trim();
    if (stored.isNotEmpty) return stored;
    return NoteDocument.delta(widget.note)
        .where((operation) => operation['insert'] is String)
        .map((operation) => operation['insert'] as String)
        .join()
        .replaceAll('\uFFFC', ' ')
        .trim();
  }

  Future<void> _generate() async {
    if (!loading && mounted) setState(() => loading = true);
    error = null;
    try {
      final text = _sourceText();
      if (text.isEmpty) {
        throw const AppFailure(
          'Añade texto al apunte para crear un cuestionario.',
        );
      }
      final generated = await ref.read(aiPort).generateQuiz(text);
      if (generated.isEmpty) {
        throw const AppFailure(
          'La IA no encontró material para crear preguntas.',
        );
      }
      if (!mounted) return;
      setState(() {
        questions = generated;
        current = 0;
        score = 0;
        selected = null;
        answered = false;
        finished = false;
      });
    } catch (exception) {
      if (mounted) {
        setState(() => error = localizedFailure(context, exception));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _choose(int index) {
    if (answered) return;
    setState(() {
      selected = index;
      answered = true;
      if (index == questions[current].answerIndex) score++;
    });
  }

  void _next() {
    if (current + 1 >= questions.length) {
      setState(() => finished = true);
      return;
    }
    setState(() {
      current++;
      selected = null;
      answered = false;
    });
  }

  void _restart() => setState(() {
    current = 0;
    score = 0;
    selected = null;
    answered = false;
    finished = false;
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final service = ref.watch(aiPort);
    final model =
        service is AiRunMetadata &&
            (service as AiRunMetadata).lastModel.isNotEmpty
        ? (service as AiRunMetadata).lastModel
        : tr(context, 'IA conectada');
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Cuestionario'))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 640,
          child: loading
              ? _loading(context)
              : error != null
              ? _errorView(context, error!)
              : finished
              ? _result(context)
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  children: [
                    Meta(widget.note.title),
                    const SizedBox(height: 5),
                    Meta('${tr(context, 'Generado con IA')} · $model'),
                    const SizedBox(height: 18),
                    LinearProgressIndicator(
                      value: (current + 1) / questions.length,
                    ),
                    const SizedBox(height: 8),
                    Meta('${current + 1} / ${questions.length}'),
                    const SizedBox(height: 18),
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            tr(context, 'Pregunta'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            questions[current].prompt,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < questions[current].options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          onPressed: answered ? null : () => _choose(i),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            disabledForegroundColor: colors.onSurface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            backgroundColor: answered && i == _correctIndex
                                ? colors.primaryContainer
                                : answered && selected == i
                                ? colors.errorContainer
                                : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(questions[current].options[i]),
                              ),
                              if (answered && i == _correctIndex)
                                Icon(Icons.check_circle, color: colors.primary)
                              else if (answered && selected == i)
                                Icon(Icons.cancel, color: colors.error),
                            ],
                          ),
                        ),
                      ),
                    if (answered) ...[
                      const SizedBox(height: 4),
                      Text(
                        selected == _correctIndex
                            ? tr(context, 'Respuesta correcta.')
                            : '${tr(context, 'Respuesta correcta:')} ${questions[current].options[_correctIndex]}',
                        style: TextStyle(
                          color: selected == _correctIndex
                              ? colors.primary
                              : colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (questions[current].explanation.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(questions[current].explanation),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _next,
                        icon: Icon(
                          current + 1 == questions.length
                              ? Icons.flag_outlined
                              : Icons.arrow_forward,
                        ),
                        label: Text(
                          tr(
                            context,
                            current + 1 == questions.length
                                ? 'Ver resultado'
                                : 'Siguiente',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  int get _correctIndex => questions[current].answerIndex;

  Widget _loading(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 14),
        Text(tr(context, 'La IA está preparando el cuestionario…')),
      ],
    ),
  );

  Widget _errorView(BuildContext context, String detail) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.refresh),
            label: Text(tr(context, 'Reintentar')),
          ),
        ],
      ),
    ),
  );

  Widget _result(BuildContext context) {
    final ratio = score / questions.length;
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ratio >= .7
                  ? Icons.emoji_events_outlined
                  : Icons.auto_stories_outlined,
              size: 48,
              color: colors.primary,
            ),
            const SizedBox(height: 14),
            Text(
              tr(context, 'Resultado'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '$score / ${questions.length}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                context,
                ratio >= .7
                    ? 'Buen repaso. Puedes volver a intentarlo cuando quieras.'
                    : 'Repasa el apunte y vuelve a intentarlo.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay),
              label: Text(tr(context, 'Intentar de nuevo')),
            ),
          ],
        ),
      ),
    );
  }
}
