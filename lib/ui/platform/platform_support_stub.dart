// SPDX-License-Identifier: GPL-2.0-or-later
Future<String?> loadCachedViaStack() async => null;

Future<void> saveCachedViaStack(String data) async {}

Future<String> downloadViaStack() async =>
    throw UnsupportedError('not available on this platform');

void exitApp() {}

Future<String?> readLocalFile(String path) async => null;
