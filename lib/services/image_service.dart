import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class ImageService {
  // Compress image to base64 string (max ~150KB for Firestore limits)
  static Future<String?> compressImageToBase64(File imageFile, {int quality = 85, int maxWidth = 800}) async {
    try {
      // Read image bytes
      Uint8List imageBytes = await imageFile.readAsBytes();
      
      // For Flutter web/desktop or if flutter_image_compress is not available
      // We'll use a simple approach - just convert to base64
      // Note: Add flutter_image_compress package for better compression
      
      // Basic size check - if image is too large, warn user
      if (imageBytes.length > 500000) { // ~500KB
        // Image too large, would need compression
        // For now, return null to indicate it needs compression
        return null;
      }
      
      // Convert to base64
      String base64String = base64Encode(imageBytes);
      
      // Check base64 size (should be < 200KB for Firestore)
      if (base64String.length > 200000) {
        // Too large for Firestore document
        return null;
      }
      
      return base64String;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  // Compress image bytes to base64 (for when we already have bytes)
  static String? compressBytesToBase64(Uint8List imageBytes) {
    try {
      // Check size
      if (imageBytes.length > 500000) { // ~500KB
        return null;
      }
      
      String base64String = base64Encode(imageBytes);
      
      if (base64String.length > 200000) {
        return null;
      }
      
      return base64String;
    } catch (e) {
      debugPrint('Error compressing bytes: $e');
      return null;
    }
  }

  // Decode base64 to image bytes for display
  static Uint8List? decodeBase64(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      debugPrint('Error decoding base64: $e');
      return null;
    }
  }

  // Estimate compressed size in KB
  static double estimateSizeKB(String base64String) {
    return base64String.length / 1024;
  }

  // Validate base64 image
  static bool isValidBase64Image(String? base64String) {
    if (base64String == null || base64String.isEmpty) return false;
    
    try {
      final bytes = base64Decode(base64String);
      return bytes.isNotEmpty && bytes.length < 300000; // Max ~300KB
    } catch (e) {
      return false;
    }
  }
}
