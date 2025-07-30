@echo off
echo Generating app icons from logo.png...
echo.

REM Get dependencies
flutter pub get

REM Run the icon generation script
dart run generate_icons.dart

echo.
echo Icon generation completed!
echo You can now build your app with the new icons.
pause 