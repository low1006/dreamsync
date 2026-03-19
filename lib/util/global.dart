import 'package:flutter/material.dart';

// This allows you to navigate without context from anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// This allows you to show SnackBars (toast messages) without context
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();