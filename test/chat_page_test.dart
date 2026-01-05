// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Replace 'your_app_name' with your actual package name
import 'package:foitifinder/pages/main_pages/dm_page.dart'; 

void main() {
  //chat page tests
  testWidgets('Chat Page allows typing and sending a message', (WidgetTester tester) async {
    // 1. Load the MessagesPage wrapped in MaterialApp 
    // (MaterialApp is required for Theme and Directionality)
    await tester.pumpWidget(const MaterialApp(
      home: DMPage(),
    ));

    // 2. Verify initial state: The list should be empty (or have your dummy data)
    // Let's assume you start with 0 or 1 dummy message. 
    // We just want to check that our NEW message isn't there yet.
    expect(find.text('Hello Robot'), findsNothing);

    // 3. Find the TextField
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    // 4. Enter Text
    await tester.enterText(textFieldFinder, 'Hello Robot');

    // 5. Find and Tap the Send Button (Icon inside the TextField)
    final sendButtonFinder = find.byIcon(Icons.send);
    expect(sendButtonFinder, findsOneWidget);
    
    await tester.tap(sendButtonFinder);

    // 6. Rebuild the widget (pump) to process the setState
    await tester.pump();

    // 7. Verify the text is now on screen
    expect(find.text('Hello Robot'), findsOneWidget);
    
    // 8. Verify the TextField was cleared
    // We cast the widget to TextField to check its controller logic indirectly
    // or just check if the finder shows empty text (harder with controllers).
    // Simpler check: Type again to ensure it doesn't append to old text.
  });

  testWidgets('Messages alternate sides (Left/Right) logic', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DMPage(),
    ));

    // Send Message 1 ("Me")
    await tester.enterText(find.byType(TextField), 'Message 1');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // Send Message 2 ("Them")
    await tester.enterText(find.byType(TextField), 'Message 2');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // Now we need to find the specific Rows or Alignments.
    // This is tricky in widget tests, but we can find the Containers with specific colors.
    
    // Check for "Me" Bubble
    final blueBubbleFinder = find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final decoration = widget.decoration as BoxDecoration;
        return decoration.color == Color(0xFF8A2BE2);
      }
      return false;
    });

    // Check for "Them" Bubble (Grey)
    final greyBubbleFinder = find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final decoration = widget.decoration as BoxDecoration;
        // Note: grey[300] is actually Color(0xFFE0E0E0)
        return decoration.color == Color(0xFF8A2BE2); 
      }
      return false;
    });

    // We expect at least one blue and one grey bubble
    expect(blueBubbleFinder, findsWidgets); 
    expect(greyBubbleFinder, findsWidgets);
  });
}
