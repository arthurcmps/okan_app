import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/core/widgets/video_player_page.dart';

void main() {
  group('VideoPlayerPage', () {
    test('normalizes supported YouTube URLs', () {
      expect(
        VideoPlayerPage.youtubeVideoId(
          '  https://youtu.be/dQw4w9WgXcQ  ',
        ),
        'dQw4w9WgXcQ',
      );
      expect(VideoPlayerPage.youtubeVideoId('   '), isNull);
      expect(
        VideoPlayerPage.youtubeVideoId('https://example.com/video'),
        isNull,
      );
    });

    testWidgets('shows an accessible state for an unsupported link', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const VideoPlayerPage(
            videoUrl: 'https://example.com/video',
            exerciseName: '  Agachamento livre  ',
          ),
        ),
      );

      expect(find.text('Agachamento livre'), findsOneWidget);
      expect(
        find.text('Link de vídeo inválido ou não suportado.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Link de vídeo inválido ou não suportado.',
        ),
      );

      expect(semantics.properties.liveRegion, isTrue);
    });

    testWidgets('uses a safe title when the exercise name is blank', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const VideoPlayerPage(
            videoUrl: '',
            exerciseName: '   ',
          ),
        ),
      );

      expect(find.text('Vídeo do exercício'), findsOneWidget);
    });
  });
}
