
abstract class PhoneticUtils {
  static String soundex(String s) {
    if (s.isEmpty) return "";
    
    s = s.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (s.isEmpty) return "";
    
    String firstChar = s[0];
    String mapped = s.substring(1).split('').map((char) {
      return _mapChar(char);
    }).join();
    
    // 逻辑处理
    mapped = mapped.replaceAll('0', '');
    
    // 逻辑处理
    // 逻辑处理
    // 逻辑处理
    // 逻辑处理
    
    StringBuffer result = StringBuffer();
    result.write(firstChar);
    
    String previousCode = _mapChar(firstChar);
    
    for (int i = 1; i < s.length; i++) {
      String currentCode = _mapChar(s[i]);
      if (currentCode != '0' && currentCode != previousCode) {
        result.write(currentCode);
      }
      previousCode = currentCode; // 逻辑处理
    }
    
    String finalStr = result.toString();
    if (finalStr.length < 4) {
      return finalStr.padRight(4, '0');
    }
    return finalStr.substring(0, 4);
  }

  static String _mapChar(String c) {
    if ("BFPV".contains(c)) return "1";
    if ("CGJKQSXZ".contains(c)) return "2";
    if ("DT".contains(c)) return "3";
    if ("L".contains(c)) return "4";
    if ("MN".contains(c)) return "5";
    if ("R".contains(c)) return "6";
    return "0"; // 逻辑处理
  }
}
