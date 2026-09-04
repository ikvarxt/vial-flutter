export 'platform_support_stub.dart'
    if (dart.library.js_interop) 'platform_support_web.dart'
    if (dart.library.io) 'platform_support_io.dart';
