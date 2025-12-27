// ─────────────────────────────────────────────────────────────────────────────
//  Investor PDFs generator (deck + full business plan)
//
//  Генерирует 2 PDF файла, используя:
//  - Лого: assets/logo.png
//  - Шрифт: Inter (fonts/Inter-*.ttf) из проекта
//  - Брендовый цвет: AppColors.brandPrimary (0xFF379AE6)
//
//  Запуск:
//    dart run tool/investor/generate_investor_pdfs.dart
//
//  Результат:
//    docs/investor/paceup_investor_deck.pdf
//    docs/investor/paceup_business_plan.pdf
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────────────────────
//                                Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Брендовый цвет (см. `lib/core/theme/colors.dart` → AppColors.brandPrimary).
const int _kBrandPrimaryArgb = 0xFF379AE6;

/// Путь к лого в репозитории.
const String _kLogoPath = 'assets/logo.png';

/// Путь, куда кладём результат.
const String _kOutDir = 'docs/investor';

/// Имена выходных файлов.
const String _kDeckFileName = 'paceup_investor_deck.pdf';
const String _kPlanFileName = 'paceup_business_plan.pdf';

// ─────────────────────────────────────────────────────────────────────────────
//                                   Main
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  final outDir = Directory(_kOutDir)..createSync(recursive: true);

  final fonts = await _loadInterFonts();
  final logoBytes = await _readRequiredBytes(_kLogoPath);
  final logo = pw.MemoryImage(logoBytes);

  final deckDoc = _buildDeckPdf(logo: logo, fonts: fonts);
  final planDoc = _buildBusinessPlanPdf(logo: logo, fonts: fonts);

  final deckBytes = await deckDoc.save();
  final planBytes = await planDoc.save();

  final deckOut = File('${outDir.path}/$_kDeckFileName');
  final planOut = File('${outDir.path}/$_kPlanFileName');

  deckOut.writeAsBytesSync(deckBytes, flush: true);
  planOut.writeAsBytesSync(planBytes, flush: true);

  stdout.writeln('OK: ${deckOut.path}');
  stdout.writeln('OK: ${planOut.path}');
}

// ─────────────────────────────────────────────────────────────────────────────
//                             Fonts / Assets
// ─────────────────────────────────────────────────────────────────────────────

Future<Uint8List> _readRequiredBytes(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Required file not found: $path');
  }
  return file.readAsBytes();
}

Future<_InterFonts> _loadInterFonts() async {
  // ──────────────────────────────────────────────────────────────
  // Загружаем Inter из папки fonts (см. pubspec.yaml).
  // ──────────────────────────────────────────────────────────────
  final regular = await _readRequiredBytes('fonts/Inter-Regular.ttf');
  final medium = await _readRequiredBytes('fonts/Inter-Medium.ttf');
  final semiBold = await _readRequiredBytes('fonts/Inter-SemiBold.ttf');
  final bold = await _readRequiredBytes('fonts/Inter-Bold.ttf');

  return _InterFonts(
    regular: pw.Font.ttf(regular.buffer.asByteData()),
    medium: pw.Font.ttf(medium.buffer.asByteData()),
    semiBold: pw.Font.ttf(semiBold.buffer.asByteData()),
    bold: pw.Font.ttf(bold.buffer.asByteData()),
  );
}

class _InterFonts {
  final pw.Font regular;
  final pw.Font medium;
  final pw.Font semiBold;
  final pw.Font bold;

  const _InterFonts({
    required this.regular,
    required this.medium,
    required this.semiBold,
    required this.bold,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//                                Styling
// ─────────────────────────────────────────────────────────────────────────────

PdfColor _brandPrimary() => const PdfColor.fromInt(_kBrandPrimaryArgb);

PdfColor _textPrimary() => const PdfColor(0.11, 0.11, 0.12);

PdfColor _textSecondary() => const PdfColor(0.42, 0.42, 0.44);

PdfColor _surface() => const PdfColor(1, 1, 1);

PdfColor _background() => const PdfColor(0.95, 0.95, 0.97);

PdfColor _divider() => const PdfColor(0.90, 0.90, 0.92);

// ─────────────────────────────────────────────────────────────────────────────
//                              Investor Deck
// ─────────────────────────────────────────────────────────────────────────────

pw.Document _buildDeckPdf({
  required pw.ImageProvider logo,
  required _InterFonts fonts,
}) {
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold);

  // ──────────────────────────────────────────────────────────────
  // Важно: цифры и допущения тут сознательно “плейсхолдерные”,
  // по запросу пользователя. Для инвестора позже заменяем фактами.
  // ──────────────────────────────────────────────────────────────

  final pages = <_DeckSlide>[
    const _DeckSlide(
      title: 'PaceUp',
      subtitle: 'Спортивная платформа: тренировки → люди → события → сделки',
      bullets: [
        'Россия: запуск по всей стране, рост через 10–20 якорных городов',
        'Стадия: MVP готов, pre‑launch',
        'Монетизация: маркет/комиссия → PacePro → реклама/партнёрки',
      ],
    ),
    const _DeckSlide(
      title: 'Проблема',
      subtitle: 'Спорт‑путь пользователя разорван на инструменты',
      bullets: [
        'Тренировки в трекерах — отдельно',
        'Сообщество и мотивация — отдельно',
        'Локальные старты/клубы — фрагментированы',
        'Вторичный рынок слотов/экипировки — без специализированной воронки',
      ],
    ),
    const _DeckSlide(
      title: 'Решение',
      subtitle: '“Всё спортивное” в одном приложении',
      bullets: [
        'Авто‑импорт тренировок (Health/Strava) → контент появляется сам',
        'Лента + подписки + челленджи → удержание',
        'Карта событий/клубов → локальный рост',
        'Маркет слотов/вещей + чаты → транзакции',
      ],
    ),
    const _DeckSlide(
      title: 'Продукт (MVP)',
      subtitle: 'Что уже реализовано в приложении',
      bullets: [
        'Лента активностей/постов, пагинация, оффлайн‑кэш',
        'Карта: события и клубы, кластеризация маркеров',
        'Маркет: слоты и вещи + чаты сделок + алерты',
        'Уведомления и бейджи, задачи и лидерборды',
      ],
    ),
    const _DeckSlide(
      title: 'Почему мы сможем',
      subtitle: 'Техническая база под “быстрый UX” и рост плотности контента',
      bullets: [
        'Offline‑first (Drift) + единый image cache',
        'Импорт тренировок снижает cost of content',
        'Кластеризация карты под рост событий/клубов',
      ],
    ),
    const _DeckSlide(
      title: 'Рынок (placeholder)',
      subtitle: 'TAM / SAM / SOM — будут уточнены по источникам',
      bullets: [
        'TAM: цифровой фитнес + любительские старты + экипировка (РФ)',
        'SAM: мультиспорт‑аудитория крупных городов + участники стартов',
        'SOM (12 мес): достижимая аудитория якорных городов',
      ],
    ),
    const _DeckSlide(
      title: 'Конкуренты',
      subtitle: 'Мы объединяем то, что сейчас разрознено',
      bullets: [
        'Strava‑класс (соцсеть тренировок)',
        'Трекеры (Apple/Google/прочие)',
        'Каталоги стартов/клубов (локальные)',
        'Маркетплейсы общего назначения',
      ],
    ),
    const _DeckSlide(
      title: 'Монетизация (этапы)',
      subtitle: 'Сначала транзакции, потом подписка',
      bullets: [
        '0–6 мес: комиссия/платное продвижение в маркете + affiliate',
        '6–12 мес: PacePro подписка (аналитика/планы/приоритет)',
        '12+ мес: реклама/спонсоры (после масштаба)',
      ],
    ),
    const _DeckSlide(
      title: 'Go‑To‑Market',
      subtitle: 'Доступно по всей РФ, рост — в городских кластерах',
      bullets: [
        '10–20 якорных городов: партнёры, клубы, организаторы стартов',
        'Paid acquisition 300k–1 млн ₽/мес: тесты, оптимизация по KPI',
        'Механики: импорт → лента → челленджи → события/маркет',
      ],
    ),
    const _DeckSlide(
      title: 'Метрики (north star)',
      subtitle: 'Что докажет PMF и монетизацию',
      bullets: [
        'Activation: % подключивших трекеры + импорт 1 тренировки',
        'Engagement: D7/D30, sessions/week',
        'Marketplace: chat→reserve→deal, GMV, take rate',
        'Revenue: conversion to Pro, ARPU',
      ],
    ),
    const _DeckSlide(
      title: 'План 12 месяцев',
      subtitle: 'Переход от MVP к монетизации',
      bullets: [
        '0–8 недель: безопасность/авторизация, аналитика, on‑boarding',
        '2–6 мес: рост якорных городов, усиление маркета',
        '6–12 мес: PacePro + масштабирование партнёрств',
      ],
    ),
    const _DeckSlide(
      title: 'Раунд',
      subtitle: 'Pre‑seed 5–20 млн ₽',
      bullets: [
        'Цель: публичный запуск по РФ, рост в якорных городах, первые доходы',
        'Use of funds: продукт+безопасность+аналитика+рост+модерация',
        'Runway: 9–15 месяцев (placeholder)',
      ],
    ),
  ];

  for (final slide in pages) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: theme,
        build: (_) => _DeckSlideView(slide: slide, logo: logo),
      ),
    );
  }

  return doc;
}

class _DeckSlide {
  final String title;
  final String subtitle;
  final List<String> bullets;

  const _DeckSlide({
    required this.title,
    required this.subtitle,
    required this.bullets,
  });
}

class _DeckSlideView extends pw.StatelessWidget {
  _DeckSlideView({required this.slide, required this.logo});

  final _DeckSlide slide;
  final pw.ImageProvider logo;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      color: _background(),
      padding: const pw.EdgeInsets.all(36),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 56,
                height: 56,
                decoration: pw.BoxDecoration(
                  color: _surface(),
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: _divider(), width: 1),
                ),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 14),
              pw.Text(
                slide.title,
                style: pw.TextStyle(
                  fontSize: 34,
                  fontWeight: pw.FontWeight.bold,
                  color: _textPrimary(),
                ),
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: _surface(),
                  borderRadius: pw.BorderRadius.circular(999),
                  border: pw.Border.all(color: _divider(), width: 1),
                ),
                child: pw.Text(
                  'Investor deck',
                  style: pw.TextStyle(fontSize: 12, color: _textSecondary()),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Container(height: 2, width: 84, color: _brandPrimary()),
          pw.SizedBox(height: 18),
          pw.Text(
            slide.subtitle,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: _brandPrimary(),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            decoration: pw.BoxDecoration(
              color: _surface(),
              borderRadius: pw.BorderRadius.circular(18),
              border: pw.Border.all(color: _divider(), width: 1),
            ),
            padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final b in slide.bullets)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          margin: const pw.EdgeInsets.only(top: 7),
                          width: 6,
                          height: 6,
                          decoration: pw.BoxDecoration(
                            color: _brandPrimary(),
                            borderRadius: pw.BorderRadius.circular(99),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Text(
                            b,
                            style: pw.TextStyle(
                              fontSize: 15,
                              color: _textPrimary(),
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Row(
            children: [
              pw.Text(
                'PaceUp • РФ • ${DateTime.now().year}',
                style: pw.TextStyle(fontSize: 11, color: _textSecondary()),
              ),
              pw.Spacer(),
              pw.Text(
                'Данные: placeholder / assumptions',
                style: pw.TextStyle(fontSize: 11, color: _textSecondary()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                             Full Business Plan
// ─────────────────────────────────────────────────────────────────────────────

pw.Document _buildBusinessPlanPdf({
  required pw.ImageProvider logo,
  required _InterFonts fonts,
}) {
  final doc = pw.Document();

  final theme = pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold);

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 48),
      ),
      header: (_) => _PlanHeader(logo: logo),
      footer: (ctx) => _PlanFooter(page: ctx.pageNumber, pages: ctx.pagesCount),
      build: (_) => [
        _PlanCover(),
        pw.SizedBox(height: 18),
        _PlanDisclaimer(),
        pw.SizedBox(height: 18),
        _PlanSection(
          title: '1. Резюме проекта',
          blocks: [
            _PlanBlock.paragraph(
              'PaceUp — спортивная платформа для пользователей из России: '
              'лента тренировок и постов, карта событий и клубов, маркет '
              'слотов и экипировки, чаты и уведомления. '
              'Старт — nationwide (вся РФ), рост — через 10–20 якорных городов.',
            ),
            _PlanBlock.bullets(const [
              'Стадия: MVP готов, запуск готовится.',
              'Монетизация: транзакции/комиссия → подписка PacePro → реклама.',
              'Запрос: Pre‑seed 5–20 млн ₽ на 9–15 месяцев runway (placeholder).',
            ]),
          ],
        ),
        _PlanSection(
          title: '2. Проблема',
          blocks: [
            _PlanBlock.bullets(const [
              'Тренировки живут в трекерах, а социальная мотивация — отдельно.',
              'События и клубы — фрагментированы по сайтам/чатам.',
              'Слоты на старты и вторичка экипировки — без удобной воронки.',
            ]),
          ],
        ),
        _PlanSection(
          title: '3. Решение и ценностное предложение',
          blocks: [
            _PlanBlock.bullets(const [
              'Импорт тренировок (Health/Strava) создаёт контент автоматически.',
              'Соцграф, задачи, лидерборды повышают вовлечённость.',
              'Карта событий/клубов даёт локальную “точку сборки”.',
              'Маркет + чаты сделок создают транзакционный слой.',
            ]),
          ],
        ),
        _PlanSection(
          title: '4. Продукт (MVP) — подтверждено репозиторием',
          blocks: [
            _PlanBlock.bullets(const [
              'Лента: пагинация, обновления, оффлайн‑кэш.',
              'Импорт: Health Connect/HealthKit, Strava sync, маршруты Android.',
              'Карта: события/клубы, кластеризация.',
              'Маркет: слоты/вещи, алерты, чаты сделок.',
              'Уведомления и бейджи, задачи и лидерборды.',
            ]),
          ],
        ),
        _PlanSection(
          title: '5. Рынок (placeholder‑модель, требует валидации источниками)',
          blocks: [
            _PlanBlock.paragraph(
              'Мы используем комбинированный подход: top‑down (рынок цифрового '
              'фитнеса/спорт‑приложений) + bottom‑up (активные спортсмены '
              'в якорных городах).',
            ),
            _PlanBlock.table(
              headers: ['Сценарий', 'SOM (12 мес)', 'MAU', 'Комментарий'],
              rows: [
                ['Консервативный', '0.02% РФ', '30k', 'Низкий paid, органика'],
                ['Базовый', '0.05% РФ', '80k', 'Фокус на якорных городах'],
                ['Агрессивный', '0.10% РФ', '150k', 'Сильные партнёрства/paid'],
              ],
            ),
          ],
        ),
        _PlanSection(
          title: '6. Бизнес‑модель и монетизация',
          blocks: [
            _PlanBlock.bullets(const [
              '0–6 мес: комиссия с маркета + платное продвижение + affiliate.',
              '6–12 мес: PacePro подписка (аналитика/планы/приоритетные алерты).',
              '12+ мес: реклама/спонсоры (после масштаба и сегментации).',
            ]),
            _PlanBlock.table(
              headers: ['Поток', 'Механика', 'Плейсхолдер'],
              rows: [
                ['Take rate', 'Комиссия маркета', '5%'],
                ['Pro', 'Подписка/мес', '399 ₽'],
                ['Affiliate', 'CPA/покупка', '3–8%'],
              ],
            ),
          ],
        ),
        _PlanSection(
          title: '7. Go‑To‑Market: nationwide + city‑focused growth',
          blocks: [
            _PlanBlock.paragraph(
              'Приложение доступно по всей стране с первого дня. '
              'Рост и партнёрства концентрируются в 10–20 городах, '
              'чтобы ускорить цикл обучения и снизить CAC.',
            ),
            _PlanBlock.bullets(const [
              'Маркетинг 300k–1 млн ₽/мес (первые 3 месяца).',
              'Партнёры: организаторы стартов, клубы, амбассадоры.',
              'Ключевой onboarding: трекер → импорт тренировки → подписка → чат.',
            ]),
          ],
        ),
        _PlanSection(
          title: '8. Метрики и KPI (placeholder)',
          blocks: [
            _PlanBlock.table(
              headers: ['Метрика', 'Цель (3 мес)', 'Почему важно'],
              rows: [
                [
                  'Activation',
                  '35% подключили трекер',
                  'контент появляется сам',
                ],
                ['D7', '18%', 'проверка вовлечённости'],
                ['GMV', '10 млн ₽', 'монетизация маркета'],
                ['Paid Pro', '1.5% MAU', 'путь к подписке'],
              ],
            ),
          ],
        ),
        _PlanSection(
          title: '9. Риски и блокеры к публичному запуску',
          blocks: [
            _PlanBlock.bullets(const [
              'Авторизация/токены: убрать временные “костыли”.',
              'Секреты/ключи: процесс хранения и ротации.',
              'Модерация маркета: анти‑фрод и правила сделок.',
              'Push‑инфраструктура и аналитика воронок.',
            ]),
          ],
        ),
        _PlanSection(
          title: '10. Roadmap (12 месяцев)',
          blocks: [
            _PlanBlock.table(
              headers: ['Период', 'Цель', 'Результат'],
              rows: [
                ['0–8 недель', 'Launch readiness', 'публичный релиз РФ'],
                ['2–6 мес', 'Рост якорных городов', 'первые транзакции'],
                ['6–12 мес', 'PacePro + масштаб', 'устойчивая выручка'],
              ],
            ),
          ],
        ),
        _PlanSection(
          title: '11. Запрос инвестиций (use of funds)',
          blocks: [
            _PlanBlock.paragraph(
              'Pre‑seed 5–20 млн ₽: два режима — Lean и Growth. '
              'Цифры ниже — плейсхолдеры до уточнения структуры затрат.',
            ),
            _PlanBlock.table(
              headers: ['Статья', 'Lean (₽)', 'Growth (₽)'],
              rows: [
                ['Продукт/инженерия', '3.0M', '7.0M'],
                ['Маркетинг', '1.5M', '6.0M'],
                ['Операции/модерация', '0.7M', '3.0M'],
                ['Резерв', '0.8M', '4.0M'],
              ],
            ),
          ],
        ),
        _PlanSection(
          title: '12. Приложение: доказательства по репозиторию',
          blocks: [
            _PlanBlock.bullets(const [
              'API клиент: lib/core/services/api_service.dart',
              'Лента: lib/features/lenta/…',
              'Импорт: lib/core/services/health_sync_service.dart и '
                  'lib/core/services/strava_sync_service.dart',
              'Карта: lib/features/map/screens/map_screen.dart',
              'Маркет: lib/features/market/…',
              'Offline/perf docs: docs/offline-first-implementation.md, '
                  'docs/unified-image-cache.md',
            ]),
          ],
        ),
      ],
    ),
  );

  return doc;
}

class _PlanHeader extends pw.StatelessWidget {
  _PlanHeader({required this.logo});

  final pw.ImageProvider logo;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _divider(), width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 28,
            height: 28,
            padding: const pw.EdgeInsets.all(3),
            decoration: pw.BoxDecoration(
              color: _surface(),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: _divider(), width: 1),
            ),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            'PaceUp • Бизнес‑план (RU)',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _textPrimary(),
            ),
          ),
          pw.Spacer(),
          pw.Text(
            'confidential (draft)',
            style: pw.TextStyle(fontSize: 10, color: _textSecondary()),
          ),
        ],
      ),
    );
  }
}

class _PlanFooter extends pw.StatelessWidget {
  _PlanFooter({required this.page, required this.pages});

  final int page;
  final int pages;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _divider(), width: 1)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'PaceUp • ${DateTime.now().toIso8601String().substring(0, 10)}',
            style: pw.TextStyle(fontSize: 9, color: _textSecondary()),
          ),
          pw.Spacer(),
          pw.Text(
            '$page / $pages',
            style: pw.TextStyle(fontSize: 9, color: _textSecondary()),
          ),
        ],
      ),
    );
  }
}

class _PlanCover extends pw.StatelessWidget {
  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _surface(),
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _divider(), width: 1),
      ),
      padding: const pw.EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PaceUp',
            style: pw.TextStyle(
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
              color: _textPrimary(),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Бизнес‑план для инвестора (черновик)',
            style: pw.TextStyle(
              fontSize: 14,
              color: _brandPrimary(),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Россия: запуск по всей стране • рост через 10–20 якорных городов',
            style: pw.TextStyle(fontSize: 11, color: _textSecondary()),
          ),
        ],
      ),
    );
  }
}

class _PlanDisclaimer extends pw.StatelessWidget {
  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _background(),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _divider(), width: 1),
      ),
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: pw.Text(
        'Дисклеймер: все цифры, бюджеты и прогнозы в этом документе — '
        'плейсхолдеры (assumptions) по вашему запросу и требуют валидации '
        'на реальных данных, источниках и результатах экспериментов.',
        style: pw.TextStyle(
          fontSize: 10,
          color: _textSecondary(),
          height: 1.25,
        ),
      ),
    );
  }
}

class _PlanSection extends pw.StatelessWidget {
  _PlanSection({required this.title, required this.blocks});

  final String title;
  final List<_PlanBlock> blocks;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _textPrimary(),
            ),
          ),
          pw.SizedBox(height: 8),
          for (final b in blocks) ...[b, pw.SizedBox(height: 10)],
        ],
      ),
    );
  }
}

class _PlanBlock extends pw.StatelessWidget {
  _PlanBlock._(this._builder);

  final pw.Widget Function() _builder;

  factory _PlanBlock.paragraph(String text) {
    return _PlanBlock._(
      () => pw.Text(
        text,
        style: pw.TextStyle(fontSize: 11, color: _textPrimary(), height: 1.35),
      ),
    );
  }

  factory _PlanBlock.bullets(List<String> items) {
    return _PlanBlock._(
      () => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final i in items)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 6),
                    width: 4,
                    height: 4,
                    decoration: pw.BoxDecoration(
                      color: _brandPrimary(),
                      borderRadius: pw.BorderRadius.circular(99),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(
                      i,
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: _textPrimary(),
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  factory _PlanBlock.table({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return _PlanBlock._(
      () => pw.Container(
        decoration: pw.BoxDecoration(
          color: _surface(),
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: _divider(), width: 1),
        ),
        child: pw.Table(
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _divider(), width: 1),
          ),
          columnWidths: {
            for (int i = 0; i < headers.length; i++)
              i: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _background()),
              children: [
                for (final h in headers)
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: _textSecondary(),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            for (final r in rows)
              pw.TableRow(
                children: [
                  for (final c in r)
                    pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: pw.Text(
                        c,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _textPrimary(),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  pw.Widget build(pw.Context context) => _builder();
}
