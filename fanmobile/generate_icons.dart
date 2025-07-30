import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() async {
  print('Generating app icons from logo.png...');
  
  // Read the source image
  final File sourceFile = File('assets/logo.png');
  if (!await sourceFile.exists()) {
    print('Error: assets/logo.png not found!');
    return;
  }
  
  final Uint8List sourceBytes = await sourceFile.readAsBytes();
  final img.Image? sourceImage = img.decodeImage(sourceBytes);
  
  if (sourceImage == null) {
    print('Error: Could not decode logo.png');
    return;
  }
  
  // Define icon sizes for different densities
  final Map<String, int> iconSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  
  // Generate icons for each density
  for (final entry in iconSizes.entries) {
    final String folder = entry.key;
    final int size = entry.value;
    
    // Create resized image
    final img.Image resized = img.copyResize(
      sourceImage,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    
    // Create directory if it doesn't exist
    final Directory dir = Directory('android/app/src/main/res/$folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    // Save the icon
    final File iconFile = File('android/app/src/main/res/$folder/ic_launcher.png');
    final Uint8List iconBytes = img.encodePng(resized);
    await iconFile.writeAsBytes(iconBytes);
    
    print('Generated: $folder/ic_launcher.png (${size}x${size})');
  }
  
  // Also generate adaptive icon background and foreground
  final int adaptiveSize = 108; // Standard adaptive icon size
  final img.Image adaptiveIcon = img.copyResize(
    sourceImage,
    width: adaptiveSize,
    height: adaptiveSize,
    interpolation: img.Interpolation.cubic,
  );
  
  // Create adaptive icon directories
  for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
    final Directory dir = Directory('android/app/src/main/res/mipmap-$density');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    // Save as ic_launcher_foreground.png for adaptive icons
    final File foregroundFile = File('android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png');
    final Uint8List foregroundBytes = img.encodePng(adaptiveIcon);
    await foregroundFile.writeAsBytes(foregroundBytes);
    
    print('Generated: mipmap-$density/ic_launcher_foreground.png');
  }
  
  print('Icon generation completed!');
  print('Note: You may need to run "flutter clean" and "flutter pub get" before building.');
} 