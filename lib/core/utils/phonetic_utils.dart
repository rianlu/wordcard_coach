
abstract class PhoneticUtils {
  static String soundex(String s) {
    if (s.isEmpty) return "";
    
    s = s.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (s.isEmpty) return "";
    
    String firstChar = s[0];
    String mapped = s.substring(1).split('').map((char) {
      return _mapChar(char);
    }).join();
    
    // Remove zeros
    mapped = mapped.replaceAll('0', '');
    
    // Remove duplicates (not exactly standard Soundex but simplified for this context)
    // Standard Soundex collapses adjacent identical numbers *before* removing zeros if they came from same code...
    // Let's implement a simpler "Match Rating Approach" or standard Soundex.
    // Standard Soundex Implementation:
    
    StringBuffer result = StringBuffer();
    result.write(firstChar);
    
    String previousCode = _mapChar(firstChar);
    
    for (int i = 1; i < s.length; i++) {
      String currentCode = _mapChar(s[i]);
      if (currentCode != '0' && currentCode != previousCode) {
        result.write(currentCode);
      }
      previousCode = currentCode; // Update even if '0' to handle 'H' and 'W' correctly in full logic, but here simple.
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
    return "0"; // A, E, I, O, U, H, W, Y
  }
}
