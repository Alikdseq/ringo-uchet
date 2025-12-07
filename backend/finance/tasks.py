from __future__ import annotations

import logging

from django.conf import settings
from django.core.files.base import ContentFile
from django.template.loader import render_to_string
from django.utils import timezone

from celery import shared_task

from .models import DocumentTemplate, Invoice

logger = logging.getLogger(__name__)

# Lazy import WeasyPrint to avoid breaking Django startup if dependencies are missing
try:
    from weasyprint import HTML

    WEASYPRINT_AVAILABLE = True
except (ImportError, OSError) as e:
    logger.warning(f"WeasyPrint not available: {e}. PDF generation will be disabled.")
    WEASYPRINT_AVAILABLE = False
    HTML = None


@shared_task(bind=True)
def generate_invoice_pdf(self, invoice_id: int, template_slug: str = "invoice-default") -> dict[str, str]:
    if not WEASYPRINT_AVAILABLE:
        error_msg = "WeasyPrint is not available. Please install system dependencies."
        logger.error(error_msg)
        raise RuntimeError(error_msg)

    invoice = Invoice.objects.select_related("order__client").get(id=invoice_id)
    template = (
        DocumentTemplate.objects.filter(slug=template_slug, is_active=True)
        .order_by("-version")
        .first()
    )
    template_path = template.template_path if template else "invoices/default.html"

    order = invoice.order
    snapshot = order.price_snapshot or {}
    context = {
        "invoice": invoice,
        "client": order.client,
        "order": order,
        "positions": snapshot.get("positions", []),
        "summary": snapshot.get("summary", {}),
        "issued_at": invoice.issued_at.strftime("%d.%m.%Y"),
        "company": {
            "name": settings.APP_CONFIG.get("company_name", "Ringo Uchet"),
            "address": settings.APP_CONFIG.get("company_address", "—"),
            "phone": settings.APP_CONFIG.get("company_phone", "—"),
            "email": settings.APP_CONFIG.get("company_email", "—"),
            "representative": settings.APP_CONFIG.get("company_representative", "—"),
        },
        "payment_link": settings.APP_CONFIG.get("payment_link", "https://example.com/pay"),
    }

    html = render_to_string(template_path, context)
    pdf_bytes = HTML(string=html, base_url="").write_pdf()
    filename = f"{invoice.number or Invoice.generate_number()}.pdf"
    invoice.pdf_file.save(filename, ContentFile(pdf_bytes), save=True)
    invoice.pdf_url = invoice.pdf_file.url if invoice.pdf_file else invoice.pdf_url
    invoice.payment_status = invoice.payment_status or "pending"
    invoice.metadata["generated_at"] = timezone.now().isoformat()
    invoice.save(update_fields=["pdf_file", "pdf_url", "payment_status", "metadata"])
    return {"invoice_id": invoice.id, "pdf_url": invoice.pdf_url}

