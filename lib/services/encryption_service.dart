import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Client-side encryption for sensitive data before it reaches Supabase.
///
/// Key derivation is deterministic: same user on any device produces the same
/// encryption key, so cloud restore works across devices without key transfer.
///
/// Uses AES-256-CBC with a random IV per record.
///
/// Required in .env:
///   ENCRYPTION_SECRET=your_random_64_char_secret
class EncryptionService {
  static final EncryptionService instance = EncryptionService._();
  EncryptionService._();

  final Map<String, encrypt.Key> _keyCache = {};

  // ---------------------------------------------------------------------------
  // KEY DERIVATION
  // ---------------------------------------------------------------------------

  encrypt.Key _deriveKey(String userId) {
    final cached = _keyCache[userId];
    if (cached != null) return cached;

    final secret = dotenv.env['ENCRYPTION_SECRET']?.trim();

    if (secret == null || secret.isEmpty) {
      throw StateError(
        'ENCRYPTION_SECRET is missing. Please add it to your .env file.',
      );
    }

    if (secret.length < 32) {
      throw StateError(
        'ENCRYPTION_SECRET is too short. Use a strong random secret with at least 32 characters.',
      );
    }

    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(userId));

    final key = encrypt.Key(Uint8List.fromList(digest.bytes));
    _keyCache[userId] = key;
    return key;
  }

  // ---------------------------------------------------------------------------
  // ENCRYPT
  // ---------------------------------------------------------------------------

  Map<String, String> encryptData(Map<String, dynamic> data, String userId) {
    final key = _deriveKey(userId);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );

    final jsonStr = jsonEncode(data);
    final encrypted = encrypter.encrypt(jsonStr, iv: iv);

    return {
      'encrypted_payload': encrypted.base64,
      'iv': iv.base64,
    };
  }

  // ---------------------------------------------------------------------------
  // DECRYPT
  // ---------------------------------------------------------------------------

  Map<String, dynamic> decryptData(
      String encryptedPayload,
      String ivBase64,
      String userId,
      ) {
    final key = _deriveKey(userId);
    final iv = encrypt.IV.fromBase64(ivBase64);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );

    try {
      final decrypted = encrypter.decrypt64(encryptedPayload, iv: iv);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      throw StateError(
        'Failed to decrypt data. Check whether ENCRYPTION_SECRET is correct and consistent across devices. Error: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  void validateConfiguration() {
    final secret = dotenv.env['ENCRYPTION_SECRET']?.trim();

    if (secret == null || secret.isEmpty) {
      throw StateError(
        'Missing ENCRYPTION_SECRET in .env file.',
      );
    }

    if (secret.length < 32) {
      throw StateError(
        'ENCRYPTION_SECRET is too short. Use at least 32 characters.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UTILS
  // ---------------------------------------------------------------------------

  void clearCache() {
    _keyCache.clear();
    debugPrint('🔐 EncryptionService: key cache cleared.');
  }
}