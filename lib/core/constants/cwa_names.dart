/// CWA 縣市／鄉鎮名一律用「臺」，用「台」會回 200 但資料為空。
String normalizeCwaName(String name) => name.replaceAll('台', '臺');
