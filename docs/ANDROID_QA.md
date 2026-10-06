# Android Technical Alpha — Stage 6 QA

## Назначение

Это первый технический debug/QA APK после полного аудита Stage 0–5. Он не является store/release build, не использует production signing и не задаёт публичную release identity. Финальный art, audio, сеть, backend, аналитика и store SDK отсутствуют.

| Поле | Значение |
|---|---|
| Preset | `Android QA` |
| Application label | `ODRAVETH Stage 6 QA` |
| Package ID | `com.example.odraveth.qa` |
| Version | `0.6.1-qa` (`versionCode=7`) |
| Build | debug, стандартная debug-подпись Godot |

Package ID намеренно технический. Перед публикацией его нужно заменить отдельным утверждённым ID; изменение создаст для Android другое приложение и другое приватное хранилище.

## Toolchain

- Godot **4.7.2 stable** с export templates той же версии;
- OpenJDK 17;
- Android SDK Platform 36 и Build Tools 36.0.0 для targetSdk 36 официального 4.7.2 template;
- Platform Tools 35.0.0 или новее;
- совместимый baseline из официальной инструкции Godot: Platform 35, Build Tools 35.0.1, CMake 3.10.2.4988404, NDK 28.1.13356709. CMake/NDK нужны для custom Gradle/native builds; текущий QA preset использует prebuilt template.

Локальные SDK/JDK пути задаются только в Godot Editor Settings и не коммитятся. `export_presets.cfg` не содержит keystore, паролей или абсолютных путей.

## Export contract

- только landscape: `display/window/handheld/orientation=4` (`userLandscape`, обе альбомные ориентации согласно настройкам пользователя ОС);
- fullscreen immersive + edge-to-edge;
- все экраны используют `SafeAreaContainer`, который учитывает `DisplayServer.get_display_safe_area()`;
- GL Compatibility, импорт ETC2/ASTC включён;
- четыре ABI: `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`;
- `minSdk=24`, `targetSdk=36` задаются официальным prebuilt template;
- offline: custom permissions пусты, `INTERNET` не запрашивается;
- backup user data отключён;
- `tests/**`, `docs/**`, `.github/**` исключены; production scenes/scripts и `data/cards/*.json` включены.

Техническая SVG-иконка является placeholder для валидного Android export и не является финальным art.

## Сборка

После настройки Android SDK и Java SDK в Godot Editor Settings:

```bash
godot --headless --path . --import
GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 \
ANDROID_SDK_ROOT=/path/to/android-sdk \
tools/build_android_qa.sh
```

Перед сборкой должны пройти:

```bash
GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 tests/run_tests.sh
```

## Проверка APK

```bash
unzip -t build/ODRAVETH-Stage6-QA-v0.6.1.apk
aapt2 dump badging build/ODRAVETH-Stage6-QA-v0.6.1.apk
aapt2 dump permissions build/ODRAVETH-Stage6-QA-v0.6.1.apk
apkanalyzer manifest print build/ODRAVETH-Stage6-QA-v0.6.1.apk
apksigner verify --verbose --print-certs build/ODRAVETH-Stage6-QA-v0.6.1.apk
sha256sum build/ODRAVETH-Stage6-QA-v0.6.1.apk
```

Проверить package/version, `screenOrientation=11` (`userLandscape`), min/target SDK, отсутствие `uses-permission` для сети, четыре ABI, пять `data/cards/*.json`, отсутствие каталогов tests/docs/.github и валидную debug-подпись.

## Установка и QA

```bash
adb install -r build/ODRAVETH-Stage6-QA-v0.6.1.apk
adb shell am force-stop com.example.odraveth.qa
adb shell monkey -p com.example.odraveth.qa -c android.intent.category.LAUNCHER 1
adb logcat
```

На реальном устройстве проверить холодный старт, обе landscape-ориентации, cutout/safe area, системный Back, сохранение профиля после перезапуска и полный путь Hero Select → Deck Builder → Prebattle → Battle → Result/Rematch. Во время боя первый Back должен открыть подтверждение выхода.

## Известные ограничения

- Q-15 («Прогресс», «Настройки») остаётся открытым; оба экрана являются placeholders.
- Колода противника создаётся временным внутренним генератором без продуктового preset/name.
- Damage Forecast сохранён как presentation hook; отдельный прогноз не рисуется без authoritative API.
- Debug certificate и временный package ID нельзя использовать для store release.
- Незавершённый матч не сохраняется.

## Защита от неполного APK

`tools/build_android_qa.sh` экспортирует во временный файл, полностью читает
каждую ZIP-запись, проверяет package/version и APK Signature Scheme v2/v3 и
только после этого атомарно присваивает итоговое имя. Частично записанный APK
не может заменить последний валидный артефакт.
