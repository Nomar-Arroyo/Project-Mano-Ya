import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/core/utils/formatters.dart';
import 'package:mano_ya/features/requests/presentation/pages/request_form_page.dart';

void main() {
  testWidgets('appointment date is selected with a Spanish calendar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const RequestFormPage(
            workerId: 'worker-id',
            workerName: 'Trabajador',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Seleccionar fecha'));
    await tester.pumpAndSettle();

    expect(find.text('Selecciona la fecha de la cita'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Aceptar'), findsOneWidget);

    final today = DateUtils.dateOnly(DateTime.now());
    await tester.tap(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text(today.day.toString()),
      ),
    );
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    expect(find.text(Formatters.date(today)), findsOneWidget);
  });
}
