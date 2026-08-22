import 'dart:ui';

/// مزاج لونيّ — لوحةٌ **مختارة** لا مشتقّة.
///
/// `ArtPalette.from` يبني اللوحة كلّها من **لون واحد**: الأساس يُضبط
/// تشبّعه وإضاءته، والمرافق يُدار على عجلة الألوان بزاوية، والعميق درجة
/// أغمق، والحياديّ رماديّ مصبوغ بدرجة الأساس. وهذا حسابٌ سليم — لكنه
/// يعني أن كل تصميم في التطبيق **تنويعٌ على درجة لونية واحدة**: لونِ
/// علامة التاجر. فمن علامتُه كحليّة لا يرى إلا الكحليّ، مهما بدّل
/// القالب والتكوين والصيغة.
///
/// وبلاغُ تاجرٍ قال «الألوان محدودة» كان يصف هذا بالضبط. والعلّة ليست
/// في جودة الاشتقاق بل في أنّ **مصدرًا واحدًا لا يُخرج تنوّعًا**:
/// `variant` ينوّع العلاقة بين الألوان (متقابل، منشقّ، ثلاثيّ، متجاور)
/// ولا ينوّع الألوان نفسها.
///
/// وهذه الأمزجة تقلب المصدر: بدل درجةٍ واحدة نبني عليها، **لوحاتٌ
/// كاملة** اختير كل لون فيها بالعين لا بالزاوية. وثلاثة قرارات:
///
///   ١) **الألوان صريحة لا محسوبة.** الفحميّ والذهبيّ ليس «أساسٌ + ١٥٠°»
///      — هو رماديٌّ فحميّ بعينه وذهبٌ بعينه، لأن الأزواج التي تُرى
///      جميلةً لا تقع على زوايا منتظمة من عجلة الألوان. وقد جرّبتُ
///      توليدها بالاشتقاق فخرج نصفها موحلًا.
///
///   ٢) **المزاج رقمٌ في المواصفة** (`DesignSpec.mood`) كنظيرَيه
///      `variant` و`pairing` — فيختاره النموذج كما يختاره التاجر، ولا
///      يعرف أيٌّ منهما أسماء ألواننا.
///
///   ٣) **لون العلامة يبقى خيارًا لا فرضًا، وهو الافتراض.**
///      `AppState.designMoodId == null` — وهي الحال الأولى — تعني
///      «اشتقّ من لون علامتي» كما كان الأمر دائمًا. فمن ضبط هويّته لا
///      يستيقظ على تصاميمه وقد تبدّلت، ومن أراد غير لونه اختار مزاجًا.
///      وكذلك `DesignSpec.mood == null` في المواصفات المحفوظة سلفًا.
library;

/// لوحة مختارة بأربعة ألوان وحبرين يُحسبان.
class ArtMood {
  const ArtMood({
    required this.id,
    required this.name,
    required this.note,
    required this.base,
    required this.deep,
    required this.complement,
    required this.neutral,
  });

  /// معرّف ثابت يُحفظ ويُرسل. الاسم للعرض والرقم للفهرسة، وهذا للتخزين
  /// — فإعادة ترتيب القائمة لا تُبدّل مزاج تاجرٍ حفظه.
  final String id;

  final String name;

  /// متى يصلح. يُعرض للتاجر ويُفيد النموذج في الاختيار.
  final String note;

  /// لون الهوية في هذه اللوحة — الأسطح الكبيرة والأشرطة.
  final Color base;

  /// العمق: خلفيات وأسطح خلف النصّ.
  final Color deep;

  /// ما يقفز: الشارات والأزرار وما يجب أن يُرى أوّلًا.
  final Color complement;

  /// سطحٌ يريح العين خلف المنتج والنصوص الثانوية. فاتحٌ في كل مزاج —
  /// وعليه تعتمد خلفية `paper` لتبقى فاتحةً مهما كان المزاج، فيصحّ
  /// معنى «أفضّل تصميمًا فاتحًا» الذي يختاره التاجر.
  final Color neutral;

  // ولا حقل `isLight` هنا عمدًا.
  //
  // كان في أوّل صياغة، ثم حُذف: العارض لا يسأل المزاج أفاتحٌ هو، بل
  // **يقيس** — `backgroundBehind` يعيد اللون الواقع تحت الحروف فعلًا،
  // و`ArtPalette.inkOn` يحسب الحبر عليه بمعادلة WCAG. فراية تقول
  // «فاتح» لا تُستشار في القرار، وإنما تنتظر أن يُخالفها لونٌ عُدّل
  // يومًا فتكذب بصمت. والحقيقة المحسوبة تُغني عن المعلنة.

  /// الأمزجة المتاحة. القائمة مغلقة عمدًا كقائمة `ArtFonts.pairs`:
  /// حرّيةُ جمع أيّ أربعة ألوان تُخرج لوحاتٍ موحلة أكثر مما تُخرج جميلة.
  ///
  /// وترتيبها مقصود: الأوّل ما يقع عليه `mood = 0`، أي ما يراه من لم
  /// يختر. فصُدّر أوسعُها صلاحيةً لا أغربُها.
  static const moods = <ArtMood>[
    ArtMood(
      id: 'midnight',
      name: 'ليليّ وذهبيّ',
      note: 'كحليّ عميق وذهب — فخم وواسع الصلاحية.',
      base: Color(0xFF1B2A5B),
      deep: Color(0xFF0B1226),
      complement: Color(0xFFE1A83B),
      neutral: Color(0xFFF2EFE7),
    ),
    ArtMood(
      id: 'terracotta',
      name: 'دافئ ترابيّ',
      note: 'طينيّ وكريميّ — للمقاهي والمخابز والحِرَف.',
      base: Color(0xFFB4552D),
      deep: Color(0xFF3A1B10),
      complement: Color(0xFFE8B34A),
      neutral: Color(0xFFF6EDE2),
    ),
    ArtMood(
      id: 'sea',
      name: 'بحريّ بارد',
      note: 'أزرق مخضرّ وفيروزيّ — للعيادات والتقنيّة والمياه.',
      base: Color(0xFF11565F),
      deep: Color(0xFF06282D),
      complement: Color(0xFF48CBC0),
      neutral: Color(0xFFEAF4F3),
    ),
    ArtMood(
      id: 'charcoal',
      name: 'فحميّ وذهبيّ',
      note: 'رماديّ فحميّ وذهب هادئ — للفخامة الصامتة.',
      base: Color(0xFF3A3D42),
      deep: Color(0xFF17181B),
      complement: Color(0xFFC9A227),
      neutral: Color(0xFFEDEBE6),
    ),
    ArtMood(
      id: 'olive',
      name: 'أخضر طبيعيّ',
      note: 'زيتونيّ وعسليّ — للعضويّ والزراعيّ والصحّيّ.',
      base: Color(0xFF4A5D2A),
      deep: Color(0xFF1E2712),
      complement: Color(0xFFD8B24C),
      neutral: Color(0xFFF1F0E3),
    ),
    ArtMood(
      id: 'berry',
      name: 'توتيّ غنيّ',
      note: 'عنّابيّ ووَرديّ — للحلويات والتجميل والهدايا.',
      base: Color(0xFF7A1F45),
      deep: Color(0xFF2E0A1B),
      complement: Color(0xFFF08FB0),
      neutral: Color(0xFFFBECF1),
    ),
    ArtMood(
      id: 'pastel',
      name: 'باستيل فاتح',
      note: 'خلفية فاتحة ولمسة لافندر — خفيف وعصريّ.',
      base: Color(0xFF7C6BD1),
      deep: Color(0xFFF4F1FB),
      complement: Color(0xFFEF7A6B),
      neutral: Color(0xFFFFFFFF),
    ),
    ArtMood(
      id: 'paper',
      name: 'ورقيّ وحبر',
      note: 'عاجيّ وحبر داكن — للمطبوع وقوائم الطعام.',
      base: Color(0xFF2C2A26),
      deep: Color(0xFFF5F0E6),
      complement: Color(0xFFB4552D),
      neutral: Color(0xFFFFFDF8),
    ),
    ArtMood(
      id: 'citrus',
      name: 'حمضيّ صاخب',
      note: 'برتقاليّ وأصفر — للخصومات التي تُقرأ من الشارع.',
      base: Color(0xFFE2521A),
      deep: Color(0xFF3D1405),
      complement: Color(0xFFFFC93C),
      neutral: Color(0xFFFFF3E2),
    ),
    ArtMood(
      id: 'saudi',
      name: 'أخضر وطنيّ',
      note: 'أخضر سعوديّ وذهب — لليوم الوطني والمناسبات الرسمية.',
      base: Color(0xFF14663B),
      deep: Color(0xFF06291A),
      complement: Color(0xFFD9B96A),
      neutral: Color(0xFFEFF5EF),
    ),
    ArtMood(
      id: 'ramadan',
      name: 'رمضانيّ',
      note: 'بنفسجيّ ليليّ وذهب دافئ — لرمضان والعيد.',
      base: Color(0xFF3B2A63),
      deep: Color(0xFF150E2A),
      complement: Color(0xFFE3B857),
      neutral: Color(0xFFF3EFF8),
    ),
    ArtMood(
      id: 'mono',
      name: 'أبيض وأسود',
      note: 'بلا لون — للأزياء والتصوير وما يجب ألّا يزاحمه لون.',
      base: Color(0xFF222222),
      deep: Color(0xFF0E0E0E),
      complement: Color(0xFFBFBFBF),
      neutral: Color(0xFFF4F4F4),
    ),
  ];

  /// المزاج برقمه — كما تُختار اللوحة بـ`variant` والوجهُ بـ`pairing`.
  static ArtMood at(int index) => moods[index.abs() % moods.length];

  /// المزاج بمعرّفه المحفوظ. المجهول يعود إلى الأوّل لا يرمي: معرّفٌ
  /// قديم من نسخةٍ حُذف مزاجها لا يجوز أن يُسقط تصميم التاجر.
  static ArtMood byId(String? id) => moods.firstWhere(
    (m) => m.id == id,
    orElse: () => moods.first,
  );

  /// فهرس المزاج بمعرّفه. `0` للمجهول، للسبب نفسه.
  static int indexOfId(String? id) {
    final i = moods.indexWhere((m) => m.id == id);
    return i < 0 ? 0 : i;
  }

  @override
  String toString() => '$name ($id)';
}
