from __future__ import annotations

import io
from datetime import datetime
from decimal import Decimal
from typing import Iterable, Sequence

import tablib
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


def export_dataset(dataset: tablib.Dataset, export_format: str) -> tuple[bytes, str, str]:
    if export_format == "xlsx":
        data = dataset.export("xlsx")
        return data, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "xlsx"
    if export_format == "csv":
        data = dataset.export("csv").encode("utf-8")
        return data, "text/csv", "csv"
    if export_format == "pdf":
        buffer = io.BytesIO()
        pdf = canvas.Canvas(buffer, pagesize=A4)
        pdf.setFont("Helvetica", 10)
        width, height = A4
        y = height - 40
        for row in dataset.dict:
            line = ", ".join(f"{k}: {v}" for k, v in row.items())
            pdf.drawString(40, y, line[:120])
            y -= 14
            if y < 40:
                pdf.showPage()
                pdf.setFont("Helvetica", 10)
                y = height - 40
        pdf.save()
        buffer.seek(0)
        return buffer.read(), "application/pdf", "pdf"
    raise ValueError("Unsupported export format")


def build_dataset(headers: Sequence[str], rows: Iterable[Sequence[str]]) -> tablib.Dataset:
    dataset = tablib.Dataset(headers=headers)
    for row in rows:
        dataset.append(row)
    return dataset


def generate_order_receipt_pdf(order) -> bytes:
    """Генерирует PDF чек для завершенной заявки."""
    import logging
    import os
    from orders.models import OrderItem, OrderStatusLog
    from catalog.models import Equipment
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    
    logger = logging.getLogger(__name__)
    
    # Проверяем, что заказ существует и имеет необходимые данные
    if not order:
        raise ValueError("Заказ не найден")
    
    if not order.number:
        raise ValueError("У заказа отсутствует номер")
    
    try:
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4, rightMargin=20*mm, leftMargin=20*mm, topMargin=20*mm, bottomMargin=20*mm)
        story = []
        styles = getSampleStyleSheet()
    except Exception as e:
        logger.error(f"Failed to initialize PDF components: {e}", exc_info=True)
        raise ValueError(f"Ошибка инициализации PDF: {str(e)}")
    
    # Регистрируем шрифты с поддержкой кириллицы
    font_name = 'Helvetica'  # По умолчанию
    font_bold_name = 'Helvetica-Bold'  # По умолчанию для жирного текста
    try:
        # Пробуем найти системные шрифты с поддержкой кириллицы
        font_configs = [
            {
                'regular': '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
                'bold': '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
            },
            {
                'regular': '/usr/share/fonts/TTF/DejaVuSans.ttf',
                'bold': '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf',
            },
            {
                'regular': 'C:/Windows/Fonts/arial.ttf',
                'bold': 'C:/Windows/Fonts/arialbd.ttf',
            },
            {
                'regular': 'C:/Windows/Fonts/arialuni.ttf',
                'bold': 'C:/Windows/Fonts/arialuni.ttf',  # Arial Unicode может не иметь отдельного жирного
            },
            {
                'regular': '/System/Library/Fonts/Supplemental/Arial.ttf',
                'bold': '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
            },
        ]
        
        for config in font_configs:
            regular_path = config['regular']
            bold_path = config.get('bold', regular_path)  # Если жирный не указан, используем обычный
            
            if os.path.exists(regular_path):
                try:
                    # Регистрируем обычный шрифт
                    pdfmetrics.registerFont(TTFont('CyrillicFont', regular_path))
                    font_name = 'CyrillicFont'
                    
                    # Пробуем зарегистрировать жирный вариант
                    if os.path.exists(bold_path) and bold_path != regular_path:
                        try:
                            pdfmetrics.registerFont(TTFont('CyrillicFont-Bold', bold_path))
                            font_bold_name = 'CyrillicFont-Bold'
                            logger.info(f"Registered Cyrillic fonts (regular and bold) from {regular_path}")
                        except Exception as e:
                            logger.warning(f"Failed to register bold font from {bold_path}: {e}, using regular for bold")
                            font_bold_name = 'CyrillicFont'  # Используем обычный для жирного
                    else:
                        # Если жирный файл не найден, используем обычный шрифт для жирного текста
                        font_bold_name = 'CyrillicFont'
                        logger.info(f"Registered Cyrillic font (regular only) from {regular_path}")
                    
                    break
                except Exception as e:
                    logger.warning(f"Failed to register font from {regular_path}: {e}")
                    continue
    except Exception as e:
        logger.warning(f"Font registration failed, using default: {e}")
        pass  # Используем стандартный шрифт
    
    # Функция для безопасного создания Paragraph с экранированием HTML
    def safe_paragraph(text, style):
        """Создает Paragraph с безопасной обработкой текста."""
        if not text:
            text = ""
        # Экранируем специальные символы HTML, но сохраняем теги <b>
        text = str(text)
        # Временно заменяем теги <b> и </b>
        text = text.replace("<b>", "___BOLD_START___").replace("</b>", "___BOLD_END___")
        # Экранируем остальные специальные символы
        text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        # Возвращаем теги <b>
        text = text.replace("___BOLD_START___", "<b>").replace("___BOLD_END___", "</b>")
        return Paragraph(text, style)
    
    # Заголовок
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=20,
        textColor=colors.HexColor('#1a1a1a'),
        spaceAfter=10,
        alignment=1,  # Center
        fontName=font_bold_name,  # Используем зарегистрированный жирный шрифт
        encoding='utf-8',
    )
    story.append(safe_paragraph("ЧЕК", title_style))
    story.append(Spacer(1, 5*mm))
    
    # Информация о заказе
    normal_style = ParagraphStyle(
        'Normal',
        parent=styles['Normal'],
        fontSize=10,
        fontName=font_name,
        encoding='utf-8',
    )
    
    info_style = ParagraphStyle(
        'Info',
        parent=styles['Normal'],
        fontSize=10,
        fontName=font_name,
        spaceAfter=4,
        encoding='utf-8',
    )
    
    # Безопасная обработка данных заказа
    order_number = str(order.number) if order.number else 'Не указан'
    story.append(safe_paragraph(f"<b>Номер заказа:</b> {order_number}", info_style))
    
    if order.client:
        try:
            client_name = str(order.client.name) if order.client.name else 'Не указан'
            story.append(safe_paragraph(f"<b>Клиент:</b> {client_name}", info_style))
            if order.client.phone:
                client_phone = str(order.client.phone)
                story.append(safe_paragraph(f"<b>Телефон:</b> {client_phone}", info_style))
        except Exception as e:
            logger.warning(f"Error processing client data: {e}")
            story.append(safe_paragraph(f"<b>Клиент:</b> Ошибка загрузки данных", info_style))
    
    address = str(order.address) if order.address else 'Не указан'
    story.append(safe_paragraph(f"<b>Адрес:</b> {address}", info_style))
    
    try:
        start_date = order.start_dt.strftime('%d.%m.%Y %H:%M') if order.start_dt else 'Не указана'
    except Exception as e:
        logger.warning(f"Error formatting start_dt: {e}")
        start_date = 'Не указана'
    story.append(safe_paragraph(f"<b>Дата начала:</b> {start_date}", info_style))
    
    try:
        end_date = order.end_dt.strftime('%d.%m.%Y %H:%M') if order.end_dt else 'Не указана'
    except Exception as e:
        logger.warning(f"Error formatting end_dt: {e}")
        end_date = 'Не указана'
    story.append(safe_paragraph(f"<b>Дата окончания:</b> {end_date}", info_style))
    
    # Получаем комментарий из последнего лога статуса при завершении
    try:
        # Используем prefetch_related если доступен, иначе обычный запрос
        if hasattr(order, '_prefetched_objects_cache') and 'status_logs' in order._prefetched_objects_cache:
            status_logs = order._prefetched_objects_cache['status_logs']
        else:
            status_logs = order.status_logs.all()
        
        completion_log = None
        for log in status_logs:
            if log.to_status == 'COMPLETED':
                if completion_log is None or (log.created_at and completion_log.created_at and log.created_at > completion_log.created_at):
                    completion_log = log
        
        if completion_log and completion_log.comment:
            story.append(Spacer(1, 3*mm))
            comment_style = ParagraphStyle(
                'Comment',
                parent=styles['Normal'],
                fontSize=10,
                fontName=font_name,
                textColor=colors.HexColor('#333333'),
                leftIndent=10,
                rightIndent=10,
                spaceAfter=5,
                encoding='utf-8',
            )
            comment_text = str(completion_log.comment) if completion_log.comment else ''
            if comment_text:
                story.append(safe_paragraph(f"<b>Комментарий:</b> {comment_text}", comment_style))
    except Exception as e:
        logger.warning(f"Failed to get completion comment: {e}", exc_info=True)
    
    story.append(Spacer(1, 5*mm))
    
    # Таблица позиций
    data = [['Наименование', 'Количество', 'Ед. изм.', 'Цена за ед.', 'Сумма']]
    
    # Используем total_amount из заявки для итоговой суммы
    calculated_total = Decimal("0.00")
    
    # Проверяем, что у заказа есть позиции
    try:
        # Используем prefetch_related если доступен
        if hasattr(order, '_prefetched_objects_cache') and 'items' in order._prefetched_objects_cache:
            items = list(order._prefetched_objects_cache['items'])
            logger.debug(f"Using prefetched items, count: {len(items)}")
        else:
            items = list(order.items.all().order_by('item_type', 'name_snapshot'))
            logger.debug(f"Fetched items from DB, count: {len(items)}")
    except Exception as e:
        logger.error(f"Error fetching order items: {e}", exc_info=True)
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        items = []
    
    if not items:
        logger.warning(f"Order {order.id} has no items")
        # Добавляем пустую строку, если нет позиций
        data.append(['Нет позиций', '', '', '', '0.00 ₽'])
    else:
        for item in items:
            try:
                metadata = item.metadata or {}
                discount = Decimal(str(item.discount or 0))
                
                # Нормализуем item_type (может быть строкой или enum)
                item_type_value = item.item_type
                if isinstance(item_type_value, str):
                    # Если это строка, пытаемся преобразовать в enum
                    try:
                        item_type_enum = OrderItem.ItemType(item_type_value)
                    except (ValueError, AttributeError):
                        # Если не удалось, используем строку как есть
                        item_type_enum = item_type_value
                else:
                    item_type_enum = item_type_value
                
                # Определяем тип позиции для отображения
                item_type_label = {
                    OrderItem.ItemType.EQUIPMENT: "Техника",
                    OrderItem.ItemType.SERVICE: "Услуга",
                    OrderItem.ItemType.MATERIAL: "Материал",
                }.get(item_type_enum if isinstance(item_type_enum, OrderItem.ItemType) else None, "Прочее")
                
                # Для материалов определяем подтип по категории
                item_type_str = item_type_enum.value if isinstance(item_type_enum, OrderItem.ItemType) else str(item_type_enum)
                if item_type_str == "material" or item_type_enum == OrderItem.ItemType.MATERIAL:
                    material_category = metadata.get("material_category", "")
                    category_labels = {
                        "soil": "Грунт",
                        "tool": "Инструмент",
                        "attachment": "Навеска",
                    }
                    if material_category in category_labels:
                        item_type_label = category_labels[material_category]
                
                name_snapshot = item.name_snapshot or "Не указано"
                name = f"{item_type_label}: {name_snapshot}"
                quantity_str = ""
                unit_str = item.unit or "-"
                price_str = ""
                line_total = Decimal("0.00")
                
                # Для техники используем правильный расчет: смены * daily_rate + часы * hourly_rate
                if item_type_str == "equipment" or item_type_enum == OrderItem.ItemType.EQUIPMENT:
                    shifts = Decimal(str(metadata.get("shifts", 0) or 0))
                    hours = Decimal(str(metadata.get("hours", 0) or 0))
                    daily_rate = Decimal(str(metadata.get("daily_rate", 0) or 0))
                    hourly_rate = Decimal(str(item.unit_price or 0))
                    
                    # Рассчитываем стоимость правильно
                    shifts_cost = shifts * daily_rate if daily_rate > 0 else Decimal("0")
                    hours_cost = hours * hourly_rate
                    line_total_before_discount = shifts_cost + hours_cost
                    
                    # Применяем скидку
                    if discount > 0:
                        discount_amount = line_total_before_discount * (discount / Decimal("100"))
                        line_total = line_total_before_discount - discount_amount
                    else:
                        line_total = line_total_before_discount
                    
                    # Формируем строку количества
                    parts = []
                    if shifts > 0:
                        parts.append(f"{int(shifts)} смен")
                    if hours > 0:
                        parts.append(f"{float(hours):.1f} ч")
                    
                    if parts:
                        quantity_str = ", ".join(parts)
                    else:
                        quantity_str = "1"
                    
                    # Формируем строку цены
                    price_parts = []
                    if shifts > 0 and daily_rate > 0:
                        price_parts.append(f"{int(shifts)} смен × {daily_rate:.2f} ₽")
                    if hours > 0 and hourly_rate > 0:
                        price_parts.append(f"{float(hours):.1f} ч × {hourly_rate:.2f} ₽")
                    
                    if price_parts:
                        price_str = " + ".join(price_parts)
                    else:
                        price_str = f"{hourly_rate:.2f} ₽"
                    
                    # Единица измерения
                    if shifts > 0:
                        unit_str = "смена" if shifts == 1 else "смены"
                    elif hours > 0:
                        unit_str = "час" if hours == 1 else "часа" if hours < 5 else "часов"
                else:
                    # Для других типов позиций (материалы, услуги)
                    quantity = Decimal(str(item.quantity or 0))
                    unit_price = Decimal(str(item.unit_price or 0))
                    quantity_str = f"{quantity:.2f}".rstrip('0').rstrip('.')
                    price_str = f"{unit_price:.2f} ₽"
                    line_total_before_discount = unit_price * quantity
                    
                    # Применяем скидку
                    if discount > 0:
                        discount_amount = line_total_before_discount * (discount / Decimal("100"))
                        line_total = line_total_before_discount - discount_amount
                    else:
                        line_total = line_total_before_discount
                
                calculated_total += line_total
                
                # Безопасная обработка строк для таблицы
                safe_name = str(name) if name else ""
                safe_quantity = str(quantity_str) if quantity_str else ""
                safe_unit = str(unit_str) if unit_str else "-"
                safe_price = str(price_str) if price_str else "0.00 ₽"
                safe_total = f"{line_total:.2f} ₽"
                
                data.append([
                    safe_name,
                    safe_quantity,
                    safe_unit,
                    safe_price,
                    safe_total
                ])
            except Exception as e:
                logger.error(f"Error processing item {item.id}: {e}", exc_info=True)
                # Добавляем строку с ошибкой вместо пропуска
                data.append([
                    f"Ошибка обработки позиции {item.id if item.id else 'unknown'}",
                    '',
                    '',
                    '',
                    '0.00 ₽'
                ])
    
    # Итоговая строка - используем total_amount из заявки
    final_total = order.total_amount if order.total_amount else calculated_total
    data.append(['', '', '', '<b>ИТОГО:</b>', f"<b>{final_total:.2f} ₽</b>"])
    
    # Создаем таблицу с использованием Paragraph для ячеек с текстом (для правильного переноса)
    try:
        # Преобразуем данные в Paragraph для правильного переноса текста
        table_data = []
        cell_style = ParagraphStyle(
            'TableCell',
            parent=styles['Normal'],
            fontSize=9,
            fontName=font_name,
            leading=11,
            encoding='utf-8',
        )
        cell_style_bold = ParagraphStyle(
            'TableCellBold',
            parent=styles['Normal'],
            fontSize=9,
            fontName=font_bold_name,  # Используем зарегистрированный жирный шрифт
            leading=11,
            encoding='utf-8',
        )
        
        for row_idx, row in enumerate(data):
            table_row = []
            for col_idx, cell in enumerate(row):
                if row_idx == 0:  # Заголовок
                    table_row.append(safe_paragraph(str(cell), cell_style_bold))
                elif row_idx == len(data) - 1:  # Итоговая строка
                    table_row.append(safe_paragraph(str(cell), cell_style_bold))
                else:  # Обычные ячейки
                    table_row.append(safe_paragraph(str(cell), cell_style))
            table_data.append(table_row)
        
        table = Table(table_data, colWidths=[70*mm, 25*mm, 20*mm, 30*mm, 25*mm], repeatRows=1)
        table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#4a5568')),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'CENTER'),
        ('ALIGN', (2, 0), (2, -1), 'CENTER'),
        ('ALIGN', (3, 0), (3, -1), 'RIGHT'),
        ('ALIGN', (4, 0), (4, -1), 'RIGHT'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('FONTNAME', (0, 0), (-1, 0), font_bold_name),
        ('FONTSIZE', (0, 0), (-1, 0), 10),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
        ('TOPPADDING', (0, 0), (-1, 0), 12),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('BACKGROUND', (0, 1), (-1, -2), colors.white),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#cbd5e0')),
        ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, colors.HexColor('#f7fafc')]),
        ('BACKGROUND', (0, -1), (-1, -1), colors.HexColor('#e2e8f0')),
        ('FONTNAME', (0, -1), (-1, -1), font_bold_name),
        ('FONTSIZE', (0, -1), (-1, -1), 11),
        ('TOPPADDING', (0, -1), (-1, -1), 10),
        ('BOTTOMPADDING', (0, -1), (-1, -1), 10),
        ]))
        
        story.append(table)
    except Exception as e:
        logger.error(f"Error creating table: {e}", exc_info=True)
        # Добавляем простой текст вместо таблицы
        story.append(safe_paragraph("Ошибка при создании таблицы позиций", info_style))
    story.append(Spacer(1, 10*mm))
    
    # Подпись и дата
    date_style = ParagraphStyle(
        'Date',
        parent=styles['Normal'],
        fontSize=9,
        fontName=font_name,
        textColor=colors.HexColor('#666666'),
        alignment=2,  # Right
        encoding='utf-8',
    )
    date_text = f"Дата формирования чека: {datetime.now().strftime('%d.%m.%Y %H:%M')}"
    story.append(safe_paragraph(date_text, date_style))
    
    # Собираем PDF
    try:
        logger.info(f"Building PDF for order {order.id}, story elements count: {len(story)}")
        doc.build(story)
        buffer.seek(0)
        pdf_bytes = buffer.read()
        if not pdf_bytes:
            logger.error("Generated PDF is empty after build")
            raise ValueError("Generated PDF is empty")
        logger.info(f"PDF generated successfully, size: {len(pdf_bytes)} bytes")
        return pdf_bytes
    except Exception as e:
        logger.error(f"Failed to build PDF: {e}", exc_info=True)
        logger.error(f"Order ID: {order.id}, Order number: {order.number}")
        try:
            items_count = order.items.count()
            logger.error(f"Items count: {items_count}")
        except Exception as items_error:
            logger.error(f"Error getting items count: {items_error}")
        import traceback
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise ValueError(f"Ошибка генерации PDF: {str(e)}")

