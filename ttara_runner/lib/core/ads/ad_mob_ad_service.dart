import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// 2026-08-11: [NoOpAdService] 플레이스홀더를 대체하는 실제 AdMob 연동.
///
/// **Android는 2026-08-11부터 YBG Ltd의 실제 AdMob 계정(앱 ID
/// ca-app-pub-3703514883602304~8606315538, AndroidManifest.xml에도 반영됨)의
/// 진짜 광고 단위 ID를 쓴다 — 실제 광고 수익이 발생한다.**
///
/// **iOS는 아직 AdMob 앱을 만들지 않아 Google 공식 테스트 ID 그대로다** — 이번
/// 세션은 Android 우선(사용자 결정: "일단 안드로이드만 출시해보고, 반응 좋으면
/// 애플 스토어도")이라 iOS는 실제 출시 준비 시점에 별도로 AdMob 앱/광고단위를
/// 새로 만들어 교체해야 한다.
String get _bannerAdUnitId =>
    Platform.isIOS ? 'ca-app-pub-3940256099942544/2934735716' : 'ca-app-pub-3703514883602304/7089073945';

String get _interstitialAdUnitId =>
    Platform.isIOS ? 'ca-app-pub-3940256099942544/4411468910' : 'ca-app-pub-3703514883602304/3341400621';

class AdMobAdService implements AdService {
  InterstitialAd? _interstitialAd;

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
          );
        },
        // 로드 실패는 조용히 무시 — 다음 [showInterstitial] 호출 시 광고가 없으면
        // 그냥 아무 일도 일어나지 않는다(학습 흐름을 막지 않는다는 인터페이스 계약).
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  @override
  Future<void> showInterstitial({int minSkipSeconds = 5}) async {
    // AdMob 전면광고는 닫기 버튼 노출 타이밍을 SDK/광고 소재가 자체적으로 제어한다
    // (프로그래매틱하게 minSkipSeconds초 뒤로 늦출 수 있는 API가 없음) — 이 값은
    // 참고용 인터페이스 계약으로만 남겨둔다.
    final ad = _interstitialAd;
    if (ad == null) return; // 로드 전이거나 로드 실패 — 조용히 스킵.
    _interstitialAd = null;
    await ad.show();
  }

  @override
  Widget bannerAdWidget(BuildContext context) => const _AdMobBannerWidget();
}

/// 배너 슬롯 위젯. 각 인스턴스가 자신만의 [BannerAd]를 로드/해제한다 — 홈 탭, 학습
/// 화면(한 문장/한꺼번에 보기) 등 여러 곳에서 동시에 [AdMobAdService.bannerAdWidget]을
/// 호출해도 서로 독립적으로 동작한다.
class _AdMobBannerWidget extends StatefulWidget {
  const _AdMobBannerWidget();

  @override
  State<_AdMobBannerWidget> createState() => _AdMobBannerWidgetState();
}

class _AdMobBannerWidgetState extends State<_AdMobBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    final ad = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _bannerAd = ad;
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ad = _bannerAd;
    return Container(
      key: const Key('ad_banner_slot'),
      width: double.infinity,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      // 로드 전/실패 시에도 레이아웃이 깨지지 않도록 항상 같은 높이를 유지한다
      // (인터페이스 계약, [AdService.bannerAdWidget] 문서 참고).
      child: (_isLoaded && ad != null) ? SizedBox(width: ad.size.width.toDouble(), height: ad.size.height.toDouble(), child: AdWidget(ad: ad)) : null,
    );
  }
}
