import 'dart:convert';
import 'package:crypto/crypto.dart';

abstract class CryptoHelper {
  /// Melakukan hashing password dengan algoritma SHA-256 (non-plaintext)
  /// Memenuhi kriteria FR-01 & aturan non-Firebase tugas akhir PAM
  static String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Memvalidasi kesesuaian input password dengan hash yang tersimpan
  static bool verifyPassword(String inputPassword, String storedHash) {
    return hashPassword(inputPassword) == storedHash;
  }
}
