import 'dart:async';

import 'provisioning.dart';
import 'demo_provisioning.dart';
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
  const WifiLinkApp({super.key, this.client});

  final ProvisioningClient? client;

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
        home: SetupPage(client: client),
      );
}

enum SetupStep { device, network, credentials, connecting, result }

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, this.client});

  final ProvisioningClient? client;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  var _step = SetupStep.device;
  var _device = '';
  var _network = '';
  var _hidePassword = true;
  final _devices = <String, PiDevice>{};
  final _wifiStatus = <String, bool>{};
  var _discoveryGeneration = 0;
  var _finishedGeneration = -1;
  var _checkingStatus = false;
  List<WifiNetwork> _networks = [];
  WifiNetwork? _selectedNetwork;
  PiDevice? _selectedDevice;
  late final ProvisioningClient _client;
  StreamSubscription<PiDevice>? _scan;
  Timer? _scanTimer;
  var _busy = false;
  var _failed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = widget.client ??
        (kIsWeb ? DemoProvisioningClient() : BleProvisioningClient());
    _discover();
  }

  Future<void> _discover() async {
    final generation = ++_discoveryGeneration;
    await _scan?.cancel();
    _scanTimer?.cancel();
    await _client.close();
    if (!mounted || generation != _discoveryGeneration) return;
    setState(() {
      _devices.clear();
      _wifiStatus.clear();
      _checkingStatus = false;
      _busy = true;
      _error = null;
    });
    _scan = _client.discover().listen((device) {
      if (mounted && generation == _discoveryGeneration)
        setState(() => _devices[device.id] = device);
    }, onError: (Object error) {
      _scanTimer?.cancel();
      _finishedGeneration = generation;
      if (mounted && generation == _discoveryGeneration)
        setState(() {
          _error = 'bluetooth scan: ${provisioningErrorMessage(error)}';
          _busy = false;
        });
    }, onDone: () => _finishDiscovery(generation));
    _scanTimer =
        Timer(const Duration(seconds: 10), () => _finishDiscovery(generation));
  }

  Future<void> _finishDiscovery(int generation) async {
    if (!mounted ||
        generation != _discoveryGeneration ||
        _finishedGeneration == generation ||
        _step != SetupStep.device) return;
    _finishedGeneration = generation;
    _scanTimer?.cancel();
    _scan?.cancel();
    setState(() {
      _checkingStatus = true;
      _busy = true;
    });
    try {
      for (final device in _devices.values.toList()) {
        if (!mounted || generation != _discoveryGeneration) return;
        try {
          await _client.open(device);
          final connected = await _client.wifiConnected();
          if (mounted && generation == _discoveryGeneration)
            setState(() => _wifiStatus[device.id] = connected);
        } catch (_) {
          // An unavailable Bluetooth reading must not become "disconnected".
        } finally {
          await _client.close();
        }
      }
    } finally {
      if (mounted && generation == _discoveryGeneration)
        setState(() {
          _checkingStatus = false;
          _busy = false;
        });
    }
  }

  Future<void> _selectDevice(PiDevice device) async {
    if (_checkingStatus) return;
    _discoveryGeneration++;
    _scan?.cancel();
    _scanTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _selectedDevice = device;
      _device = device.name;
      _step = SetupStep.network;
      _networks = [];
      _busy = false;
      _error = null;
    });
    await _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    var stage = 'bluetooth connection';
    try {
      await _client.open(_selectedDevice!);
      if (!mounted) {
        await _client.close();
        return;
      }
      stage = 'wifi status';
      final connected = await _client.wifiConnected();
      if (mounted) setState(() => _wifiStatus[_selectedDevice!.id] = connected);
      stage = 'wifi scan';
      final networks = await _client.networks();
      if (mounted)
        setState(() {
          _networks = networks;
          _step = SetupStep.network;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = '$stage: ${provisioningErrorMessage(error)}';
        });
      await _client.close();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _discoveryGeneration++;
    _scanTimer?.cancel();
    _scan?.cancel();
    _client.close();
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
      _error = null;
    });
    _discover();
  }

  Future<void> _connect() async {
    if (_step != SetupStep.credentials || !_form.currentState!.validate())
      return;
    FocusScope.of(context).unfocus();
    setState(() => _step = SetupStep.connecting);
    _failed = false;
    _error = null;
    try {
      await _client.connect(_selectedNetwork!, _password.text);
      _wifiStatus[_selectedDevice!.id] = true;
    } catch (error) {
      _failed = true;
      _error =
          'wifi confirmation: ${provisioningErrorMessage(error, password: _password.text)}';
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _step = SetupStep.result);
      }
    }
  }

  Widget _choice(
          String title, String subtitle, Widget leading, VoidCallback? tap) =>
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
            for (final device in _devices.values)
              _choice(
                  device.name,
                  _wifiStatus.containsKey(device.id)
                      ? (_wifiStatus[device.id]! ? 'connected' : 'disconnected')
                      : (_busy ? 'checking...' : 'wifi status unavailable'),
                  const Icon(LucideIcons300.terminal, size: 20),
                  _checkingStatus ? null : () => _selectDevice(device)),
            if (_busy)
              Text(_checkingStatus ? 'checking wifi status...' : 'scanning...'),
            if (!_busy && _devices.isEmpty) const Text('no devices found'),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(
                onPressed: _busy ? null : _discover,
                child: const Text('refresh')),
          ],
        );
      case SetupStep.network:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('networks',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            for (final network in _networks)
              _choice(
                  network.name,
                  '${network.mhz < 3000 ? '2.4' : '5'} ghz / ${network.security}',
                  const Icon(LucideIcons300.wifi, size: 20), () {
                if (network.security == 'unsupported') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('unsupported network security')));
                  return;
                }
                setState(() {
                  _selectedNetwork = network;
                  _network = network.name;
                  _step = SetupStep.credentials;
                });
              }),
            if (_busy) const _ConnectionSpinner(),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_error != null)
              TextButton(
                  onPressed: _busy ? null : _loadNetworks,
                  child: const Text('retry')),
            if (!_busy && _error == null && _networks.isEmpty)
              const Text('no networks found'),
            TextButton(
                onPressed: _busy ? null : _restart,
                child: const Text('< back to devices')),
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
                  helperText: _selectedNetwork?.security == 'open'
                      ? 'no password required.'
                      : '8–63 characters or 64 hex digits.',
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'show password' : 'hide password',
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(_hidePassword
                        ? LucideIcons300.eye
                        : LucideIcons300.eyeOff),
                  ),
                ),
                validator: (value) {
                  if (_selectedNetwork?.security == 'open') return null;
                  final password = value ?? '';
                  if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(password))
                    return null;
                  return RegExp(r'^[ -~]{8,63}$').hasMatch(password)
                      ? null
                      : 'enter 8–63 ASCII characters or a 64-digit hex key.';
                },
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
            Text(_failed ? 'connection failed' : 'connected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: _failed
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface,
                )),
            const SizedBox(height: 12),
            Text(
                _failed
                    ? (_error ?? 'check your password and try again.')
                    : '$_device is connected to $_network.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (_failed)
              FilledButton(
                  onPressed: () =>
                      setState(() => _step = SetupStep.credentials),
                  child: const Text('retry')),
            TextButton(
                onPressed: _busy ? null : _restart,
                child: const Text('< back to devices')),
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
