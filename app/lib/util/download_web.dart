import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Saves text as a file in the browser.
bool downloadText(String filename, String content, {String mime = 'text/csv'}) {
  final bytes = utf8.encode('﻿$content'); // BOM so Excel reads Indonesian text correctly
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: '$mime;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
