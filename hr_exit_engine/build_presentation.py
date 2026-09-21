import os
from reportlab.lib.pagesizes import landscape, A4
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

# 1. Регистрация системных шрифтов Windows для полной поддержки кириллицы
font_regular_path = "C:\\Windows\\Fonts\\arial.ttf"
font_bold_path = "C:\\Windows\\Fonts\\arialbd.ttf"

if os.path.exists(font_regular_path) and os.path.exists(font_bold_path):
    pdfmetrics.registerFont(TTFont('ArialCustom', font_regular_path))
    pdfmetrics.registerFont(TTFont('ArialCustom-Bold', font_bold_path))
    FONT_NORMAL = 'ArialCustom'
    FONT_BOLD = 'ArialCustom-Bold'
else:
    FONT_NORMAL = 'Helvetica'
    FONT_BOLD = 'Helvetica-Bold'

PAGE_W, PAGE_H = landscape(A4)

class PresentationCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_decorations(self, total_pages):
        self.saveState()
        # Верхняя акцентная линия
        self.setStrokeColor(colors.HexColor("#4F46E5"))
        self.setLineWidth(4)
        self.line(40, PAGE_H - 24, PAGE_W - 40, PAGE_H - 24)

        # Нижний колонтитул
        self.setFont(FONT_BOLD, 8)
        self.setFillColor(colors.HexColor("#64748B"))
        self.drawString(40, 20, "HR EXIT INTELLIGENCE ENGINE  |  HACKATHON MVP")
        
        page_str = f"Слайд {self._pageNumber} из {total_pages}"
        self.drawRightString(PAGE_W - 40, 20, page_str)
        self.restoreState()

def generate_presentation(filename="presentation.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=landscape(A4),
        leftMargin=40,
        rightMargin=40,
        topMargin=36,
        bottomMargin=36
    )

    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        'CoverTitle',
        parent=styles['Normal'],
        fontName=FONT_BOLD,
        fontSize=24,
        leading=30,
        textColor=colors.HexColor("#1E293B"),
        spaceAfter=4
    )
    subtitle_style = ParagraphStyle(
        'CoverSubtitle',
        parent=styles['Normal'],
        fontName=FONT_BOLD,
        fontSize=11,
        leading=15,
        textColor=colors.HexColor("#4F46E5"),
        spaceAfter=12
    )
    slide_h1 = ParagraphStyle(
        'SlideH1',
        parent=styles['Normal'],
        fontName=FONT_BOLD,
        fontSize=18,
        leading=22,
        textColor=colors.HexColor("#0F172A"),
        spaceAfter=2
    )
    card_title = ParagraphStyle(
        'CardTitle',
        parent=styles['Normal'],
        fontName=FONT_BOLD,
        fontSize=10,
        leading=14,
        textColor=colors.HexColor("#1E293B"),
        spaceAfter=4
    )
    body_text = ParagraphStyle(
        'CardBody',
        parent=styles['Normal'],
        fontName=FONT_NORMAL,
        fontSize=9,
        leading=13,
        textColor=colors.HexColor("#334155")
    )

    story = []

    # ==================== СЛАЙД 1 ====================
    story.append(Paragraph("HR EXIT INTELLIGENCE ENGINE", title_style))
    story.append(Paragraph("Автоматизированный аудит и паспорт увольнений на базе YandexGPT", subtitle_style))
    story.append(Spacer(1, 8))

    col1 = [
        Paragraph("ПРОБЛЕМА БИЗНЕСА", ParagraphStyle('H1', parent=card_title, textColor=colors.HexColor("#BE123C"))),
        Spacer(1, 4),
        Paragraph("• Сотрудники скрывают реальные триггеры ухода за вежливыми формулировками («хочу развиваться»).", body_text),
        Paragraph("• Ручной анализ диалогов отнимает до 40 рабочих часов HR-отдела ежемесячно.", body_text),
        Paragraph("• Системные проблемы (микроменеджмент, бюрократия, разрывы в оплате) вскрываются слишком поздно.", body_text),
    ]
    col2 = [
        Paragraph("РЕШЕНИЕ И ЦЕННОСТЬ", ParagraphStyle('H2', parent=card_title, textColor=colors.HexColor("#047857"))),
        Spacer(1, 4),
        Paragraph("• Превращение сырого транскрипта в структурированный «Паспорт проблемы» за 4 секунды.", body_text),
        Paragraph("• Детекция скрытых эмоций (раздражение, апатия, тревога) и калибровка уровня риска (High/Med/Low).", body_text),
        Paragraph("• 3 готовых, неизбитых управленческих шага для топ-менеджмента без шаблонной воды.", body_text),
    ]

    t1 = Table([[col1, col2]], colWidths=[370, 370])
    t1.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), colors.HexColor("#FFF1F2")),
        ('BACKGROUND', (1,0), (1,0), colors.HexColor("#ECFDF5")),
        ('BOX', (0,0), (0,0), 1, colors.HexColor("#FECDD3")),
        ('BOX', (1,0), (1,0), 1, colors.HexColor("#A7F3D0")),
        ('PADDING', (0,0), (-1,-1), 14),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(t1)
    story.append(PageBreak())

    # ==================== СЛАЙД 2 ====================
    story.append(Paragraph("02. АРХИТЕКТУРА: ДВУХУРОВНЕВЫЙ NLP-ПАЙПЛАЙН", slide_h1))
    story.append(Paragraph("Принцип Zero-Hallucination: разделение вычисления фактов и рассуждений LLM", subtitle_style))
    story.append(Spacer(1, 8))

    s1 = [
        Paragraph("1. Детерминированный NLP", card_title),
        Paragraph("FastAPI принимает текст. Модуль <i>pymorphy3</i> нормализует леммы и вычисляет точную частоту ключевых понятий. Модель не выдумывает цифры.", body_text)
    ]
    s2 = [
        Paragraph("2. Context Injection & LLM", card_title),
        Paragraph("Сборка системного Few-Shot промпта с жесткой схемой. <i>YandexGPT</i> (температура 0.1) определяет скрытые эмоции и привязывает цитаты-якоря.", body_text)
    ]
    s3 = [
        Paragraph("3. Контракт и Хранилище", card_title),
        Paragraph("Строгая валидация ответа через <i>Pydantic v2</i>. Сохранение сырых диалогов и JSON-паспортов в <i>SQLite</i> для накопления аналитики.", body_text)
    ]

    t2 = Table([[s1, s2, s3]], colWidths=[246, 246, 246])
    t2.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#E2E8F0")),
        ('PADDING', (0,0), (-1,-1), 12),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(t2)
    story.append(Spacer(1, 12))

    tech = [
        Paragraph("ТЕХНОЛОГИЧЕСКИЙ СТЕК РЕШЕНИЯ", card_title),
        Paragraph("<b>Backend:</b> Python 3.13, FastAPI, Pydantic v2, Uvicorn   |   <b>AI Core:</b> YandexGPT API (Yandex Cloud), pymorphy3<br/><b>Frontend:</b> React 18 SPA, Tailwind CSS, Lucide Icons   |   <b>База данных:</b> SQLite3 (интервью и история)", body_text)
    ]
    t_tech = Table([[tech]], colWidths=[742])
    t_tech.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#EEF2FF")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#C7D2FE")),
        ('PADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(t_tech)
    story.append(PageBreak())

    # ==================== СЛАЙД 3 ====================
    story.append(Paragraph("03. ИНТЕРФЕЙС И РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ", slide_h1))
    story.append(Paragraph("Практический инструмент для HR-директора и топ-менеджмента", subtitle_style))
    story.append(Spacer(1, 8))

    ui1 = [
        Paragraph("ИНТЕРАКТИВНАЯ РАЗМЕТКА ТЕКСТА", ParagraphStyle('U1', parent=card_title, textColor=colors.HexColor("#4F46E5"))),
        Paragraph("Фронтенд в реальном времени сопоставляет паспорт с текстом:", body_text),
        Paragraph("• <b>Красный:</b> Системные проблемы и зоны боли с цитатой", body_text),
        Paragraph("• <b>Зеленый:</b> Сильные стороны компании и менторство", body_text),
        Paragraph("• <b>Оранжевый:</b> Ключевой триггер увольнения", body_text),
    ]
    ui2 = [
        Paragraph("САЙДБАР ИСТОРИИ И ЭКСПОРТ", ParagraphStyle('U2', parent=card_title, textColor=colors.HexColor("#4F46E5"))),
        Paragraph("• Мгновенное переключение между историческими отчетами без повторного вызова нейросети.", body_text),
        Paragraph("• Бейджи риска (High / Medium / Low) прямо в ленте.", body_text),
        Paragraph("• Экспорт готового паспорта в формат JSON одним кликом.", body_text),
    ]

    t3 = Table([[ui1, ui2]], colWidths=[370, 370])
    t3.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.white),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#CBD5E1")),
        ('PADDING', (0,0), (-1,-1), 14),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(t3)
    story.append(Spacer(1, 12))

    res_box = [
        Paragraph("ИТОГИ СТРЕСС-ТЕСТА (10 РЕАЛЬНЫХ КЕЙСОВ)", card_title),
        Paragraph("Система валидирована на 10 сценариях (токсичные руководители, карьерный потолок, выгорание, оффер +40%). Средняя скорость анализа — <b>4.2 секунды</b>. Полное покрытие сквозными тестами (pytest: 9 из 9 passed).", body_text)
    ]
    t_res = Table([[res_box]], colWidths=[742])
    t_res.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F1F5F9")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#CBD5E1")),
        ('PADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(t_res)
    story.append(PageBreak())

    # ==================== СЛАЙД 4 ====================
    story.append(Paragraph("04. ЭФФЕКТ ДЛЯ БИЗНЕСА И РАЗВИТИЕ (ROADMAP)", slide_h1))
    story.append(Paragraph("Измеримый ROI и масштабирование системы на всю компанию", subtitle_style))
    story.append(Spacer(1, 8))

    eff = [
        Paragraph("БИЗНЕС-ЭФФЕКТ (ROI)", ParagraphStyle('E1', parent=card_title, textColor=colors.HexColor("#047857"))),
        Spacer(1, 4),
        Paragraph("• <b>Экономия 85% времени:</b> 4 секунды на анализ вместо 30-40 минут ручного изучения интервью.", body_text),
        Paragraph("• <b>Раннее купирование оттока:</b> топ-менеджмент видит системный кризис до ухода ключевых команд.", body_text),
        Paragraph("• <b>Качественные данные:</b> алгоритм фильтрует социальную желательность и вскрывает Root Cause.", body_text),
    ]
    next_steps = [
        Paragraph("ПЛАН РАЗВИТИЯ (NEXT STEPS)", ParagraphStyle('N1', parent=card_title, textColor=colors.HexColor("#4F46E5"))),
        Spacer(1, 4),
        Paragraph("• <b>BI-дашборд срезов:</b> сквозная аналитика по подразделениям для выявления токсичных отделов.", body_text),
        Paragraph("• <b>RAG по политикам компании:</b> генерация рекомендаций с учетом грейдов и лимитов ФОТ.", body_text),
        Paragraph("• <b>Интеграция с корпоративной связью:</b> автоимпорт транскриптов из Zoom/Meet через вебхуки.", body_text),
    ]

    t4 = Table([[eff, next_steps]], colWidths=[370, 370])
    t4.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), colors.HexColor("#ECFDF5")),
        ('BACKGROUND', (1,0), (1,0), colors.HexColor("#EEF2FF")),
        ('BOX', (0,0), (0,0), 1, colors.HexColor("#A7F3D0")),
        ('BOX', (1,0), (1,0), 1, colors.HexColor("#C7D2FE")),
        ('PADDING', (0,0), (-1,-1), 14),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(t4)

    doc.build(story, canvasmaker=PresentationCanvas)
    print(f"Готово! Презентация сохранена в файл: {os.path.abspath(filename)}")

if __name__ == "__main__":
    generate_presentation("presentation.pdf")