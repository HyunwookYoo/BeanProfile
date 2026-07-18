import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:beanprofile/features/tasting/tasting_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

bool _textFieldFocused() {
  final f = FocusManager.instance.primaryFocus;
  // EditableText wraps its focus node in an internal `Focus` widget (see
  // framework's editable_text.dart), so the node's own context is that
  // `Focus`, never `EditableText` itself — check the ancestor chain instead.
  return f != null && f.context?.findAncestorWidgetOfExactType<EditableText>() != null;
}

void main() {
  testWidgets('tasting form: tapping empty area dismisses the keyboard', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(wrapApp(const TastingFormScreen(beanId: 1), db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first); // focus the comment field
    await tester.pump();
    expect(_textFieldFocused(), isTrue);

    await tester.tap(find.text('강도')); // non-interactive label → translucent GestureDetector
    await tester.pump();
    expect(_textFieldFocused(), isFalse);
  });

  testWidgets('bean form: tapping empty area dismisses the keyboard', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(wrapApp(const BeanFormScreen(), db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('field-name')));
    await tester.pump();
    expect(_textFieldFocused(), isTrue);

    await tester.tap(find.text('원산지 구성'));
    await tester.pump();
    expect(_textFieldFocused(), isFalse);
  });
}
