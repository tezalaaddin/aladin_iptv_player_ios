---
name: aladin_iptv_player_ios
description: >
  Flutter tabanlı iOS/iPad IPTV oynatıcı uygulaması. Android TV sürümünden fork edildi,
  ExoPlayer/Kotlin katmanı tamamen kaldırıldı, yerine media_kit (pure Flutter) tabanlı
  çapraz platform player mimarisi kuruldu. Hedef platformlar: iPhone, iPad, Apple TV (tvOS).
version: 1.0.0
author: tezalaaddin
tags: [iptv, flutter, media-kit, streaming, isar, ios, ipad, apple-tv]
last_real_code_audit: 2026-05-24
platform: iOS / iPadOS / tvOS (Apple TV)
parent_project: aladin_iptv_player_pro (Android TV)
---

# aladin IPTV Player iOS — Skill Manifest
### Version 1.0.0 · Flutter · iOS / iPad / Apple TV

---

## 0. İçindekiler

1. [Proje Kimliği ve Fark Analizi](#1-proje-kimliği-ve-fark-analizi)
2. [Mimari Özet ve Dosya Yapısı](#2-mimari-özet-ve-dosya-yapısı)
3. [Kritik Görev: Player Migrasyonu](#3-kritik-görev-player-migrasyonu)
4. [Bağımlılıklar (pubspec.yaml)](#4-bağımlılıklar-pubspecyaml)
5. [Servis ve API Dokümantasyonu](#5-servis-ve-api-dokümantasyonu)
6. [Platform Guard Envanteri](#6-platform-guard-envanteri)
7. [Veri Akışları](#7-veri-akışları)
8. [Kullanım Senaryoları (Prompting)](#8-kullanım-senaryoları-prompting)
9. [Bilinen Sorunlar ve Yapılacaklar](#9-bilinen-sorunlar-ve-yapılacaklar)
10. [Build ve Deployment](#10-build-ve-deployment)
11. [IOS v.1.0.0+1 Sürüm Notları](#11-ios-v1001-sürüm-notları)

---

## 1. Proje Kimliği ve Fark Analizi

### Bu Proje Nedir?

`aladin_iptv_player_ios`, Android TV için yazılmış `aladin_iptv_player_pro` uygulamasının
iOS/iPad/Apple TV hedefli fork'udur. Tüm iş mantığı katmanı (M3U parsing, Isar veritabanı,
EPG motoru, Xtream API, TMDB servisi) **birebir aynıdır**. Tek değişen şey **oynatıcı katmanı**.

### Android Sürümüyle Fark Tablosu

| Bileşen | Android TV (parent) | iOS Fork (bu proje) |
|---------|---------------------|----------------------|
| **Video Player** | Native ExoPlayer (Kotlin) | media_kit (pure Flutter) |
| **Player köprüsü** | MethodChannel `aladin/exoplayer` | Yok (doğrudan Dart API) |
| **Kotlin dosyaları** | `MainActivity.kt`, `NativePlayerActivity.kt` | Yok |
| **Android TV Global Search** | ✅ Aktif | ❌ `Platform.isAndroid` guard |
| **Watch Next** | ✅ Aktif | ❌ `Platform.isAndroid` guard |
| **MediaSession** | ✅ Aktif | ❌ Yok |
| **D-pad navigasyon** | TV kumandası (Kotlin `onKeyDown`) | Flutter `KeyboardListener` |
| **İlerleme kaydı** | Kotlin → Flutter MethodChannel | media_kit stream → Dart doğrudan |
| **PiP (Picture-in-Picture)** | Kotlin `onUserLeaveHint()` | Flutter PiP (iOS 15+) |

### Ortak Kalan Her Şey (DOKUNMA)

Aşağıdaki dosyalar Android sürümüyle **aynıdır**, iOS geliştirmesinde değiştirilmemelidir:
- `lib/core/` altındaki tüm model, parser, servis, state dosyaları
- `lib/features/` altındaki tüm sayfa dosyaları (`player/` hariç)
- `lib/shared/` altındaki tüm widget ve tema dosyaları
- `lib/main.dart` (sadece `_setupNativeListener()` kaldırılacak)

---

## 2. Mimari Özet ve Dosya Yapısı

```
aladin_iptv_player_ios/
│
├── lib/
│   ├── main.dart                          # Boot, DI init, Provider setup
│   │                                      # ⚠️ _setupNativeListener() KALDIRILACAK
│   │
│   ├── core/                              # ← Android ile AYNI (dokunma)
│   │   ├── database/
│   │   │   └── aladin_isar_service.dart   # Isar singleton
│   │   ├── di/
│   │   │   └── aladin_di.dart             # GetIt service locator
│   │   ├── models/
│   │   │   ├── aladin_channel_model.dart  # Kanal/bölüm Isar koleksiyonu
│   │   │   ├── aladin_category_model.dart
│   │   │   ├── aladin_playlist_model.dart
│   │   │   ├── aladin_epg_model.dart
│   │   │   └── aladin_iptv_item.dart      # M3U parse geçici modeli
│   │   ├── parsers/
│   │   │   ├── aladin_m3u_parser.dart     # Isolate tabanlı M3U parser
│   │   │   ├── aladin_xtream_parser.dart  # Xtream Codes API istemcisi
│   │   │   └── aladin_import_bridge.dart  # URL/dosya → ChannelModel orkestrasyonu
│   │   ├── services/
│   │   │   ├── aladin_channel_service.dart    # CRUD + ilerleme kaydı
│   │   │   │                                  # ✅ Platform guard mevcut
│   │   │   ├── aladin_playlist_service.dart   # Import pipeline
│   │   │   ├── aladin_epg_engine.dart         # EPG senkronizasyon motoru
│   │   │   ├── aladin_epg_service.dart        # EPG DB sorguları
│   │   │   ├── aladin_tmdb_service.dart       # TMDB metadata
│   │   │   ├── aladin_metadata_sync_service.dart
│   │   │   ├── aladin_parental_service.dart
│   │   │   └── aladin_update_service.dart
│   │   └── state/
│   │       ├── aladin_app_state.dart      # AppState (ChangeNotifier)
│   │       ├── aladin_app_prefs.dart      # SharedPreferences wrapper
│   │       └── aladin_app_strings.dart    # Çok dilli UI metinleri (TR/EN/AR/AZ...)
│   │
│   ├── features/
│   │   ├── aladin_main_page.dart          # Ana sayfa — alt sekme navigasyonu
│   │   ├── home/
│   │   │   └── aladin_home_page.dart      # Dashboard
│   │   ├── content/
│   │   │   ├── aladin_category_page.dart
│   │   │   └── aladin_catchup_page.dart
│   │   ├── live_tv/
│   │   │   └── aladin_live_tv_page.dart
│   │   ├── movies/
│   │   │   └── aladin_movies_page.dart
│   │   ├── series/
│   │   │   └── aladin_series_page.dart    # + AladinSeriesDetailPage
│   │   ├── favorites/
│   │   │   └── aladin_favorites_page.dart
│   │   ├── search/
│   │   │   └── aladin_search_page.dart
│   │   ├── player/
│   │   │   └── aladin_player_page.dart    # 🔴 BÜYÜK DEĞİŞİKLİK — media_kit player
│   │   └── settings/
│   │       └── aladin_settings_page.dart
│   │
│   └── shared/
│       ├── theme/
│       │   └── aladin_app_theme.dart
│       └── widgets/
│           ├── aladin_app_bar.dart
│           ├── aladin_category_row.dart
│           ├── aladin_channel_card.dart
│           ├── aladin_empty_state.dart
│           ├── aladin_folder_explorer.dart
│           ├── aladin_input_dialog.dart
│           └── aladin_manual_logos.dart
│
├── ios/                                   # flutter create --platforms=ios . ile oluşturuldu
│   ├── Runner/
│   │   ├── Info.plist                     # NSAppTransportSecurity, mikrofon/ağ izinleri
│   │   └── AppDelegate.swift
│   └── Podfile                            # media_kit CocoaPods bağımlılıkları
│
└── pubspec.yaml
```

---

## 3. Kritik Görev: Player Migrasyonu

### Mevcut Durum (SORUNLU)

`aladin_player_page.dart` şu an hâlâ MethodChannel üzerinden Android ExoPlayer'ı çağırıyor.
Bu iOS'ta **çöküş** üretir.

```dart
// ⛔ MEVCUT KOD — iOS'ta çalışmaz
static const MethodChannel _exoChannel = MethodChannel('aladin/exoplayer');
await _exoChannel.invokeMethod('playNative', { ... });
```

### Hedef Mimari (media_kit)

```dart
// ✅ HEDEF — Saf Flutter, tüm platformlarda çalışır
final Player _player = Player();
final VideoController _controller = VideoController(_player);
_player.open(Media(url));
```

### `aladin_player_page.dart` — Eksiksiz Yeniden Yazım

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../../core/models/aladin_channel_model.dart';
import '../../core/models/aladin_playlist_model.dart';
import '../../core/services/aladin_channel_service.dart';
import '../../core/services/aladin_metadata_sync_service.dart';
import '../../core/state/aladin_app_prefs.dart';
import '../../core/state/aladin_app_state.dart';
import '../../shared/theme/aladin_app_theme.dart';
import '../series/aladin_series_page.dart';

class PlayerPage extends StatefulWidget {
  final ChannelModel channel;
  final List<ChannelModel> playlist;
  final PlaylistModel? playlistModel;

  const PlayerPage({
    super.key,
    required this.channel,
    required this.playlist,
    this.playlistModel,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;

  late List<ChannelModel> _playable;
  late int _currentIndex;

  bool _showControls = true;
  bool _isLive = false;
  bool _isLoading = true;
  bool _hasError = false;

  Timer? _hideTimer;
  Timer? _progressTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // ⚡ Arka plan sync'i oynatma sırasında durdur
    MetadataSyncService.instance.stopSync();

    // Boş URL'leri filtrele
    _playable = widget.playlist
        .where((e) => e.url.trim().isNotEmpty)
        .toList();

    // Xtream ana seri kaydı (url boş) → seri detay sayfasına yönlendir
    if (widget.channel.url.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AladinSeriesDetailPage(
              playlistId: widget.channel.playlistId,
              seriesName: widget.channel.seriesName ?? widget.channel.name,
              seriesId: widget.channel.tvgId,
              playlistModel: widget.playlistModel,
            ),
          ),
        );
      });
      return;
    }

    _currentIndex = _playable.indexWhere((e) => e.id == widget.channel.id);
    if (_currentIndex < 0) _currentIndex = 0;

    _isLive = _detectLive(widget.channel.url);

    // media_kit başlat
    _player = Player();
    _controller = VideoController(_player);

    _setupStreams();
    _playChannel(_playable[_currentIndex]);
    _startHideTimer();
  }

  void _setupStreams() {
    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isLoading = buffering);
    });

    _player.stream.playing.listen((_) {
      if (mounted) setState(() => _hasError = false);
    });

    _player.stream.error.listen((error) {
      if (mounted) setState(() => _hasError = true);
      debugPrint('[PlayerPage] media_kit error: $error');
    });

    _player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    // İlerleme kaydı — 60 saniyede bir (Android sürümüyle aynı mantık)
    _progressTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _saveProgress();
    });
  }

  void _playChannel(ChannelModel ch) {
    setState(() {
      _isLive = _detectLive(ch.url);
      _hasError = false;
      _isLoading = true;
    });
    _player.open(Media(ch.url));
  }

  bool _detectLive(String url) {
    final u = url.toLowerCase();
    return u.startsWith('rtsp') ||
        u.startsWith('rtp') ||
        u.startsWith('udp') ||
        (!u.contains('.mp4') &&
            !u.contains('.mkv') &&
            !u.contains('.avi') &&
            !u.contains('.ts'));
  }

  void _channelUp() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _playChannel(_playable[_currentIndex]);
    }
  }

  void _channelDown() {
    if (_currentIndex < _playable.length - 1) {
      setState(() => _currentIndex++);
      _playChannel(_playable[_currentIndex]);
    }
  }

  void _seekForward() =>
      _player.seek(_position + const Duration(seconds: 30));
  void _seekBack() =>
      _player.seek(_position - const Duration(seconds: 10));

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  Future<void> _saveProgress() async {
    final ch = _playable.isNotEmpty ? _playable[_currentIndex] : null;
    if (ch == null) return;
    if (_duration.inSeconds < 10) return;
    // ChannelService.updateProgressByUrl → %3-%90 arası kayıt, %90+ bitmiş say
    await ChannelService.instance.updateProgressByUrl(
      ch.url,
      _position.inSeconds,
      _duration.inSeconds,
    );
  }

  @override
  void dispose() {
    _saveProgress(); // Kapatırken son pozisyonu kaydet
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _focusNode.dispose();
    _player.dispose();
    // ⚡ Oynatma bitince sync'i yeniden başlat
    MetadataSyncService.instance.startSync(
      widget.channel.playlistId,
      lang: AppState.instance.lang,
    );
    super.dispose();
  }

  // ── Key handler: D-pad + iPad klavye + Apple TV Remote ──────────────────
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    setState(() => _showControls = true);
    _startHideTimer();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        if (_isLive) _channelUp();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        if (_isLive) _channelDown();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        if (!_isLive) _seekBack();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        if (!_isLive) _seekForward();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        _player.playOrPause();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        Navigator.pop(context);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: _onTap,
          child: Stack(
            children: [
              // Video
              Center(child: Video(controller: _controller)),

              // Yükleniyor
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),

              // Hata
              if (_hasError)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white54, size: 48),
                      const SizedBox(height: 12),
                      const Text('Yayın yüklenemedi',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () =>
                            _playChannel(_playable[_currentIndex]),
                        child: const Text('Yeniden Dene',
                            style: TextStyle(color: AppTheme.accent)),
                      ),
                    ],
                  ),
                ),

              // Kontroller overlay
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _buildControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final ch = _playable.isNotEmpty
        ? _playable[_currentIndex]
        : widget.channel;

    return Column(
      children: [
        // Üst bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ch.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ch.categoryName.isNotEmpty)
                      Text(
                        ch.categoryName,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (_isLive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
            ],
          ),
        ),

        const Spacer(),

        // Alt bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: Column(
            children: [
              // Seek bar (sadece VOD)
              if (!_isLive && _duration.inSeconds > 0)
                Slider(
                  value: _position.inSeconds
                      .clamp(0, _duration.inSeconds)
                      .toDouble(),
                  max: _duration.inSeconds.toDouble(),
                  onChanged: (v) =>
                      _player.seek(Duration(seconds: v.toInt())),
                  activeColor: AppTheme.accent,
                  inactiveColor: Colors.white24,
                ),

              // Kontrol düğmeleri
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Kanal yukarı (Live)
                  if (_isLive)
                    IconButton(
                      icon: const Icon(Icons.skip_previous,
                          color: Colors.white, size: 36),
                      onPressed: _channelUp,
                    ),

                  // 10sn geri (VOD)
                  if (!_isLive)
                    IconButton(
                      icon: const Icon(Icons.replay_10,
                          color: Colors.white, size: 36),
                      onPressed: _seekBack,
                    ),

                  const SizedBox(width: 16),

                  // Oynat/Durdur
                  StreamBuilder<bool>(
                    stream: _player.stream.playing,
                    builder: (_, snap) => IconButton(
                      icon: Icon(
                        (snap.data ?? false)
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 64,
                      ),
                      onPressed: _player.playOrPause,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // 30sn ileri (VOD)
                  if (!_isLive)
                    IconButton(
                      icon: const Icon(Icons.forward_30,
                          color: Colors.white, size: 36),
                      onPressed: _seekForward,
                    ),

                  // Kanal aşağı (Live)
                  if (_isLive)
                    IconButton(
                      icon: const Icon(Icons.skip_next,
                          color: Colors.white, size: 36),
                      onPressed: _channelDown,
                    ),
                ],
              ),

              // Zaman göstergesi (VOD)
              if (!_isLive && _duration.inSeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
```

### `main.dart` — Kaldırılacak Satırlar

`_setupNativeListener()` metodu ve çağrısı tamamen silinecek:

```dart
// ⛔ BU FONKSİYONU ve initState'teki ÇAĞRISINI SİL:
void _setupNativeListener() {
  const MethodChannel('aladin/exoplayer').setMethodCallHandler((call) async {
    // ... tüm blok
  });
}
```

---

## 4. Bağımlılıklar (pubspec.yaml)

### Tam pubspec.yaml

```yaml
name: aladin_iptv_player_ios
description: Aladin Media Player Pro TV — iOS/iPad Edition
publish_to: 'none'
version: 1.0.0

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # ── iOS/Apple TV Player (ExoPlayer YERİNE) ────────────────────────────────
  media_kit: ^1.1.11
  media_kit_video: ^1.2.5
  media_kit_libs_ios_video: ^1.3.3
  media_kit_libs_macos_video: ^1.3.3   # Apple TV / tvOS için

  # ── Database ──────────────────────────────────────────────────────────────
  isar_community: ^3.3.2
  isar_community_flutter_libs: ^3.3.2
  path_provider: ^2.1.3

  # ── Network ───────────────────────────────────────────────────────────────
  http: ^1.2.1
  cached_network_image: ^3.3.1

  # ── File ──────────────────────────────────────────────────────────────────
  file_picker: ^8.0.6
  permission_handler: ^12.0.1

  # ── XML + GZ (EPG) ────────────────────────────────────────────────────────
  xml: ^6.5.0
  archive: ^3.6.1

  # ── UI ────────────────────────────────────────────────────────────────────
  flutter_svg: ^2.0.10+1
  shimmer: ^3.0.0
  cupertino_icons: ^1.0.8

  # ── State ─────────────────────────────────────────────────────────────────
  provider: ^6.1.2
  get_it: ^8.0.2

  # ── Utils ─────────────────────────────────────────────────────────────────
  intl: ^0.19.0
  url_launcher: ^6.3.0
  package_info_plus: ^8.1.1
  collection: ^1.18.0
  speech_to_text: 7.4.0
  fuzzy: ^0.5.1
  flutter_secure_storage: 10.2.0
  connectivity_plus: ^6.1.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  isar_community_generator: ^3.3.2
  build_runner: any
  build_runner_core: any
  build_resolvers: any
  flutter_lints: ^3.0.0
  analyzer: ^8.4.1
  flutter_launcher_icons: ^0.13.1

dependency_overrides:
  isar_community_flutter_libs: 3.3.2
```

### media_kit İçin iOS `Info.plist` Eklentileri

```xml
<!-- ios/Runner/Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
<key>NSMicrophoneUsageDescription</key>
<string>Sesli arama için mikrofon erişimi gereklidir.</string>
```

---

## 5. Servis ve API Dokümantasyonu

### `PlayerPage` (media_kit) — Ana Arayüz

```dart
// Video oynat
Navigator.push(context, MaterialPageRoute(
  builder: (_) => PlayerPage(
    channel: channelModel,          // ChannelModel
    playlist: channelList,          // List<ChannelModel>
    playlistModel: playlistModel,   // PlaylistModel? (Xtream yönlendirme için)
  ),
));
```

**Önemli:** `channel.url` boşsa (Xtream ana seri kaydı), `PlayerPage` otomatik olarak
`AladinSeriesDetailPage`'e yönlendirir. Native player dönemindeki aynı guard davranışı korunmuştur.

### `ChannelService` — iOS İçin Kullanılabilir Metodlar

```dart
// İlerleme kaydetme (media_kit player tarafından çağrılır)
await ChannelService.instance.updateProgressByUrl(
  url,        // String — kanal URL'si
  seconds,    // int — mevcut pozisyon (saniye)
  totalSecs,  // int — toplam süre (saniye)
);
// Kural: %3-%90 arası → kayıt; %90+ → bitmiş say

// Favori toggle
await ChannelService.instance.toggleFavorite(channelId);
await ChannelService.instance.setFavoriteByUrl(url, isFavorite);

// Son izlenenler (Continue Watching)
final items = await ChannelService.instance.getContinueWatching(playlistId);

// Kategoriler
final cats = await ChannelService.instance.getCategories(
  playlistId: id,
  contentType: 'tv' | 'movie' | 'series',
);
```

### `ChannelService` — Android-Only (iOS'ta güvenle çağrılabilir, işlem yapmaz)

```dart
// Platform guard mevcut — iOS'ta sessizce döner
await ChannelService.instance.syncSearchData(playlistId);  // no-op
await ChannelService.instance.addToWatchNext(channel);     // no-op
```

### `AladinPrefs` — Ayar Okuma

```dart
// Kullanıcı seçtiği kalite
final quality = AladinPrefs.instance.getString('preferredQuality');
// '4k' | 'fhd' | 'hd' | 'sd' | null (auto)

// Seçili dil
final lang = AladinPrefs.instance.getString('lang') ?? 'tr';
```

### `AppState` — Global Durum

```dart
final state = context.read<AppState>();
final playlist = state.active;       // PlaylistModel?
final lang = state.lang;             // String
final strings = state.s;             // AppStrings (lokalizasyon)
```

---

## 6. Platform Guard Envanteri

Bu dosyalar iOS'ta güvenle çalışır çünkü Android-only çağrılar zaten guard altındadır.

| Dosya | Guard tipi | Durum |
|-------|-----------|-------|
| `aladin_channel_service.dart` | `defaultTargetPlatform == TargetPlatform.android` | ✅ Mevcut |
| `aladin_player_page.dart` | MethodChannel kaldırılıyor | 🔴 Görev devam ediyor |
| `main.dart` | `_setupNativeListener()` kaldırılıyor | 🔴 Görev devam ediyor |
| `aladin_settings_page.dart` | Decoder modu UI — iOS'ta gösterilebilir | ✅ Fonksiyonel değil ama çökmez |
| `aladin_series_page.dart` | Android TV Watch Next çağrısı yok | ✅ Temiz |
| `aladin_main_page.dart` | Global Search, MediaSession yok | ✅ Temiz |

### Henüz Eklenmemiş Guard'lar

```dart
// main.dart — _boot() içinde KALDIRILACAK:
_setupNativeListener(); // ← Bu satır ve metod tamamen silinecek

// Decoder modu ayarı (settings page) iOS'ta anlamsız:
// → Ayarlar'da göstermemeyi düşün (Platform.isAndroid guard)
```

---

## 7. Veri Akışları

### A) Video Oynatma Akışı (iOS)

```
Kullanıcı kanala tıklar
│
▼
PlayerPage(channel, playlist, playlistModel?)
│
├─ [url boş] ──► AladinSeriesDetailPage (Xtream seri yönlendirme)
│
└─ [url dolu]
    │
    ▼
    media_kit Player.open(Media(url))
    │
    ├─► stream.buffering → _isLoading state
    ├─► stream.position  → _position state (60sn'de bir DB'ye yazılır)
    ├─► stream.duration  → _duration state
    └─► stream.error     → _hasError state → retry butonu
    │
    ▼ (60 saniyede bir)
    ChannelService.updateProgressByUrl(url, seconds, totalSeconds)
    └─► Isar writeTxn → ch.watchedSeconds, ch.totalDurationSeconds
    └─► [contentType != 'tv'] addToWatchNext() → [Android guard] no-op
```

### B) İlerleme Kaydı Kuralı (Android ile Aynı)

```
izleme_yüzdesi = (seconds / totalSeconds) * 100

%3 - %90  → lastWatched = şimdi; watchedSeconds = seconds; totalDurationSeconds = total
>%90      → lastWatched = şimdi; watchedSeconds = total (bitmiş say)
<% 3      → kayıt yok
```

### C) Import Akışı (Değişmedi)

```
Kullanıcı URL/Dosya girer (SettingsPage)
│
▼
PlaylistService.importM3U() / importXtream()
│
▼
AladinM3UParser [Dart isolate] / AladinXtreamParser [async]
│
▼
List<ChannelModel> (200'lük batch)
│
▼
Isar.channelModels.putAll()
│
▼
AladinImportBridge.buildCategories()
│
▼
Isar.categoryModels.putAll()
```

---

## 8. Kullanım Senaryoları (Prompting)

Bu tablo, bir AI asistanının bu kod tabanında çalışırken hangi dosya ve fonksiyonu
kullanması gerektiğini tanımlar.

| Senaryo | Dosya / Fonksiyon |
|---------|-------------------|
| **Video oynat (iOS)** | `PlayerPage` → `media_kit Player.open(Media(url))` |
| **İlerleme kaydet** | `ChannelService.instance.updateProgressByUrl(url, secs, total)` |
| **Kaldığın yerden devam** | `ChannelService.instance.getContinueWatching(playlistId)` |
| **M3U import** | `PlaylistService.instance.importM3U(url, name)` |
| **Xtream import** | `PlaylistService.instance.importXtream(server, user, pass, name)` |
| **Kategorileri listele** | `ChannelService.instance.getCategories(playlistId, contentType)` |
| **Dizi bölümleri (Xtream)** | `AladinXtreamParser.fetchSeriesEpisodes(seriesId, pid, catName)` |
| **Favori toggle** | `ChannelService.instance.toggleFavorite(channelId)` |
| **EPG güncelle** | `AladinEpgEngine.instance.forceSync()` |
| **Dil değiştir** | `AppState.instance.setLang('tr')` |
| **Aktif playlist** | `AppState.instance.active` → `PlaylistModel?` |
| **Lokalizasyon** | `AppState.instance.s` → `AppStrings` |

### Kritik Uyarılar

```
❌ YANLIŞ: MethodChannel('aladin/exoplayer') kullanmak
✅ DOĞRU:  media_kit Player() + VideoController() kullanmak

❌ YANLIŞ: ChannelService.instance.saveWatchProgress() (bu metod yok)
✅ DOĞRU:  ChannelService.instance.updateProgressByUrl(url, secs, total)

❌ YANLIŞ: updateWatched(channelId, seconds) — sadece saniye kaydeder, süre kaydı yok
✅ DOĞRU:  updateProgressByUrl(url, seconds, totalSeconds) — tam ilerleme kaydı

❌ YANLIŞ: Xtream'de ChannelService.getSeriesEpisodes() tek başına (boş döner)
✅ DOĞRU:
   1. getSeriesEpisodes() → boş mu?
   2. Evet + playlist.type == 'xtream'
      → AladinXtreamParser.fetchSeriesEpisodes(seriesId, pid, catName)
      → ChannelService.saveChannels(episodes)
```

---

## 9. Bilinen Sorunlar ve Yapılacaklar

### 🔴 Acil (Build Blocker)

| # | Sorun | Dosya | Çözüm |
|---|-------|-------|-------|
| 1 | `aladin_player_page.dart` hâlâ MethodChannel kullanıyor | `lib/features/player/` | Bölüm 3'teki kodu yaz |
| 2 | `main.dart`'ta `_setupNativeListener()` iOS'ta gereksiz | `lib/main.dart` | Metodu ve çağrısını sil |

### 🟡 Önemli (İlk Release Öncesi)

| # | Sorun | Dosya | Çözüm |
|---|-------|-------|-------|
| 3 | `ios/` klasörü henüz yok | Proje kökü | `flutter create --platforms=ios .` |
| 4 | `ios/Runner/Info.plist` ATS ve audio izinleri eksik | `ios/Runner/` | Bölüm 4'teki XML ekle |
| 5 | Decoder modu ayarı iOS'ta görünüyor ama işlevsiz | `aladin_settings_page.dart` | `Platform.isAndroid` guard ekle |

### 🟢 Gelecek Özellikler

| # | Özellik | Not |
|---|---------|-----|
| 6 | Apple TV (tvOS) target ekleme | `flutter create --platforms=macos` değil, tvOS ayrı bir hedef |
| 7 | iOS PiP (Picture-in-Picture) | `pip_flutter` paketi veya native AVKit PiP |
| 8 | AirPlay desteği | media_kit AVPlayer backend otomatik destekler |
| 9 | iOS Siri Remote optimizasyonu | Apple TV'de `MediaKey` events |
| 10 | iOS App Store yayını | Apple Developer hesabı ($99/yıl) gerekli |

---

## 10. Build ve Deployment

### Geliştirme Ortamı

```
Geliştirme makinesi : Windows 11 (i7-12700K, RTX 4060) — Android Studio
iOS Build makinesi  : Codemagic.io (macOS M2 cloud runner)
Test cihazı         : iPad Air 2 (iOS 16, jailbreak)
Kurulum yöntemi     : AppSync Unified (jailbreak) veya AltStore (7 günlük cert)
```

### Codemagic Build Komutu (codemagic.yaml)

```yaml
workflows:
  ios-debug:
    name: iOS Debug Build
    max_build_duration: 60
    environment:
      flutter: stable
      xcode: latest
    scripts:
      - name: Flutter pub get
        script: flutter pub get
      - name: Isar code gen
        script: flutter pub run build_runner build --delete-conflicting-outputs
      - name: Build iOS (no-codesign)
        script: |
          flutter build ios --debug --no-codesign
    artifacts:
      - build/ios/iphoneos/Runner.app
```

### iPad'e Kurulum (AppSync Unified yöntemi)

```
1. Codemagic'ten .app indirin
2. iMazing veya iTunes ile .ipa oluşturun (App → Transfer to IPA)
3. iPad'de AppSync Unified yüklü olduğunu doğrulayın (Cydia/Sileo)
4. iMazing → Apps → Install IPA
```

### Flutter Minimum iOS Sürümü

```ruby
# ios/Podfile
platform :ios, '14.0'   # media_kit minimum iOS 14 gerektirir
```

### Hızlı Başlangıç

```bash
# 1. Bağımlılıkları yükle
flutter pub get

# 2. Isar G dosyalarını oluştur
flutter pub run build_runner build --delete-conflicting-outputs

# 3. iOS hedefini oluştur
flutter create --platforms=ios .

# 4. Lokal analiz (hata kontrolü)
flutter analyze

# 5. Codemagic'e push
git add .
git commit -m "feat: iOS player migration to media_kit"
git push
```

---

## 11. IOS v.1.0.0+1 Sürüm Notları

### 📅 Tarih: 2024-05-24
### 🛠 Değişiklik Özeti: Player Migrasyonu ve iOS Temel Yapılandırması

**1. Player Modernizasyonu (`media_kit` Geçişi):**
- `aladin_player_page.dart` tamamen yeniden yazıldı. Android native ExoPlayer (`MethodChannel`) bağımlılığı kaldırıldı.
- `Player` ve `VideoController` nesneleri ile saf Flutter video oynatma mimarisi kuruldu.
- Live (Canlı TV) ve VOD (Dizi/Film) tespiti için URL tabanlı `_detectLive` mantığı eklendi.
- VOD içerikler için %3 - %90 arası izleme ilerlemesini 60 saniyede bir Isar DB'ye kaydeden `_saveProgress` mekanizması entegre edildi.
- **D-pad / Keyboard Support:** Apple TV Remote ve iPad klavyeleri için `Focus` + `onKeyEvent` işleyicisi (Arrow keys, Enter, Space, Escape) eklendi.

**2. Proje Temizliği:**
- `main.dart` içerisindeki `_setupNativeListener()` metodu ve çağrısı silindi. Artık native Android tarafına veri gönderilmiyor.
- `aladin_settings_page.dart` üzerinde "Decoder Modu" (HW/SW) ayarı `defaultTargetPlatform == TargetPlatform.android` kontrolü ile iOS cihazlarda gizlendi (iOS'ta decoder seçimi native olarak yönetilir).

**3. iOS Platform Yapılandırması:**
- `flutter create --platforms=ios .` ile `ios/` klasörü initialize edildi.
- `Info.plist` güncellendi:
    - `NSAppTransportSecurity`: M3U listelerindeki HTTP (şifresiz) yayınlar için izin verildi.
    - `UIBackgroundModes`: Arka planda ses (audio) çalma yeteneği eklendi.
    - `NSMicrophoneUsageDescription`: Sesli arama özelliği için gerekli izin metni eklendi.

**4. Bağımlılık Güncellemeleri (`pubspec.yaml`):**
- `media_kit`, `media_kit_video` eklendi.
- iOS ve macOS (tvOS desteği için) native binary paketleri `1.1.4` sürümüne sabitlendi.
- Gereksiz Android-only yorum satırları ve kütüphaneler ayıklandı.

---

## Versiyon Geçmişi

| Versiyon | Tarih | Not |
|----------|-------|-----|
| 1.0.0 | 2026-05-24 | Android TV fork, media_kit entegrasyonu başladı |
| 1.0.0+1 | 2024-05-24 | iOS Player Migrasyonu tamamlandı, ilk iOS build hazırlığı. |
