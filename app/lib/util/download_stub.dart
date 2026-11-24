/// Non-web builds: no browser download. Returns false so the caller can show the text instead.
bool downloadText(String filename, String content, {String mime = 'text/csv'}) => false;
