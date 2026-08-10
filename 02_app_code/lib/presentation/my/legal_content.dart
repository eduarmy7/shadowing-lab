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
    '쉐도잉랩("서비스")은 이용자의 개인정보를 중요하게 생각하며 관련 법령을 준수합니다. 본 개인정보처리방침은 '
        '서비스가 어떤 정보를 어떻게 처리하는지 설명합니다.',
  ),
  (
    '1. 수집하는 정보',
    '서비스는 회원가입·로그인 절차가 없으며, 이름·이메일 등 개인 식별정보를 수집하지 않습니다. 이용자가 업로드하는 '
        '음성/영상 파일, 문장 분리 결과, 학습 진행 기록은 모두 이용자의 기기 내부에만 저장되며, 회사의 서버로 '
        '전송되지 않습니다.',
  ),
  (
    '2. 자동으로 수집되는 정보',
    '서비스 자체는 별도의 분석(Analytics) 도구를 사용하지 않습니다. 다만 광고가 표시되는 화면에서는 광고 '
        '제공업체가 광고 식별자(예: Android Advertising ID, IDFA) 등 기기 식별 정보를 자체적으로 처리할 수 있으며, '
        '이는 각 광고 네트워크의 개인정보처리방침이 별도로 적용됩니다.',
  ),
  (
    '3. 인앱 구매 정보',
    '"광고 제거" 구매 시 결제 정보는 Apple/Google 등 각 플랫폼이 직접 처리하며, 회사는 카드번호 등 결제 수단 '
        '정보에 접근하지 않습니다. 회사가 보유하는 정보는 구매 완료 여부(예/아니오)뿐입니다.',
  ),
  (
    '4. 정보의 보관 및 삭제',
    '모든 학습 데이터는 이용자의 기기에만 저장됩니다. 앱을 삭제하거나 앱 내 삭제 기능을 사용하면 해당 데이터는 '
        '즉시 영구적으로 삭제되며, 회사가 별도로 보관하는 사본은 없습니다.',
  ),
  (
    '5. 제3자 제공',
    '회사는 이용자의 정보를 제3자에게 판매하거나 제공하지 않습니다. 다만 광고 SDK, 앱스토어 결제 시스템 등 서비스 '
        '운영에 필수적인 제3자 서비스는 각자의 개인정보처리방침에 따라 별도로 정보를 처리할 수 있습니다.',
  ),
  (
    '6. 아동의 개인정보',
    '서비스는 만 14세 미만 아동을 주 대상으로 하지 않으며, 개인 식별정보를 별도로 수집하지 않으므로 아동으로부터 '
        '개인정보를 의도적으로 수집하지 않습니다.',
  ),
  (
    '7. 이용자의 권리',
    '서비스는 서버에 개인정보를 저장하지 않으므로, 별도의 열람·정정·삭제 요청 없이도 이용자는 앱 내 삭제 기능이나 '
        '앱 삭제를 통해 언제든지 본인의 모든 데이터를 완전히 삭제할 수 있습니다.',
  ),
  ('8. 개인정보처리방침의 변경', '이 방침이 변경되는 경우 앱 내 공지 또는 업데이트를 통해 안내합니다.'),
  ('9. 문의', '개인정보 관련 문의사항은 $_placeholderEmail로 연락해 주세요.'),
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
    'ShadowingLab (the "Service") takes your privacy seriously and complies with applicable law. This Privacy '
        'Policy explains what information the Service processes and how.',
  ),
  (
    '1. Information We Collect',
    'The Service has no account or login system and does not collect personal identifiers such as your name or '
        'email. Audio/video files, sentence-splitting results, and study progress you create are stored only on '
        'your device and are never transmitted to our servers.',
  ),
  (
    '2. Automatically Collected Information',
    'The Service itself does not use any analytics tool. On screens where ads are shown, ad providers may process '
        'device identifiers (e.g., Android Advertising ID, IDFA) under their own privacy policies.',
  ),
  (
    '3. In-App Purchase Information',
    'Payment for "Remove Ads" is processed directly by Apple/Google; we never have access to your card details. '
        'We only retain whether the purchase was completed (yes/no).',
  ),
  (
    '4. Data Retention and Deletion',
    'All study data lives only on your device. Deleting the app or using the in-app delete feature permanently '
        'removes that data immediately — we keep no separate copy.',
  ),
  (
    '5. Third-Party Sharing',
    'We do not sell or share your information with third parties. Third-party services essential to running the '
        'app (ad SDKs, store billing) may separately process information under their own privacy policies.',
  ),
  (
    '6. Children\'s Privacy',
    'The Service is not directed at children under 14 and does not knowingly collect personal information from '
        'children, since it does not collect personal identifiers from anyone.',
  ),
  (
    '7. Your Rights',
    'Because the Service stores no personal data on any server, you can fully delete all your data at any time '
        'via the in-app delete feature or by uninstalling the app — no separate access/correction/deletion request '
        'is needed.',
  ),
  ('8. Changes to This Policy', 'Any changes will be announced via an in-app notice or update.'),
  ('9. Contact', 'For privacy questions, contact $_placeholderEmailEn.'),
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
    'シャドーイングラボ（以下「本サービス」）は利用者のプライバシーを重視し、関連法令を遵守します。本プライバシー '
        'ポリシーは、本サービスがどのような情報をどのように処理するかを説明します。',
  ),
  (
    '1. 収集する情報',
    '本サービスには会員登録・ログイン機能がなく、氏名・メールアドレスなどの個人識別情報を収集しません。利用者が '
        'アップロードする音声/動画ファイル、文分割結果、学習進捗はすべて利用者の端末内にのみ保存され、当社のサーバーには '
        '送信されません。',
  ),
  (
    '2. 自動的に収集される情報',
    '本サービス自体は解析（アナリティクス）ツールを使用しません。ただし広告が表示される画面では、広告提供事業者が '
        '広告識別子（例：Android Advertising ID、IDFA）などの端末識別情報を自社ポリシーに基づき処理する場合があります。',
  ),
  (
    '3. アプリ内課金情報',
    '「広告削除」購入時の決済情報はApple/Googleなど各プラットフォームが直接処理し、当社はカード番号などの決済手段 '
        '情報にアクセスしません。当社が保持する情報は購入完了の有無（はい/いいえ）のみです。',
  ),
  (
    '4. 情報の保管および削除',
    'すべての学習データは利用者の端末にのみ保存されます。アプリを削除するかアプリ内削除機能を使用すると、当該データは '
        '直ちに完全に削除され、当社が別途保管する複製はありません。',
  ),
  (
    '5. 第三者への提供',
    '当社は利用者の情報を第三者に販売または提供しません。ただし、広告SDKやストア決済システムなどサービス運営に '
        '不可欠な第三者サービスは、各自のプライバシーポリシーに従い別途情報を処理する場合があります。',
  ),
  (
    '6. 児童のプライバシー',
    '本サービスは満14歳未満の児童を主な対象としておらず、個人識別情報自体を収集しないため、児童から個人情報を '
        '意図的に収集することはありません。',
  ),
  (
    '7. 利用者の権利',
    '本サービスはサーバーに個人情報を保存しないため、別途の閲覧・訂正・削除請求なしに、利用者はアプリ内削除機能や '
        'アプリ削除によりいつでも自身の全データを完全に削除できます。',
  ),
  ('8. プライバシーポリシーの変更', '本ポリシーが変更される場合、アプリ内告知またはアップデートにより案内します。'),
  ('9. お問い合わせ', '個人情報に関するお問い合わせは$_placeholderEmailJaまでご連絡ください。'),
  ('施行日', _placeholderDateJa),
];
