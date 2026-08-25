import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class GymAdIds {
  static const banner = 'ca-app-pub-2556899149200560/2699862325';
  static const testDeviceIds = <String>['AB9A963A409B8CE72B2204636633BD87'];
}

Future<void> initGymAds() async {
  if (kIsWeb) return;
  await MobileAds.instance.initialize();
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: GymAdIds.testDeviceIds),
  );
}

class GymBannerAd extends StatefulWidget {
  const GymBannerAd({super.key});

  @override
  State<GymBannerAd> createState() => _GymBannerAdState();
}

class _GymBannerAdState extends State<GymBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _load();
  }

  void _load() {
    _ad = BannerAd(
      adUnitId: GymAdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
