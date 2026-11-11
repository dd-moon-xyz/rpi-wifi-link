import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['Lucide'],
      await rootBundle.loadString('assets/licenses/lucide.txt'),
    );
  });
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['JetBrains Mono'],
      await rootBundle.loadString('assets/licenses/jetbrains-mono.txt'),
    );
  });
  runApp(const WifiLinkApp());
}

class WifiLinkApp extends StatelessWidget {
  const WifiLinkApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'rpi-wifi-link',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'JetBrains Mono',
          scaffoldBackgroundColor: const Color(0xFF09090B),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFAFAFA),
            onPrimary: Color(0xFF18181B),
            secondary: Color(0xFFA1A1AA),
            onSecondary: Color(0xFF09090B),
            surface: Color(0xFF09090B),
            onSurface: Color(0xFFFAFAFA),
            onSurfaceVariant: Color(0xFFA1A1AA),
            outline: Color(0xFF27272A),
            outlineVariant: Color(0xFF27272A),
            error: Color(0xFFF87171),
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF09090B),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleTextStyle: TextStyle(
              color: Color(0xFFFAFAFA),
              fontSize: 16,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF09090B),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFF27272A)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFA1A1AA),
              minimumSize: const Size(48, 48),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            labelStyle: TextStyle(color: Color(0xFFA1A1AA)),
            helperStyle: TextStyle(color: Color(0xFFA1A1AA)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
              borderSide: BorderSide(color: Color(0xFF27272A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
              borderSide: BorderSide(color: Color(0xFFA1A1AA)),
            ),
          ),
        ),
        home: const SetupPage(),
      );
}

enum SetupStep { device, network, credentials, connecting, result }

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, this.simulateFailure = false});

  final bool simulateFailure;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  var _step = SetupStep.device;
  var _device = '';
  var _network = '';
  var _connectedNetwork = '';
  var _hidePassword = true;
  bool get _simulateFailure => widget.simulateFailure || _device == 'raspi-02';

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _restart() {
    _password.clear();
    setState(() {
      _step = SetupStep.device;
      _device = '';
      _network = '';
      _hidePassword = true;
    });
  }

  Future<void> _connect() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = SetupStep.connecting);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _password.clear();
    setState(() {
      if (!_simulateFailure) _connectedNetwork = _network;
      _step = SetupStep.result;
    });
  }

  Widget _choice(
          String title, String subtitle, Widget leading, VoidCallback tap) =>
      Card.outlined(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: leading,
          title: Text(title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle, style: const TextStyle(fontSize: 12)),
          ),
          trailing: const Text('>'),
          onTap: tap,
        ),
      );

  Widget _content() {
    switch (_step) {
      case SetupStep.device:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('devices',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            _choice(
                'raspi-01',
                _connectedNetwork.isEmpty ? 'disconnected' : 'connected',
                const Icon(LucideIcons300.terminal, size: 20), () {
              setState(() {
                _device = 'raspi-01';
                _step = SetupStep.network;
              });
            }),
            _choice('raspi-02', 'disconnected',
                const Icon(LucideIcons300.terminal, size: 20), () {
              setState(() {
                _device = 'raspi-02';
                _step = SetupStep.network;
              });
            }),
          ],
        );
      case SetupStep.network:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('networks',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            for (final name in ['wifi-01', 'wifi-02', 'wifi-03'])
              _choice(name, '2.4 ghz / secured',
                  const Icon(LucideIcons300.wifi, size: 20), () {
                setState(() {
                  _network = name;
                  _step = SetupStep.credentials;
                });
              }),
            TextButton(
                onPressed: _restart, child: const Text('< back to devices')),
          ],
        );
      case SetupStep.credentials:
        return Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('connect device',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text('$_device -> $_network'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _password,
                obscureText: _hidePassword,
                autocorrect: false,
                enableSuggestions: false,
                onFieldSubmitted: (_) => _connect(),
                decoration: InputDecoration(
                  labelText: 'wifi password',
                  helperText: 'minimum 8 characters.',
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'show password' : 'hide password',
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(_hidePassword
                        ? LucideIcons300.eye
                        : LucideIcons300.eyeOff),
                  ),
                ),
                validator: (value) => (value ?? '').length < 8
                    ? 'enter at least 8 characters.'
                    : null,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _connect, child: const Text('connect')),
              TextButton(
                onPressed: () {
                  _password.clear();
                  setState(() => _step = SetupStep.network);
                },
                child: const Text('< back to networks'),
              ),
            ],
          ),
        );
      case SetupStep.connecting:
        return const Column(children: [
          SizedBox(height: 48),
          _ConnectionSpinner(),
          SizedBox(height: 24),
          Text('connecting...', style: TextStyle(fontSize: 24)),
          SizedBox(height: 8),
          Text('establishing wifi connection.'),
        ]);
      case SetupStep.result:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_simulateFailure ? 'connection failed' : 'connected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: _simulateFailure
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface,
                )),
            const SizedBox(height: 12),
            Text(
                _simulateFailure
                    ? 'check your password and try again.'
                    : '$_device is connected to $_network.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (_simulateFailure)
              FilledButton(
                  onPressed: () =>
                      setState(() => _step = SetupStep.credentials),
                  child: const Text('retry')),
            TextButton(
                onPressed: _restart, child: const Text('< back to devices')),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    '[ raspi wifi setup ]',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _content(),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ConnectionSpinner extends StatefulWidget {
  const _ConnectionSpinner();

  @override
  State<_ConnectionSpinner> createState() => _ConnectionSpinnerState();
}

class _ConnectionSpinnerState extends State<_ConnectionSpinner>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'connecting',
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) => SizedBox(
              width: 24,
              height: 32,
              child: Center(
                child: Text(
                  const [
                    '⠋',
                    '⠙',
                    '⠹',
                    '⠸',
                    '⠼',
                    '⠴',
                    '⠦',
                    '⠧',
                    '⠇',
                    '⠏'
                  ][(_animation.value * 10).floor()],
                  style: const TextStyle(
                      fontSize: 24, fontFamily: 'JetBrains Mono'),
                ),
              ),
            ),
          ),
        ),
      );
}
