import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/utils/constants/asset_constants.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';

void main() {
  const cases = [
    (width: 320.0, scale: 1.0, language: AppLanguage.english, columns: 2),
    (width: 360.0, scale: 2.0, language: AppLanguage.malayalam, columns: 1),
    (width: 720.0, scale: 1.0, language: AppLanguage.malayalam, columns: 4),
  ];

  for (final layout in cases) {
    testWidgets('overview fits at ${layout.width}px and ${layout.scale}x', (
      tester,
    ) async {
      final t = AppText(layout.language);
      final labels = [
        t.statTreesToday,
        t.workers,
        t.pendingTasks,
        t.statPendingSync,
      ];
      const counts = ['1234', '8', '1', '0'];

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(layout.scale)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: layout.width,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      OmEarthOverviewMetricGrid(
                        children: [
                          for (var index = 0; index < labels.length; index++)
                            OmEarthOverviewMetricCard(
                              value: counts[index],
                              label: labels[index],
                              illustrationAsset: ImageConstants.seedling,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final cards = find.byType(OmEarthOverviewMetricCard);
      final firstRowTop = tester.getTopLeft(cards.first).dy;
      var firstRowCount = 0;
      for (var index = 0; index < labels.length; index++) {
        final card = cards.at(index);
        final cardRect = tester.getRect(card);
        if (cardRect.top == firstRowTop) firstRowCount++;

        final label = find.text(labels[index]);
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final labelRect = tester.getRect(label);
        final image = find.descendant(of: card, matching: find.byType(Image));

        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.constraints.maxWidth, greaterThan(100));
        expect(labelRect.top, greaterThan(tester.getBottomLeft(image).dy));
        expect(labelRect.bottom, lessThan(cardRect.bottom));
        expect(find.text(counts[index]), findsOneWidget);
      }
      expect(firstRowCount, layout.columns);
    });
  }
}
