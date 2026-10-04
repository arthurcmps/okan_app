import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_colors.dart';

class RunningPage extends StatefulWidget {
  const RunningPage({super.key});

  @override
  State<RunningPage> createState() => _RunningPageState();
}

class _RunningPageState extends State<RunningPage> {
  static const _initialCenter = LatLng(-22.785, -43.311);

  final MapController _mapController = MapController();

  LatLng? _currentLocation;
  double? _accuracyMeters;
  bool _isLocating = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _findMyLocation() async {
    if (_isLocating) return;

    setState(() => _isLocating = true);

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;

      if (!enabled) {
        _showMessage('Ative a localização do celular e tente novamente.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Libere a localização nas configurações do aplicativo Okan DEV.',
        );
        return;
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _showMessage('Precisamos da sua permissão para mostrar a posição.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;

      final location = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = location;
        _accuracyMeters = position.accuracy;
      });

      _mapController.move(location, 17);
    } on TimeoutException {
      _showMessage(
        'Não conseguimos localizar você a tempo. '
        'Tente novamente em um local com melhor sinal.',
      );
    } catch (_) {
      _showMessage('Não foi possível obter sua localização. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _openMapCredits(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('https://www.openstreetmap.org/copyright'),
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir os créditos do mapa.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Corrida'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textMain,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 14,
                minZoom: 3,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sankofa.okan',
                  maxNativeZoom: 19,
                ),
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.black,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                SimpleAttributionWidget(
                  source: const Text(
                    'OpenStreetMap contributors',
                    style: TextStyle(color: Colors.black, fontSize: 11),
                  ),
                  backgroundColor: Colors.white,
                  onTap: () => _openMapCredits(context),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _accuracyMeters == null
                        ? 'Toque abaixo para mostrar sua posição.'
                        : 'Precisão estimada: '
                              '${_accuracyMeters!.toStringAsFixed(0)} metros.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSub),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isLocating ? null : _findMyLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: _isLocating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      _isLocating ? 'Localizando...' : 'Minha localização',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
