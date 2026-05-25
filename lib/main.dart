import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'core/database/aladin_isar_service.dart';
import 'core/services/aladin_channel_service.dart';
import 'core/di/aladin_di.dart';
import 'core/state/aladin_app_prefs.dart';
import 'core/state/aladin_app_state.dart';
import 'core/state/aladin_app_strings.dart';
import 'core/services/aladin_metadata_sync_service.dart';
import 'core/services/aladin_epg_engine.dart';
import 'features/aladin_main_page.dart';
import 'shared/theme/aladin_app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (foundation.kReleaseMode) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(16),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white38, size: 28),
            SizedBox(height: 6),
            Text('Görüntülenemiyor', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      );
    }
    return ErrorWidget(details.exception);
  };

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const AladinApp());
}

class AladinApp extends StatefulWidget {
  const AladinApp({super.key});
  @override
  State<AladinApp> createState() => _AladinAppState();
}

class _AladinAppState extends State<AladinApp> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _phase = 0; 
  late AnimationController _animCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
    _boot();
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _animCtrl.dispose(); super.dispose(); }

  Future<void> _boot() async {
    await AladinPrefs.instance.load();
    await initDI();
    await Future.wait([IsarService.instance.init(), AppState.instance.init()]);
    await AppState.instance.loadPlaylists();
    if (!mounted) return;
    final hasLang = AladinPrefs.instance.getString('lang') != null;
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _phase = hasLang ? 2 : 1);
  }

  void _onLangSelected(String lang) async {
    await AppState.instance.setLang(lang);
    if (mounted) setState(() => _phase = 2);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AppState.instance),
        ChangeNotifierProvider.value(value: MetadataSyncService.instance),
        ChangeNotifierProvider.value(value: AladinEpgEngine.instance),
      ],
      child: MaterialApp(
        title: 'Aladin IPTV',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: FocusScope(
          autofocus: true,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: switch (_phase) {
              1 => _LangSelect(onSelect: _onLangSelected),
              2 => const MainPage(),
              _ => _Splash(fade: _fade),
            },
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  final Animation<double> fade;
  const _Splash({required this.fade});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FadeTransition(
        opacity: fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.45), blurRadius: 15, spreadRadius: 2)],
                ),
                child: const Icon(Icons.live_tv, color: Colors.white, size: 52),
              ),
              const SizedBox(height: 26),
              const Text('Aladin Media Player Pro', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangSelect extends StatelessWidget {
  final void Function(String) onSelect;
  const _LangSelect({required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final langs = AppStrings.getLanguageNames();
    return Scaffold(
      body: Center(
        child: Wrap(
          spacing: 20, runSpacing: 20,
          children: langs.entries.map((e) => _LangBtn(
            flag: e.value.split(' ')[0],
            label: e.value.split(' ').skip(1).join(' '),
            autofocus: e.key == 'en',
            onTap: () => onSelect(e.key),
          )).toList(),
        ),
      ),
    );
  }
}

class _LangBtn extends StatefulWidget {
  final String flag, label;
  final VoidCallback onTap;
  final bool autofocus;
  const _LangBtn({required this.flag, required this.label, required this.onTap, this.autofocus = false});
  @override
  State<_LangBtn> createState() => _LangBtnState();
}

class _LangBtnState extends State<_LangBtn> with SingleTickerProviderStateMixin {
  bool _focused = false;
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) { setState(() => _focused = v); if (v) _ctrl.forward(); else _ctrl.reverse(); },
      onKeyEvent: (n, e) {
        if (e is KeyDownEvent && (e.logicalKey == LogicalKeyboardKey.select || e.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap(); return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: 240, height: 72,
            decoration: BoxDecoration(
              color: _focused ? Colors.white : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text("${widget.flag} ${widget.label}", style: TextStyle(color: _focused ? Colors.black : Colors.white, fontSize: 18))),
          ),
        ),
      ),
    );
  }
}
