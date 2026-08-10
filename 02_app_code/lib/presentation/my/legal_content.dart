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
    '이 약관은 $_placeholderCompany(이하 "회사")이 제공하는 모바일 애플리케이션 "쉐도잉랩"(이하 "서비스")의 이용과 '
        '관련하여 회사와 이용자 간의 권리, 의무 및 책임사항을 정함을 목적으로 합니다.',
  ),
  (
    '제2조 (서비스의 내용)',
    '1. 서비스는 이용자가 자신의 기기에 보유하거나 적법하게 접근할 수 있는 음성 또는 영상 파일을 선택하거나 불러와 '
        '문장 단위로 나누고, 반복 청취 및 따라 말하기 등의 방식으로 어학 학습을 할 수 있도록 지원하는 개인용 학습 '
        '도구입니다.\n'
        '2. 이용자가 선택하거나 불러온 음성·영상 파일, 문장 분리 결과 및 학습 과정에서 생성되는 데이터는 모두 '
        '이용자의 기기 내부에서만 처리됩니다.\n'
        '3. 회사는 이용자가 선택하거나 불러온 음성·영상 파일 및 그 내용을 회사의 서버 또는 외부 서버로 전송하거나 '
        '저장하지 않으며, 문장 분리 및 학습 처리를 위하여 외부 API를 사용하지 않습니다.\n'
        '4. 회사는 이용자가 선택하거나 불러온 콘텐츠에 직접 접근하지 않으며, 해당 콘텐츠의 저작권 또는 기타 '
        '권리관계를 확인하지 않습니다.\n'
        '5. 이용자는 자신이 해당 콘텐츠를 이용할 적법한 권한을 보유하거나 관련 법령에 따라 이용이 허용되는 범위에서 '
        '서비스를 이용하여야 합니다.',
  ),
  (
    '제3조 (이용자의 의무)',
    '1. 이용자는 저작권, 초상권, 개인정보 기타 제3자의 권리를 침해하는 방식으로 서비스를 이용해서는 안 됩니다.\n'
        '2. 이용자는 서비스를 개인적인 학습 목적으로 이용하여야 하며, 타인의 콘텐츠를 관련 법령 또는 권리자의 허락 '
        '없이 제3자에게 배포·공유·판매·재판매하거나 공개해서는 안 됩니다.\n'
        '3. 이용자는 관련 법령, 본 약관 및 서비스와 관련하여 회사가 적법하게 안내하는 사항을 준수하여야 합니다.\n'
        '4. 이용자는 서비스의 정상적인 운영을 방해하거나 앱의 보안 또는 기술적 보호조치를 부당하게 우회·변조하는 '
        '행위를 해서는 안 됩니다.\n'
        '5. 이용자가 본 조를 위반하여 제3자의 권리를 침해한 경우 그로 인하여 발생하는 문제는 이용자와 해당 권리자 '
        '사이에서 해결하여야 합니다. 다만 회사에 귀책사유가 있는 경우에는 관련 법령에 따라 회사가 책임을 부담합니다.',
  ),
  (
    '제4조 (콘텐츠 및 학습 데이터의 저장)',
    '1. 서비스에서 이용되는 음성·영상 파일, 문장 분리 결과, 학습 진행 상태 및 학습 기록은 이용자의 기기 내부에서만 '
        '처리되고 저장됩니다.\n'
        '2. 회사는 제1항의 콘텐츠 및 학습 데이터를 수집하거나 회사의 서버 또는 외부 서버로 전송·저장하지 않습니다.\n'
        '3. 회사는 이용자의 음성·영상 콘텐츠 및 해당 콘텐츠에서 생성된 문장 분리 결과에 접근할 수 없습니다.\n'
        '4. 앱 삭제, 앱 데이터 삭제, 기기 초기화, 기기의 분실·고장 또는 기타 기기 환경의 변화로 저장된 데이터가 '
        '삭제된 경우 회사는 해당 데이터를 복구할 수 없습니다.\n'
        '5. 광고 또는 인앱 구매 기능을 제공하기 위하여 이용되는 제3자 서비스에서 처리하는 정보는 이용자의 학습 '
        '콘텐츠와 별개이며, 이에 관한 자세한 사항은 개인정보처리방침에서 확인할 수 있습니다.',
  ),
  (
    '제5조 (인앱 구매)',
    '1. 서비스는 광고 제거 등 특정 기능을 제공하기 위한 일회성 인앱 구매 상품을 제공할 수 있습니다.\n'
        '2. 인앱 구매의 결제는 Google Play 등 해당 앱 마켓의 결제 시스템을 통하여 처리됩니다.\n'
        '3. 회사는 이용자의 카드번호, 계좌번호 등 결제수단 정보를 직접 수집하거나 저장하지 않습니다.\n'
        '4. 서비스는 구매 상품의 정상적인 제공을 위하여 해당 앱 마켓이 제공하는 구매 여부 및 구매 상태에 관한 '
        '정보를 확인할 수 있습니다.\n'
        '5. 청약철회 및 환불은 관련 법령과 해당 앱 마켓의 정책에 따라 처리됩니다. 앱 마켓의 정책 또는 본 약관이 '
        '관련 법령에 따라 이용자에게 보장되는 권리를 제한하는 경우에는 관련 법령이 우선 적용됩니다.',
  ),
  (
    '제6조 (광고)',
    '1. 서비스를 무료로 이용하는 이용자에게는 광고가 표시될 수 있습니다.\n'
        '2. 광고 제공을 위하여 Google AdMob 등 제3자 광고 서비스가 사용될 수 있습니다.\n'
        '3. 광고 서비스 제공 과정에서 광고 제공업체는 광고 식별자, 기기 또는 앱 관련 정보, 광고와의 상호작용 정보 '
        '등을 자체 정책에 따라 처리할 수 있습니다. 이에 관한 자세한 사항은 개인정보처리방침에서 확인할 수 있습니다.\n'
        '4. 회사는 이용자가 학습을 위하여 선택하거나 불러온 음성·영상 파일, 해당 콘텐츠의 내용 또는 문장 분리 결과를 '
        '광고 제공업체에 제공하지 않습니다.\n'
        '5. 광고 제거 상품을 구매한 이용자에게는 해당 구매 조건에 따라 서비스 내 광고가 표시되지 않습니다.',
  ),
  (
    '제7조 (서비스의 변경·중단 및 종료)',
    '1. 회사는 다음 각 호의 사유가 있는 경우 서비스의 전부 또는 일부를 변경하거나 일시적으로 중단할 수 있습니다.\n'
        '   - 서비스의 점검, 유지보수 또는 기술적 변경이 필요한 경우\n'
        '   - 운영체제, 앱 마켓 또는 제3자 서비스의 변경으로 서비스 유지가 어려운 경우\n'
        '   - 관련 법령 또는 정책의 변경이 있는 경우\n'
        '   - 보안상 문제가 발생하거나 발생할 우려가 있는 경우\n'
        '   - 그 밖에 서비스 운영상 합리적으로 필요한 사유가 있는 경우\n'
        '2. 회사는 기술적·운영상 또는 경영상의 합리적인 사유로 서비스를 지속하기 어려운 경우 서비스의 전부 또는 '
        '일부를 종료할 수 있습니다.\n'
        '3. 이용자에게 중대한 영향을 미치는 서비스의 변경 또는 종료가 예정된 경우 회사는 가능한 범위에서 사전에 앱 '
        '내 공지 또는 기타 적절한 방법을 통하여 안내합니다.\n'
        '4. 긴급한 장애, 보안 문제, 천재지변 기타 사전에 안내하기 어려운 사유가 있는 경우에는 사후에 안내할 수 '
        '있습니다.\n'
        '5. 서비스의 변경·중단 또는 종료로 이용자에게 법령상 환불이나 기타 권리가 발생하는 경우에는 관련 법령에 '
        '따라 처리합니다.',
  ),
  (
    '제8조 (서비스 및 콘텐츠에 관한 권리)',
    '1. 서비스의 프로그램, 소프트웨어, 디자인, UI, 로고, 상표 및 회사가 직접 제작한 콘텐츠 등에 대한 저작권 및 '
        '기타 지식재산권은 회사 또는 정당한 권리자에게 귀속됩니다.\n'
        '2. 이용자가 자신의 기기에서 선택하거나 불러오는 음성·영상 파일 및 그 콘텐츠에 대한 권리는 해당 이용자 또는 '
        '기존의 정당한 권리자에게 귀속됩니다.\n'
        '3. 이용자가 서비스를 이용한다는 이유만으로 회사가 이용자의 음성·영상 콘텐츠에 대한 소유권, 저작권 기타 '
        '권리를 취득하는 것은 아닙니다.\n'
        '4. 회사는 이용자가 선택하거나 불러온 콘텐츠를 회사의 광고, 마케팅, 데이터 분석, 인공지능 학습 또는 별도의 '
        '콘텐츠 제작 목적으로 이용하지 않습니다.',
  ),
  (
    '제9조 (책임 및 면책)',
    '1. 서비스의 문장 분리, 재생 위치, 음성·영상 처리 결과 및 기타 학습 기능은 파일의 형식이나 품질, 이용자의 기기 '
        '성능 및 운영환경 등에 따라 차이가 발생할 수 있습니다.\n'
        '2. 회사는 관련 법령이 허용하는 범위에서 서비스가 항상 중단 또는 오류 없이 제공되거나 특정한 학습 효과 또는 '
        '결과를 보장한다고 보증하지 않습니다.\n'
        '3. 이용자가 관련 법령 또는 본 약관을 위반하여 콘텐츠를 이용함으로써 저작권자 등 제3자와 분쟁이 발생한 '
        '경우 회사에 고의 또는 과실 등 귀책사유가 없는 한 회사는 해당 분쟁으로 인한 책임을 부담하지 않습니다.\n'
        '4. 천재지변, 이용자의 기기 또는 운영체제 문제, 이용자의 귀책사유, 통신 장애, 앱 마켓 또는 광고 서비스 등 '
        '회사가 합리적으로 통제하기 어려운 제3자 서비스의 장애 등 회사에 귀책사유가 없는 사유로 발생한 손해에 '
        '대하여 회사는 책임을 부담하지 않습니다.\n'
        '5. 이용자가 기기 내에 저장된 콘텐츠나 학습 데이터를 별도로 백업하지 않아 발생한 데이터 손실에 대해서는 '
        '회사에 귀책사유가 없는 한 회사가 책임을 부담하지 않습니다.\n'
        '6. 회사의 고의 또는 과실로 인하여 이용자에게 손해가 발생한 경우 회사는 관련 법령에 따라 책임을 부담합니다.\n'
        '7. 본 약관의 어떠한 내용도 회사의 고의 또는 중대한 과실에 따른 법률상 책임이나 관련 법령에 따라 제한할 수 '
        '없는 이용자의 권리를 배제하거나 제한하는 것으로 해석되지 않습니다.',
  ),
  (
    '제10조 (약관의 변경)',
    '1. 회사는 관련 법령을 위반하지 않는 범위에서 본 약관을 변경할 수 있습니다.\n'
        '2. 회사가 약관을 변경하는 경우 변경되는 내용, 변경 사유 및 적용일을 명시하여 원칙적으로 적용일 7일 '
        '전부터 앱 내 공지 또는 회사가 제공하는 기타 적절한 방법을 통하여 안내합니다.\n'
        '3. 이용자에게 불리하거나 이용자의 권리·의무에 중대한 영향을 미치는 내용으로 약관을 변경하는 경우에는 '
        '원칙적으로 적용일 30일 전부터 안내합니다.\n'
        '4. 관련 법령에서 약관 변경에 대하여 별도의 절차 또는 더 긴 통지기간을 요구하는 경우에는 해당 법령에 '
        '따릅니다.\n'
        '5. 변경된 약관은 안내된 적용일부터 효력이 발생합니다.',
  ),
  (
    '제11조 (준거법 및 분쟁 해결)',
    '1. 본 약관은 대한민국 법령에 따라 해석되고 적용됩니다.\n'
        '2. 회사와 이용자 사이에 서비스 이용과 관련하여 분쟁이 발생한 경우 회사와 이용자는 원만한 해결을 위하여 '
        '성실히 협의할 수 있습니다.\n'
        '3. 협의로 분쟁이 해결되지 않는 경우 민사소송법 등 관련 법령에 따른 관할 법원에 소를 제기할 수 있습니다.',
  ),
  (
    '제12조 (문의)',
    '서비스 이용 및 본 약관과 관련한 문의는 아래 연락처를 통하여 접수할 수 있습니다.\n\n'
        '서비스명: 쉐도잉랩\n'
        '사업자/개발자명: $_placeholderCompany\n'
        '문의 이메일: $_placeholderEmail',
  ),
  ('부칙', '본 약관은 $_placeholderDate부터 시행합니다.'),
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
    'Article 1 (Purpose)',
    'These Terms govern the rights, obligations, and responsibilities between $_placeholderCompanyEn (the '
        '"Company") and users of the "ShadowingLab" mobile application (the "Service").',
  ),
  (
    'Article 2 (Description of the Service)',
    '1. The Service is a personal learning tool that lets you select or import audio or video files you own or '
        'can lawfully access on your device, split them into sentences, and study through repeated listening and '
        'shadowing.\n'
        '2. Audio/video files you select or import, sentence-splitting results, and data generated during study '
        'are all processed only on your device.\n'
        '3. The Company does not transmit or store the audio/video files you select or import, or their contents, '
        'on the Company\'s servers or any external server, and does not use an external API for sentence '
        'splitting or study processing.\n'
        '4. The Company does not directly access content you select or import, and does not verify its copyright '
        'or other rights status.\n'
        '5. You must use the Service only for content you have a lawful right to use, or to the extent permitted '
        'by applicable law.',
  ),
  (
    'Article 3 (User Obligations)',
    '1. You must not use the Service in a way that infringes copyright, likeness rights, personal information, or '
        'other third-party rights.\n'
        '2. You must use the Service for personal learning purposes and must not distribute, share, sell, resell, '
        'or publish others\' content to third parties without legal basis or rights-holder permission.\n'
        '3. You must comply with applicable law, these Terms, and any notices the Company lawfully provides '
        'regarding the Service.\n'
        '4. You must not interfere with the normal operation of the Service or improperly bypass or alter the '
        'app\'s security or technical protection measures.\n'
        '5. If you infringe a third party\'s rights in violation of this Article, you must resolve the resulting '
        'issue directly with that rights holder, except that the Company bears responsibility under applicable '
        'law where the Company is at fault.',
  ),
  (
    'Article 4 (Storage of Content and Study Data)',
    '1. Audio/video files, sentence-splitting results, study progress, and study history used in the Service are '
        'processed and stored only on your device.\n'
        '2. The Company does not collect the content and study data described in paragraph 1, or transmit or '
        'store it on the Company\'s servers or any external server.\n'
        '3. The Company cannot access your audio/video content or the sentence-splitting results generated from '
        'it.\n'
        '4. If stored data is deleted due to app deletion, app-data deletion, device reset, device loss/failure, '
        'or other changes to your device environment, the Company cannot recover that data.\n'
        '5. Information processed by third-party services used to provide advertising or in-app purchase features '
        'is separate from your study content; see the Privacy Policy for details.',
  ),
  (
    'Article 5 (In-App Purchases)',
    '1. The Service may offer a one-time in-app purchase to provide specific features such as ad removal.\n'
        '2. In-app purchase payments are processed through the billing system of the relevant app marketplace, '
        'such as Google Play.\n'
        '3. The Company does not directly collect or store your card number, account number, or other payment '
        'method information.\n'
        '4. The Service may check purchase status and related information provided by the app marketplace to '
        'properly deliver purchased items.\n'
        '5. Withdrawal and refunds are handled under applicable law and the relevant app marketplace\'s policy. '
        'Where the marketplace\'s policy or these Terms would limit a right guaranteed to you by applicable law, '
        'applicable law controls.',
  ),
  (
    'Article 6 (Advertising)',
    '1. Users on the free tier of the Service may be shown ads.\n'
        '2. Third-party ad services such as Google AdMob may be used to deliver ads.\n'
        '3. In the course of providing ads, ad providers may process advertising identifiers, device or app '
        'information, and information about interactions with ads under their own policies; see the Privacy '
        'Policy for details.\n'
        '4. The Company does not provide the audio/video files you select or import for study, their contents, '
        'or sentence-splitting results, to ad providers.\n'
        '5. Users who purchase the ad-removal item will not be shown ads within the Service, subject to the terms '
        'of that purchase.',
  ),
  (
    'Article 7 (Changes, Suspension, and Termination of the Service)',
    '1. The Company may change or temporarily suspend all or part of the Service for any of the following '
        'reasons:\n'
        '   - Inspection, maintenance, or technical changes to the Service are needed\n'
        '   - Changes to the operating system, app marketplace, or third-party services make maintaining the '
        'Service difficult\n'
        '   - Applicable law or policy changes\n'
        '   - A security issue has occurred or may occur\n'
        '   - Other reasons reasonably necessary for operating the Service\n'
        '2. The Company may discontinue all or part of the Service where continuing it is difficult for '
        'reasonable technical, operational, or business reasons.\n'
        '3. Where a change or termination of the Service is planned that materially affects users, the Company '
        'will, where possible, provide advance notice via an in-app notice or other appropriate method.\n'
        '4. Where advance notice is difficult due to an urgent failure, security issue, force majeure, or similar '
        'reason, notice may be given after the fact.\n'
        '5. Where a change, suspension, or termination of the Service gives rise to a refund or other right under '
        'applicable law, that right will be handled in accordance with applicable law.',
  ),
  (
    'Article 8 (Rights in the Service and Content)',
    '1. Copyright and other intellectual property rights in the Service\'s programs, software, design, UI, logos, '
        'trademarks, and content created directly by the Company belong to the Company or the relevant rights '
        'holder.\n'
        '2. Rights in audio/video files and their content that you select or import from your own device belong '
        'to you or the pre-existing rights holder.\n'
        '3. Your use of the Service does not, by itself, transfer ownership, copyright, or other rights in your '
        'audio/video content to the Company.\n'
        '4. The Company does not use content you select or import for the Company\'s advertising, marketing, data '
        'analysis, AI training, or separate content production purposes.',
  ),
  (
    'Article 9 (Liability and Disclaimer)',
    '1. Sentence splitting, playback position, audio/video processing results, and other study features may vary '
        'depending on file format or quality, your device performance, and your operating environment.\n'
        '2. To the extent permitted by applicable law, the Company does not warrant that the Service will always '
        'be provided without interruption or error, or that it will produce a particular learning effect or '
        'result.\n'
        '3. Where a dispute arises with a copyright holder or other third party because you used content in '
        'violation of applicable law or these Terms, the Company bears no liability for that dispute unless the '
        'Company was at fault through intent or negligence.\n'
        '4. The Company bears no liability for damage arising from causes not attributable to the Company, such '
        'as force majeure, problems with your device or operating system, your own fault, communication '
        'failures, or failures of third-party services (such as the app marketplace or ad services) that are '
        'reasonably beyond the Company\'s control.\n'
        '5. Unless the Company is at fault, the Company bears no liability for data loss resulting from your '
        'failure to separately back up content or study data stored on your device.\n'
        '6. Where you suffer damage due to the Company\'s intent or negligence, the Company bears liability under '
        'applicable law.\n'
        '7. Nothing in these Terms shall be construed to exclude or limit the Company\'s legal liability for its '
        'own intentional misconduct or gross negligence, or any user right that cannot be limited under '
        'applicable law.',
  ),
  (
    'Article 10 (Changes to These Terms)',
    '1. The Company may amend these Terms without violating applicable law.\n'
        '2. Where the Company amends these Terms, it will, in principle, announce the changed content, the reason '
        'for the change, and the effective date starting 7 days before the effective date, via an in-app notice '
        'or other appropriate method provided by the Company.\n'
        '3. Where an amendment is disadvantageous to users or materially affects users\' rights or obligations, '
        'the Company will, in principle, provide notice starting 30 days before the effective date.\n'
        '4. Where applicable law requires a separate procedure or a longer notice period for amending these '
        'Terms, that law controls.\n'
        '5. Amended Terms take effect as of the announced effective date.',
  ),
  (
    'Article 11 (Governing Law and Dispute Resolution)',
    '1. These Terms are interpreted and applied under the laws of the Republic of Korea.\n'
        '2. Where a dispute arises between the Company and a user regarding use of the Service, both parties may '
        'confer in good faith to resolve it amicably.\n'
        '3. Where a dispute is not resolved through discussion, either party may bring an action in the court of '
        'competent jurisdiction under the Civil Procedure Act and other applicable law.',
  ),
  (
    'Article 12 (Contact)',
    'Inquiries about using the Service or these Terms may be directed to the contact below.\n\n'
        'Service name: ShadowingLab\n'
        'Business/Developer: $_placeholderCompanyEn\n'
        'Contact email: $_placeholderEmailEn',
  ),
  ('Addendum', 'These Terms take effect as of $_placeholderDateEn.'),
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
    '1. 本サービスは、利用者が自らの端末に保有するかまたは適法にアクセスできる音声または動画ファイルを選択・読み込み、'
        '文単位に分割して、繰り返し再生やシャドーイング等の方法で語学学習を行えるよう支援する個人向け学習ツールです。\n'
        '2. 利用者が選択・読み込んだ音声・動画ファイル、文分割結果および学習過程で生成されるデータは、すべて利用者の '
        '端末内でのみ処理されます。\n'
        '3. 当社は、利用者が選択・読み込んだ音声・動画ファイルおよびその内容を当社サーバーまたは外部サーバーに送信・'
        '保存せず、文分割および学習処理のために外部APIを使用しません。\n'
        '4. 当社は利用者が選択・読み込んだコンテンツに直接アクセスせず、当該コンテンツの著作権その他の権利関係を '
        '確認しません。\n'
        '5. 利用者は、自らが当該コンテンツを利用する適法な権限を有するか、関連法令により利用が認められる範囲で本 '
        'サービスを利用しなければなりません。',
  ),
  (
    '第3条（利用者の義務）',
    '1. 利用者は著作権、肖像権、個人情報その他第三者の権利を侵害する方法で本サービスを利用してはなりません。\n'
        '2. 利用者は本サービスを個人的な学習目的で利用しなければならず、他人のコンテンツを関連法令または権利者の '
        '許諾なく第三者に配布・共有・販売・再販または公開してはなりません。\n'
        '3. 利用者は関連法令、本規約および本サービスに関して当社が適法に案内する事項を遵守しなければなりません。\n'
        '4. 利用者は本サービスの正常な運営を妨害したり、アプリのセキュリティまたは技術的保護措置を不当に回避・改変'
        'する行為をしてはなりません。\n'
        '5. 利用者が本条に違反して第三者の権利を侵害した場合、それにより生じる問題は利用者と当該権利者との間で解決'
        'しなければなりません。ただし当社に帰責事由がある場合は関連法令に従い当社が責任を負います。',
  ),
  (
    '第4条（コンテンツおよび学習データの保存）',
    '1. 本サービスで利用される音声・動画ファイル、文分割結果、学習進捗状況および学習記録は、利用者の端末内でのみ '
        '処理・保存されます。\n'
        '2. 当社は第1項のコンテンツおよび学習データを収集せず、当社サーバーまたは外部サーバーへ送信・保存しません。\n'
        '3. 当社は利用者の音声・動画コンテンツおよび当該コンテンツから生成された文分割結果にアクセスできません。\n'
        '4. アプリの削除、アプリデータの削除、端末の初期化、端末の紛失・故障その他端末環境の変化により保存データが '
        '削除された場合、当社は当該データを復元できません。\n'
        '5. 広告またはアプリ内課金機能を提供するために利用される第三者サービスが処理する情報は、利用者の学習コンテ'
        'ンツとは別のものであり、詳細はプライバシーポリシーでご確認いただけます。',
  ),
  (
    '第5条（アプリ内課金）',
    '1. 本サービスは広告削除等の特定機能を提供するための一回限りのアプリ内課金商品を提供する場合があります。\n'
        '2. アプリ内課金の決済はGoogle Play等該当アプリマーケットの決済システムを通じて処理されます。\n'
        '3. 当社は利用者のカード番号、口座番号等の決済手段情報を直接収集または保存しません。\n'
        '4. 本サービスは購入商品の正常な提供のため、該当アプリマーケットが提供する購入有無および購入状態に関する '
        '情報を確認する場合があります。\n'
        '5. 申込みの撤回および返金は関連法令および該当アプリマーケットのポリシーに従い処理されます。アプリマーケッ'
        'トのポリシーまたは本規約が関連法令により利用者に保障される権利を制限する場合は、関連法令が優先して適用さ'
        'れます。',
  ),
  (
    '第6条（広告）',
    '1. 本サービスを無料で利用する利用者には広告が表示される場合があります。\n'
        '2. 広告提供のためGoogle AdMob等の第三者広告サービスが使用される場合があります。\n'
        '3. 広告サービス提供の過程で、広告提供事業者は広告識別子、端末またはアプリ関連情報、広告との相互作用情報等'
        'を自社ポリシーに従い処理する場合があります。詳細はプライバシーポリシーでご確認いただけます。\n'
        '4. 当社は利用者が学習のために選択・読み込んだ音声・動画ファイル、当該コンテンツの内容または文分割結果を '
        '広告提供事業者に提供しません。\n'
        '5. 広告削除商品を購入した利用者には、当該購入条件に従い本サービス内の広告が表示されません。',
  ),
  (
    '第7条（サービスの変更・中断および終了）',
    '1. 当社は次の各号の事由がある場合、本サービスの全部または一部を変更または一時的に中断することができます。\n'
        '   - 本サービスの点検、保守または技術的変更が必要な場合\n'
        '   - OS、アプリマーケットまたは第三者サービスの変更により本サービスの維持が困難な場合\n'
        '   - 関連法令またはポリシーの変更がある場合\n'
        '   - セキュリティ上の問題が発生したまたは発生するおそれがある場合\n'
        '   - その他本サービス運営上合理的に必要な事由がある場合\n'
        '2. 当社は技術的・運営上または経営上の合理的な事由により本サービスの継続が困難な場合、本サービスの全部また'
        'は一部を終了することができます。\n'
        '3. 利用者に重大な影響を及ぼす本サービスの変更または終了が予定されている場合、当社は可能な範囲で事前にアプ'
        'リ内告知その他適切な方法により案内します。\n'
        '4. 緊急な障害、セキュリティ問題、天災その他事前の案内が困難な事由がある場合は、事後に案内することができます。\n'
        '5. 本サービスの変更・中断または終了により利用者に法令上の返金その他の権利が発生する場合は、関連法令に従い'
        '処理します。',
  ),
  (
    '第8条（本サービスおよびコンテンツに関する権利）',
    '1. 本サービスのプログラム、ソフトウェア、デザイン、UI、ロゴ、商標および当社が直接制作したコンテンツ等に対す'
        'る著作権その他の知的財産権は、当社または正当な権利者に帰属します。\n'
        '2. 利用者が自らの端末で選択・読み込む音声・動画ファイルおよびそのコンテンツに対する権利は、当該利用者また'
        'は既存の正当な権利者に帰属します。\n'
        '3. 利用者が本サービスを利用するという理由のみで、当社が利用者の音声・動画コンテンツに対する所有権、著作権'
        'その他の権利を取得するものではありません。\n'
        '4. 当社は利用者が選択・読み込んだコンテンツを、当社の広告、マーケティング、データ分析、AI学習または別途の'
        'コンテンツ制作目的で利用しません。',
  ),
  (
    '第9条（責任および免責）',
    '1. 本サービスの文分割、再生位置、音声・動画処理結果その他の学習機能は、ファイルの形式・品質、利用者の端末性'
        '能および利用環境等により差異が生じる場合があります。\n'
        '2. 当社は関連法令が許す範囲で、本サービスが常に中断またはエラーなく提供されること、または特定の学習効果'
        'もしくは結果を保証するものではありません。\n'
        '3. 利用者が関連法令または本規約に違反してコンテンツを利用したことにより著作権者等第三者と紛争が生じた場'
        '合、当社に故意または過失等の帰責事由がない限り、当社は当該紛争について責任を負いません。\n'
        '4. 天災、利用者の端末またはOSの問題、利用者の帰責事由、通信障害、アプリマーケットまたは広告サービス等当社'
        'が合理的に制御し難い第三者サービスの障害等、当社に帰責事由のない事由により生じた損害について、当社は責任'
        'を負いません。\n'
        '5. 利用者が端末内に保存されたコンテンツや学習データを別途バックアップしなかったことにより生じたデータ損'
        '失について、当社に帰責事由がない限り当社は責任を負いません。\n'
        '6. 当社の故意または過失により利用者に損害が生じた場合、当社は関連法令に従い責任を負います。\n'
        '7. 本規約のいかなる内容も、当社の故意または重過失による法律上の責任、または関連法令により制限できない利'
        '用者の権利を排除または制限するものと解釈されません。',
  ),
  (
    '第10条（規約の変更）',
    '1. 当社は関連法令に違反しない範囲で本規約を変更することができます。\n'
        '2. 当社が規約を変更する場合、変更内容、変更理由および適用日を明示し、原則として適用日の7日前からアプリ内'
        '告知その他当社が提供する適切な方法により案内します。\n'
        '3. 利用者に不利な内容または利用者の権利・義務に重大な影響を及ぼす内容に規約を変更する場合は、原則として適'
        '用日の30日前から案内します。\n'
        '4. 関連法令が規約変更について別途の手続または、より長い通知期間を要求する場合は、当該法令に従います。\n'
        '5. 変更後の規約は案内された適用日から効力を生じます。',
  ),
  (
    '第11条（準拠法および紛争解決）',
    '1. 本規約は大韓民国の法令に従って解釈・適用されます。\n'
        '2. 当社と利用者間で本サービスの利用に関して紛争が生じた場合、当社と利用者は円満な解決のため誠実に協議す'
        'ることができます。\n'
        '3. 協議により紛争が解決しない場合、民事訴訟法等関連法令に定める管轄裁判所に訴えを提起することができます。',
  ),
  (
    '第12条（お問い合わせ）',
    '本サービスの利用および本規約に関するお問い合わせは、以下の連絡先までご連絡ください。\n\n'
        'サービス名：シャドーイングラボ\n'
        '事業者/開発者名：$_placeholderCompanyJa\n'
        'お問い合わせメール：$_placeholderEmailJa',
  ),
  ('附則', '本規約は$_placeholderDateJaから施行します。'),
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
