/// 이용약관/개인정보처리방침 본문 — 2026-08-10 초안. **법률 자문이 아니며, 실제 출시
/// 전 변호사 검토가 필요하다**(화면에도 이 문구를 노출한다). 대괄호로 표시된
/// `[사업자명/개발자명]`, `[문의 이메일 주소]`, `[YYYY년 MM월 DD일]` 등은 실제 정보로
/// 반드시 교체해야 하는 자리표시자다.
///
/// 정적 법률 문서라 ARB placeholder 치환 방식보다 언어별 긴 본문을 그대로 두는 게
/// 관리하기 쉬워서, l10n 코드생성 대신 이 파일에서 로케일별로 직접 분기한다.
library legal_content;

typedef LegalSection = (String heading, String body);

const _placeholderCompany = '[사업자명/개발자명]';
const _placeholderCompanyEn = '[Business/Developer Name]';
const _placeholderCompanyJa = '[事業者名/開発者名]';
const _placeholderEmail = '[문의 이메일 주소]';
const _placeholderEmailEn = '[contact email address]';
const _placeholderEmailJa = '[問い合わせ用メールアドレス]';
const _placeholderContact = '[성명 또는 담당부서]';
const _placeholderContactEn = '[Name or Department]';
const _placeholderContactJa = '[氏名または担当部署]';
const _placeholderDate = '[YYYY년 MM월 DD일]';
const _placeholderDateEn = '[Month DD, YYYY]';
const _placeholderDateJa = '[YYYY年MM月DD日]';

List<LegalSection> termsOfService(String languageCode) => switch (languageCode) {
      'en' => _termsEn,
      'ja' => _termsJa,
      _ => _termsKo,
    };

List<LegalSection> privacyPolicy(String languageCode) => switch (languageCode) {
      'en' => _privacyEn,
      'ja' => _privacyJa,
      _ => _privacyKo,
    };

final _termsKo = <LegalSection>[
  (
    '제1조 (목적)',
    '이 약관은 $_placeholderCompany("회사")이 제공하는 모바일 애플리케이션 "쉐도잉랩"(이하 "서비스")의 이용과 관련하여 '
        '회사와 이용자 간의 권리, 의무 및 책임사항을 정함을 목적으로 합니다.',
  ),
  (
    '제2조 (서비스의 내용)',
    '서비스는 이용자가 직접 보유한 음성/영상 파일을 업로드하여 문장 단위로 나누고, 반복 청취 및 따라 말하기 방식으로 '
        '어학 학습을 돕는 개인용 학습 도구입니다. 서비스는 이용자가 업로드한 파일의 저작권 적법성을 확인하지 않으며, '
        '그 책임은 전적으로 이용자에게 있습니다.',
  ),
  (
    '제3조 (이용자의 의무)',
    '1. 이용자는 본인이 적법하게 이용 권한을 보유한 파일만 업로드해야 합니다.\n'
        '2. 이용자는 서비스를 개인적, 비상업적 학습 목적으로만 사용해야 하며, 업로드한 콘텐츠를 제3자에게 배포·공유·재판매해서는 안 됩니다.\n'
        '3. 이용자는 관련 법령, 이 약관 및 서비스 관련 공지사항을 준수해야 합니다.',
  ),
  (
    '제4조 (콘텐츠 및 데이터의 저장)',
    '서비스가 처리하는 음성/영상 파일과 학습 기록은 이용자의 기기에만 저장되며, 회사의 서버로 전송되지 않습니다. '
        '회사는 이용자가 업로드한 콘텐츠에 접근하거나 이를 수집하지 않습니다. 앱 삭제 또는 기기 초기화 시 해당 데이터는 '
        '복구할 수 없습니다.',
  ),
  (
    '제5조 (인앱 구매)',
    '1. 서비스는 광고 제거를 위한 일회성 인앱 구매 상품을 제공합니다.\n'
        '2. 결제는 앱스토어/구글플레이 등 각 플랫폼의 결제 시스템을 통해 처리되며, 환불 정책은 각 플랫폼의 정책을 따릅니다.\n'
        '3. 회사는 정당한 사유 없이 임의로 구매를 취소·환불 처리하지 않습니다.',
  ),
  (
    '제6조 (광고)',
    '무료로 서비스를 이용하는 이용자에게는 광고가 표시될 수 있습니다. 광고 제공업체는 자체 정책에 따라 광고 식별자 등 '
        '정보를 처리할 수 있으며, 자세한 내용은 개인정보처리방침을 참고하시기 바랍니다.',
  ),
  (
    '제7조 (서비스 제공의 중단)',
    '회사는 서비스용 설비 보수, 경영상 판단, 기타 불가항력적 사유가 있는 경우 서비스 제공을 일시적으로 중단하거나 '
        '종료할 수 있습니다.',
  ),
  (
    '제8조 (면책조항)',
    '1. 서비스는 "있는 그대로" 제공되며, 회사는 서비스의 정확성·신뢰성·특정 목적 적합성에 대해 명시적·묵시적 보증을 '
        '하지 않습니다.\n'
        '2. 회사는 이용자가 업로드한 콘텐츠의 저작권 침해, 이용자와 제3자 간에 서비스를 매개로 발생한 분쟁에 대해 '
        '책임을 지지 않습니다.\n'
        '3. 회사는 천재지변, 기기 오류, 이용자의 귀책사유로 인한 서비스 이용 장애에 대해 책임을 지지 않습니다.\n'
        '4. 관련 법령이 허용하는 최대한도 내에서, 서비스 관련 회사의 책임은 이용자가 최근 12개월간 실제로 지불한 '
        '금액을 초과하지 않습니다.',
  ),
  (
    '제9조 (약관의 변경)',
    '회사는 관련 법령을 위배하지 않는 범위에서 이 약관을 변경할 수 있으며, 변경된 약관은 앱 내 공지 또는 업데이트를 '
        '통해 효력이 발생합니다.',
  ),
  (
    '제10조 (준거법 및 관할)',
    '이 약관은 대한민국 법령에 따라 해석되며, 서비스 이용과 관련한 분쟁은 민사소송법상의 관할 법원에 제소합니다.',
  ),
  ('제11조 (문의)', '서비스 이용 관련 문의는 $_placeholderEmail 또는 앱스토어/플레이스토어 리뷰를 통해 접수해 주세요.'),
  ('시행일', _placeholderDate),
];

final _privacyKo = <LegalSection>[
  (
    '개요',
    '쉐도잉랩(이하 "서비스")은 이용자의 개인정보를 중요하게 생각하며 「개인정보 보호법」 등 관련 법령을 준수합니다.\n\n'
        '본 개인정보처리방침은 서비스 이용 과정에서 처리되는 정보의 종류, 이용 목적, 보관 및 삭제 방법 등에 관한 사항을 설명합니다.',
  ),
  (
    '1. 이용자가 입력하거나 저장하는 정보',
    '서비스는 별도의 회원가입 또는 로그인 절차를 제공하지 않으며, 회사는 회원가입을 목적으로 이용자의 이름, 이메일 주소, 전화번호 등의 개인정보를 수집하지 않습니다.\n\n'
        '이용자가 학습을 위해 선택하거나 불러오는 다음 정보는 원칙적으로 이용자의 기기 내부에서만 처리됩니다.\n'
        '- 이용자가 선택하거나 불러온 음성 및 영상 파일\n'
        '- 음성·영상 파일의 문장 분리 등 처리 결과\n'
        '- 학습 진행 상태 및 학습 기록\n'
        '- 앱 설정 정보\n\n'
        '위 정보는 회사의 서버로 업로드되거나 저장되지 않으며, 회사는 해당 콘텐츠에 직접 접근할 수 없습니다.\n\n'
        '다만 서비스 제공 과정에서 이용되는 제3자 SDK 및 플랫폼 서비스는 아래에서 설명하는 정보를 별도로 처리할 수 있습니다.',
  ),
  (
    '2. 광고 서비스에서 처리될 수 있는 정보',
    '무료 버전의 서비스에는 광고가 표시될 수 있으며, 이를 위해 Google AdMob 등 제3자 광고 서비스가 사용될 수 있습니다.\n\n'
        '광고 서비스 제공 과정에서 광고 제공업체는 다음과 같은 정보를 자동으로 처리할 수 있습니다.\n'
        '- IP 주소\n'
        '- 광고 식별자(Android Advertising ID 등) 및 기타 기기 또는 앱 식별자\n'
        '- 앱 실행, 광고 노출·클릭 등 서비스 및 광고와의 상호작용 정보\n'
        '- 앱 및 광고 SDK의 오류, 성능 등 진단정보\n'
        '- 그 밖에 광고 제공, 광고 성과 측정 및 부정 이용 방지에 필요한 정보\n\n'
        '이러한 정보의 구체적인 처리 방식은 해당 광고 서비스 제공업체의 개인정보처리방침 및 정책에 따릅니다.\n\n'
        '회사는 이용자가 학습을 위해 불러온 음성·영상 파일 또는 해당 파일의 내용을 광고 제공업체에 제공하지 않습니다.',
  ),
  (
    '3. 인앱 구매와 관련된 정보',
    '서비스는 광고 제거 등을 위한 인앱 구매 기능을 제공할 수 있습니다.\n\n'
        '결제 및 결제수단 정보는 Google Play 등 앱 마켓 사업자가 직접 처리하며, 회사는 이용자의 카드번호, 계좌번호 등 결제수단 정보에 접근하지 않습니다.\n\n'
        '서비스는 구매 여부 확인 및 구매 기능 제공을 위해 앱 마켓이 제공하는 상품 정보, 구매 상태 등 필요한 정보를 처리할 수 있습니다.\n\n'
        '별도의 안내가 없는 한 회사는 이러한 구매 정보를 자체 서버에 별도로 저장하지 않습니다.',
  ),
  (
    '4. 정보의 이용 목적',
    '서비스에서 처리되는 정보는 다음 목적을 위해 사용됩니다.\n'
        '- 음성·영상 파일을 이용한 어학 학습 기능 제공\n'
        '- 학습 진행 상태 및 이용자 설정 저장\n'
        '- 광고 제공 및 광고 성과 측정\n'
        '- 인앱 구매 확인 및 광고 제거 기능 제공\n'
        '- 서비스 안정성 확보 및 부정 이용 방지\n\n'
        '회사는 이용자의 음성·영상 콘텐츠를 광고, 마케팅 또는 별도의 콘텐츠 제작 목적으로 이용하지 않습니다.',
  ),
  (
    '5. 정보의 보관 및 삭제',
    '이용자가 서비스에서 사용하는 음성·영상 파일, 처리 결과 및 학습 기록은 원칙적으로 이용자의 기기에만 저장됩니다.\n\n'
        '이용자는 앱에서 제공하는 삭제 기능을 통해 해당 데이터를 삭제할 수 있습니다.\n\n'
        '앱을 삭제하거나 기기를 초기화하는 경우 기기에 저장된 데이터가 삭제될 수 있으며, 회사는 해당 정보의 별도 사본을 보유하지 않으므로 이를 복구할 수 없습니다.\n\n'
        '광고 제공업체 또는 앱 마켓 사업자가 처리하는 정보의 보관 및 삭제에 대해서는 해당 사업자의 정책이 적용됩니다.',
  ),
  (
    '6. 제3자 서비스 이용',
    '서비스는 다음과 같은 외부 서비스를 이용할 수 있습니다.\n\n'
        'Google AdMob\n'
        '- 목적: 광고 제공, 광고 성과 측정 및 부정 이용 방지\n'
        '- 처리될 수 있는 정보: IP 주소, 광고 및 기기 식별자, 앱 상호작용 정보, 진단정보 등\n\n'
        'Google Play\n'
        '- 목적: 앱 배포 및 인앱 구매 처리\n'
        '- 처리될 수 있는 정보: 구매 및 거래에 필요한 정보\n\n'
        '각 외부 서비스 사업자는 자신의 개인정보처리방침 및 관련 정책에 따라 정보를 처리할 수 있습니다.\n\n'
        '회사는 이용자가 학습을 위해 불러온 음성·영상 파일 또는 해당 파일의 내용을 위 사업자에게 제공하지 않습니다.',
  ),
  (
    '7. 이용자의 권리 및 정보 관리',
    '서비스의 주요 학습 데이터는 이용자의 기기에 저장되므로 이용자는 앱 내 삭제 기능 등을 통해 직접 데이터를 관리할 수 있습니다.\n\n'
        '회사가 별도의 서버에 이용자의 학습 데이터를 보관하지 않는 경우 회사는 해당 데이터를 직접 열람, 수정 또는 삭제할 수 없습니다.\n\n'
        '광고 식별자 등 제3자 서비스가 처리하는 정보는 기기의 개인정보 또는 광고 설정과 해당 서비스 제공업체가 제공하는 방법을 통해 관리할 수 있습니다.',
  ),
  (
    '8. 아동의 개인정보',
    '서비스는 만 14세 미만 아동의 개인정보를 별도로 수집하기 위한 회원가입 또는 계정 기능을 제공하지 않습니다.\n\n'
        '회사는 만 14세 미만 아동으로부터 이름, 연락처 등 개인 식별정보를 의도적으로 수집하지 않습니다.\n\n'
        '다만 서비스의 이용 대상 및 광고 제공 방식에 따라 관련 법령 및 앱 마켓의 아동·가족 관련 정책이 적용되는 경우 해당 정책에 필요한 조치를 적용합니다.',
  ),
  (
    '9. 개인정보의 안전성',
    '회사는 이용자의 음성·영상 파일 및 주요 학습 데이터를 회사 서버로 전송하지 않고 이용자의 기기 내부에서 처리하는 것을 원칙으로 합니다.\n\n'
        '제3자 서비스를 통해 정보가 전송되는 경우 해당 서비스 제공업체의 보안 및 개인정보 보호 정책이 적용됩니다.',
  ),
  (
    '10. 개인정보 보호 문의',
    '개인정보 보호 관련 문의는 아래 연락처로 접수할 수 있습니다.\n\n'
        '서비스명: 쉐도잉랩\n'
        '개발자/사업자: $_placeholderCompany\n'
        '개인정보 보호 담당: $_placeholderContact\n'
        '이메일: $_placeholderEmail',
  ),
  (
    '11. 개인정보처리방침의 변경',
    '본 개인정보처리방침의 내용이 변경되는 경우 앱 내 공지, 앱 업데이트 또는 서비스가 제공하는 기타 적절한 방법을 통해 변경 내용을 안내합니다.\n\n'
        '중요한 변경이 있는 경우 관련 법령이 요구하는 방식에 따라 사전에 안내합니다.',
  ),
  ('시행일', _placeholderDate),
];

final _termsEn = <LegalSection>[
  (
    '1. Purpose',
    'These Terms govern the rights, obligations, and responsibilities between $_placeholderCompanyEn ("we", "us") '
        'and users of the "ShadowingLab" mobile application (the "Service").',
  ),
  (
    '2. Description of Service',
    'The Service is a personal learning tool that splits audio/video files you provide into sentences for repeated '
        'listening and shadowing practice. We do not verify the copyright status of files you upload — that '
        'responsibility rests entirely with you.',
  ),
  (
    '3. User Obligations',
    '1. You must only upload files you have a lawful right to use.\n'
        '2. You must use the Service for personal, non-commercial learning purposes only, and must not distribute, '
        'share, or resell uploaded content to third parties.\n'
        '3. You must comply with applicable law, these Terms, and any notices we post about the Service.',
  ),
  (
    '4. Storage of Content and Data',
    'Audio/video files and study records processed by the Service are stored only on your device and are never '
        'transmitted to our servers. We do not access or collect the content you upload. This data cannot be '
        'recovered once you delete the app or reset your device.',
  ),
  (
    '5. In-App Purchases',
    '1. The Service offers a one-time in-app purchase to remove ads.\n'
        '2. Payments are processed through the App Store/Google Play billing system, and refunds follow that '
        'platform\'s policy.\n'
        '3. We do not arbitrarily cancel or refund purchases without valid cause.',
  ),
  (
    '6. Advertising',
    'Free-tier users may see ads. Ad providers may process device identifiers (such as advertising IDs) under '
        'their own policies — see our Privacy Policy for details.',
  ),
  (
    '7. Service Suspension',
    'We may temporarily suspend or discontinue the Service for maintenance, business reasons, or events beyond '
        'our reasonable control.',
  ),
  (
    '8. Disclaimer',
    '1. The Service is provided "as is," without warranties of accuracy, reliability, or fitness for a particular '
        'purpose, express or implied.\n'
        '2. We are not liable for copyright infringement in content you upload, or disputes between you and third '
        'parties arising from use of the Service.\n'
        '3. We are not liable for service interruptions caused by force majeure, device failure, or your own '
        'actions.\n'
        '4. To the maximum extent permitted by law, our total liability relating to the Service will not exceed '
        'the amount you actually paid in the preceding 12 months.',
  ),
  (
    '9. Changes to These Terms',
    'We may amend these Terms without violating applicable law; amended Terms take effect via an in-app notice '
        'or update.',
  ),
  ('10. Governing Law', 'These Terms are governed by the laws of the Republic of Korea.'),
  ('11. Contact', 'For questions about the Service, contact $_placeholderEmailEn or leave a Store review.'),
  ('Effective Date', _placeholderDateEn),
];

final _privacyEn = <LegalSection>[
  (
    'Overview',
    'ShadowingLab ("the Service") takes user privacy seriously and complies with applicable personal data '
        'protection laws.\n\n'
        'This Privacy Policy explains the types of information processed while using the Service, the purposes of '
        'use, and how it is stored and deleted.',
  ),
  (
    '1. Information You Provide or Store',
    'The Service does not offer account registration or login, and we do not collect personal information such as '
        'your name, email address, or phone number for account purposes.\n\n'
        'The following information you select or import for study is, in principle, processed only on your '
        'device:\n'
        '- Audio and video files you select or import\n'
        '- Results of processing those files (e.g., sentence splitting)\n'
        '- Study progress and study history\n'
        '- App settings\n\n'
        'This information is never uploaded to or stored on our servers, and we cannot directly access this '
        'content.\n\n'
        'However, third-party SDKs and platform services used to provide the Service may separately process the '
        'information described below.',
  ),
  (
    '2. Information Ad Services May Process',
    'The free version of the Service may display ads, which may use third-party ad services such as Google '
        'AdMob.\n\n'
        'In the course of providing ads, the ad provider may automatically process the following information:\n'
        '- IP address\n'
        '- Advertising identifiers (e.g., Android Advertising ID) and other device or app identifiers\n'
        '- App launches, ad impressions/clicks, and other interactions with the Service and ads\n'
        '- Diagnostic information such as app and ad SDK errors and performance\n'
        '- Other information necessary for ad delivery, ad performance measurement, and fraud prevention\n\n'
        'The specific handling of this information is governed by the relevant ad provider\'s own privacy '
        'policy.\n\n'
        'We do not provide the audio/video files you import for study, or their contents, to ad providers.',
  ),
  (
    '3. In-App Purchase Information',
    'The Service may offer an in-app purchase to remove ads.\n\n'
        'Payment and payment-method information is processed directly by the app marketplace operator (e.g., '
        'Google Play); we never access your card or account details.\n\n'
        'The Service may process product information and purchase status provided by the app marketplace as '
        'needed to verify purchases and provide purchase features.\n\n'
        'Unless otherwise stated, we do not separately store this purchase information on our own servers.',
  ),
  (
    '4. Purpose of Use',
    'Information processed by the Service is used for the following purposes:\n'
        '- Providing language-learning features using audio/video files\n'
        '- Saving study progress and user settings\n'
        '- Serving ads and measuring ad performance\n'
        '- Verifying in-app purchases and providing the ad-removal feature\n'
        '- Maintaining service stability and preventing fraudulent use\n\n'
        'We do not use your audio/video content for advertising, marketing, or separate content production '
        'purposes.',
  ),
  (
    '5. Retention and Deletion',
    'Audio/video files, processing results, and study history you use in the Service are, in principle, stored '
        'only on your device.\n\n'
        'You can delete this data using the delete feature provided in the app.\n\n'
        'Deleting the app or resetting your device may delete data stored on the device; we keep no separate '
        'copy, so it cannot be recovered.\n\n'
        'Retention and deletion of information processed by ad providers or the app marketplace operator are '
        'governed by their own policies.',
  ),
  (
    '6. Use of Third-Party Services',
    'The Service may use the following external services:\n\n'
        'Google AdMob\n'
        '- Purpose: ad delivery, ad performance measurement, fraud prevention\n'
        '- Information that may be processed: IP address, advertising/device identifiers, app interaction '
        'information, diagnostics, etc.\n\n'
        'Google Play\n'
        '- Purpose: app distribution and in-app purchase processing\n'
        '- Information that may be processed: information necessary for purchases and transactions\n\n'
        'Each external provider may process information under its own privacy policy and related terms.\n\n'
        'We do not provide the audio/video files you import for study, or their contents, to the providers above.',
  ),
  (
    '7. Your Rights and Control Over Information',
    'Because the Service\'s core study data is stored on your device, you can manage it directly via the in-app '
        'delete feature and similar controls.\n\n'
        'If we do not retain your study data on a separate server, we are unable to directly view, modify, or '
        'delete that data ourselves.\n\n'
        'Information processed by third-party services, such as advertising identifiers, can be managed through '
        'your device\'s privacy/ad settings or methods provided by the relevant service provider.',
  ),
  (
    '8. Children\'s Privacy',
    'The Service does not provide account registration or login features intended to separately collect personal '
        'information from children under 14.\n\n'
        'We do not knowingly collect personal identifiers such as name or contact information from children under '
        '14.\n\n'
        'Where applicable law or an app marketplace\'s child/family policy applies based on the Service\'s '
        'intended audience and ad delivery methods, we take the measures required by that policy.',
  ),
  (
    '9. Security of Information',
    'As a matter of principle, we process your audio/video files and core study data on your device rather than '
        'transmitting them to our servers.\n\n'
        'Where information is transmitted through a third-party service, that provider\'s own security and '
        'privacy policies apply.',
  ),
  (
    '10. Privacy Contact',
    'Privacy-related inquiries can be directed to the contact below.\n\n'
        'Service name: ShadowingLab\n'
        'Developer/Business: $_placeholderCompanyEn\n'
        'Privacy contact: $_placeholderContactEn\n'
        'Email: $_placeholderEmailEn',
  ),
  (
    '11. Changes to This Policy',
    'If the content of this Privacy Policy changes, we will announce the changes via an in-app notice, app '
        'update, or other appropriate method provided by the Service.\n\n'
        'For material changes, we will provide advance notice in the manner required by applicable law.',
  ),
  ('Effective Date', _placeholderDateEn),
];

final _termsJa = <LegalSection>[
  (
    '第1条（目的）',
    '本規約は、$_placeholderCompanyJa（以下「当社」）が提供するモバイルアプリケーション「シャドーイングラボ」'
        '（以下「本サービス」）の利用に関して、当社と利用者の権利義務および責任事項を定めることを目的とします。',
  ),
  (
    '第2条（サービスの内容）',
    '本サービスは、利用者が自ら保有する音声/動画ファイルをアップロードして文単位に分割し、繰り返し再生とシャドーイングで '
        '語学学習を支援する個人向け学習ツールです。当社はアップロードされたファイルの著作権の適法性を確認せず、その '
        '責任はすべて利用者にあります。',
  ),
  (
    '第3条（利用者の義務）',
    '1. 利用者は自らが適法に利用権限を有するファイルのみアップロードしなければなりません。\n'
        '2. 利用者は本サービスを個人的・非商業的な学習目的でのみ使用し、アップロードしたコンテンツを第三者に配布・共有・'
        '再販してはなりません。\n'
        '3. 利用者は関連法令、本規約およびサービスに関する告知事項を遵守しなければなりません。',
  ),
  (
    '第4条（コンテンツおよびデータの保存）',
    '本サービスが処理する音声/動画ファイルおよび学習記録は利用者の端末にのみ保存され、当社のサーバーには送信されません。 '
        '当社は利用者がアップロードしたコンテンツにアクセスまたは収集しません。アプリ削除や端末初期化後、当該データは '
        '復元できません。',
  ),
  (
    '第5条（アプリ内課金）',
    '1. 本サービスは広告削除のための一回限りのアプリ内課金商品を提供します。\n'
        '2. 決済はApp Store/Google Playなど各プラットフォームの決済システムを通じて処理され、返金ポリシーは各 '
        'プラットフォームのポリシーに従います。\n'
        '3. 当社は正当な理由なく購入を任意にキャンセル・返金しません。',
  ),
  (
    '第6条（広告）',
    '無料で本サービスを利用する利用者には広告が表示される場合があります。広告提供事業者は自社ポリシーに従い広告識別子 '
        'などの情報を処理する場合があります。詳細はプライバシーポリシーをご確認ください。',
  ),
  (
    '第7条（サービス提供の中断）',
    '当社は設備の保守、経営上の判断、その他不可抗力事由がある場合、サービス提供を一時的に中断または終了することが '
        'あります。',
  ),
  (
    '第8条（免責事項）',
    '1. 本サービスは「現状有姿」で提供され、当社は正確性・信頼性・特定目的への適合性について明示または黙示の保証を '
        'しません。\n'
        '2. 当社は利用者がアップロードしたコンテンツの著作権侵害、利用者と第三者間で本サービスを介して生じた紛争に '
        'ついて責任を負いません。\n'
        '3. 当社は天災、端末の不具合、利用者の帰責事由によるサービス利用障害について責任を負いません。\n'
        '4. 関連法令が許す最大限の範囲で、本サービスに関する当社の責任は利用者が直近12か月間に実際に支払った金額を '
        '超えないものとします。',
  ),
  ('第9条（規約の変更）', '当社は関連法令に反しない範囲で本規約を変更でき、変更後の規約はアプリ内告知またはアップデートにより効力を生じます。'),
  ('第10条（準拠法および管轄）', '本規約は大韓民国の法令に従って解釈され、本サービスに関する紛争は民事訴訟法上の管轄裁判所に提訴します。'),
  ('第11条（お問い合わせ）', '本サービスに関するお問い合わせは$_placeholderEmailJaまたはストアレビューまでご連絡ください。'),
  ('施行日', _placeholderDateJa),
];

final _privacyJa = <LegalSection>[
  (
    '概要',
    'シャドーイングラボ（以下「本サービス」）は利用者のプライバシーを重視し、「個人情報保護法」等関連法令を遵守します。\n\n'
        '本プライバシーポリシーは、本サービスの利用過程で処理される情報の種類、利用目的、保管および削除方法等について説明します。',
  ),
  (
    '1. 利用者が入力・保存する情報',
    '本サービスは会員登録またはログイン機能を提供しておらず、当社は会員登録を目的として氏名、メールアドレス、電話番号等の個人情報を収集しません。\n\n'
        '利用者が学習のために選択・読み込む以下の情報は、原則として利用者の端末内でのみ処理されます。\n'
        '- 利用者が選択・読み込んだ音声および動画ファイル\n'
        '- 音声・動画ファイルの文分割等の処理結果\n'
        '- 学習進捗状況および学習記録\n'
        '- アプリ設定情報\n\n'
        '上記情報は当社のサーバーにアップロードまたは保存されず、当社は当該コンテンツに直接アクセスできません。\n\n'
        'ただし、本サービスの提供過程で利用される第三者SDKおよびプラットフォームサービスは、以下で説明する情報を別途処理する場合があります。',
  ),
  (
    '2. 広告サービスにより処理される可能性がある情報',
    '無料版の本サービスには広告が表示される場合があり、これにはGoogle AdMob等の第三者広告サービスが使用される場合があります。\n\n'
        '広告サービスの提供過程で、広告提供事業者は次のような情報を自動的に処理する場合があります。\n'
        '- IPアドレス\n'
        '- 広告識別子（Android Advertising ID等）およびその他の端末またはアプリ識別子\n'
        '- アプリ起動、広告表示・クリック等、本サービスおよび広告との相互作用情報\n'
        '- アプリおよび広告SDKのエラー、パフォーマンス等の診断情報\n'
        '- その他広告提供、広告効果測定および不正利用防止に必要な情報\n\n'
        'これらの情報の具体的な処理方法は、当該広告サービス提供事業者のプライバシーポリシーおよびポリシーに従います。\n\n'
        '当社は、利用者が学習のために読み込んだ音声・動画ファイルまたはその内容を広告提供事業者に提供しません。',
  ),
  (
    '3. アプリ内課金に関する情報',
    '本サービスは広告削除等のためのアプリ内課金機能を提供する場合があります。\n\n'
        '決済および決済手段情報はGoogle Play等アプリマーケット事業者が直接処理し、当社は利用者のカード番号、口座番号等の決済手段情報にアクセスしません。\n\n'
        '本サービスは購入確認および購入機能提供のため、アプリマーケットが提供する商品情報、購入状態等必要な情報を処理する場合があります。\n\n'
        '別途案内がない限り、当社はこれらの購入情報を自社サーバーに別途保存しません。',
  ),
  (
    '4. 情報の利用目的',
    '本サービスで処理される情報は次の目的で使用されます。\n'
        '- 音声・動画ファイルを利用した語学学習機能の提供\n'
        '- 学習進捗状況および利用者設定の保存\n'
        '- 広告提供および広告効果測定\n'
        '- アプリ内課金の確認および広告削除機能の提供\n'
        '- サービスの安定性確保および不正利用防止\n\n'
        '当社は利用者の音声・動画コンテンツを広告、マーケティングまたは別途のコンテンツ制作目的で利用しません。',
  ),
  (
    '5. 情報の保管および削除',
    '利用者が本サービスで使用する音声・動画ファイル、処理結果および学習記録は、原則として利用者の端末にのみ保存されます。\n\n'
        '利用者はアプリが提供する削除機能を通じて当該データを削除できます。\n\n'
        'アプリを削除するか端末を初期化する場合、端末に保存されたデータが削除される場合があり、当社は当該情報の別途複製を保有しないため、これを復元することはできません。\n\n'
        '広告提供事業者またはアプリマーケット事業者が処理する情報の保管および削除については、当該事業者のポリシーが適用されます。',
  ),
  (
    '6. 第三者サービスの利用',
    '本サービスは次のような外部サービスを利用する場合があります。\n\n'
        'Google AdMob\n'
        '- 目的：広告提供、広告効果測定および不正利用防止\n'
        '- 処理される可能性がある情報：IPアドレス、広告・端末識別子、アプリ相互作用情報、診断情報等\n\n'
        'Google Play\n'
        '- 目的：アプリ配信およびアプリ内課金処理\n'
        '- 処理される可能性がある情報：購入および取引に必要な情報\n\n'
        '各外部サービス事業者は自社のプライバシーポリシーおよび関連ポリシーに従い情報を処理する場合があります。\n\n'
        '当社は、利用者が学習のために読み込んだ音声・動画ファイルまたはその内容を上記事業者に提供しません。',
  ),
  (
    '7. 利用者の権利および情報管理',
    '本サービスの主要な学習データは利用者の端末に保存されるため、利用者はアプリ内削除機能等を通じて直接データを管理できます。\n\n'
        '当社が別途サーバーに利用者の学習データを保管しない場合、当社は当該データを直接閲覧、修正または削除することはできません。\n\n'
        '広告識別子等、第三者サービスが処理する情報は、端末のプライバシーまたは広告設定および当該サービス提供事業者が提供する方法を通じて管理できます。',
  ),
  (
    '8. 児童のプライバシー',
    '本サービスは満14歳未満の児童の個人情報を別途収集するための会員登録またはアカウント機能を提供しません。\n\n'
        '当社は満14歳未満の児童から氏名、連絡先等の個人識別情報を意図的に収集しません。\n\n'
        'ただし、本サービスの利用対象および広告提供方式により関連法令やアプリマーケットの児童・家族関連ポリシーが適用される場合、当該ポリシーに必要な措置を適用します。',
  ),
  (
    '9. 情報の安全性',
    '当社は利用者の音声・動画ファイルおよび主要な学習データを当社サーバーに送信せず、利用者の端末内で処理することを原則とします。\n\n'
        '第三者サービスを通じて情報が送信される場合、当該サービス提供事業者のセキュリティおよびプライバシー保護ポリシーが適用されます。',
  ),
  (
    '10. 個人情報保護に関するお問い合わせ',
    '個人情報保護に関するお問い合わせは以下の連絡先までご連絡ください。\n\n'
        'サービス名：シャドーイングラボ\n'
        '開発者/事業者：$_placeholderCompanyJa\n'
        '個人情報保護担当：$_placeholderContactJa\n'
        'メール：$_placeholderEmailJa',
  ),
  (
    '11. プライバシーポリシーの変更',
    '本プライバシーポリシーの内容が変更される場合、アプリ内告知、アプリアップデートまたは本サービスが提供するその他適切な方法を通じて変更内容を案内します。\n\n'
        '重要な変更がある場合、関連法令が要求する方式に従い事前に案内します。',
  ),
  ('施行日', _placeholderDateJa),
];
