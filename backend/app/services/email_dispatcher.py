import os
import smtplib
import base64
import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
from typing import List, Dict, Any
from ..core.config import settings

logger = logging.getLogger(__name__)

ATTENDED_HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
    <h2 style="color: #2b6cb0;">Meeting Summary & Follow-Up: {meeting_title}</h2>
    <p>Dear {name},</p>
    <p>Thank you for attending today's meeting. Below is a concise overview of the agreed outcomes and your assigned action items.</p>
    
    <div style="background-color: #f7fafc; padding: 15px; border-left: 4px solid #3182ce; margin: 15px 0;">
      <h3 style="margin-top: 0; color: #2d3748;">Executive Summary</h3>
      <p style="margin-bottom: 0;">{executive_summary}</p>
    </div>

    <h3>Your Action Items & Deadlines</h3>
    {action_items_html}

    <p style="margin-top: 20px;">The complete executive <strong>Minutes of Meeting (MoM) PDF</strong> is attached for your records.</p>
    
    <hr style="border: none; border-top: 1px solid #edf2f7; margin: 20px 0;">
    <p style="font-size: 12px; color: #718096;">Generated automatically by Bilingual Meeting Intelligence System.</p>
  </div>
</body>
</html>"""

ABSENT_HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
    <h2 style="color: #c53030;">Meeting Catch-Up Briefing: {meeting_title}</h2>
    <p>Dear {name},</p>
    <p>We missed you at today's meeting. Here is an executive briefing on the key decisions made and upcoming milestones so you stay fully aligned with the team.</p>
    
    <div style="background-color: #f7fafc; padding: 15px; border-left: 4px solid #e53e3e; margin: 15px 0;">
      <h3 style="margin-top: 0; color: #2d3748;">Executive Summary</h3>
      <p style="margin-bottom: 0;">{executive_summary}</p>
    </div>

    <h3>Key Decisions Finalized</h3>
    {decisions_html}

    <p style="margin-top: 20px;">Please find the complete official <strong>Minutes of Meeting (MoM) PDF</strong> attached to review the full discussions.</p>
    
    <hr style="border: none; border-top: 1px solid #edf2f7; margin: 20px 0;">
    <p style="font-size: 12px; color: #718096;">Generated automatically by Bilingual Meeting Intelligence System.</p>
  </div>
</body>
</html>"""

class EmailDispatcherService:
    @classmethod
    def distribute_meeting_mom(
        cls,
        meeting_title: str,
        summary: Dict[str, Any],
        participants: List[Dict[str, Any]],
        pdf_path: str,
        custom_message: str = None
    ) -> Dict[str, Any]:
        """
        Distributes tailored English emails with attached PDF to all participants.
        Uses Resend API if configured, otherwise falls back to Gmail SMTP or local log simulation.
        """
        results = []
        attended_count = 0
        absent_count = 0

        # Read PDF binary
        pdf_bytes = b""
        pdf_name = os.path.basename(pdf_path)
        if os.path.exists(pdf_path):
            with open(pdf_path, "rb") as f:
                pdf_bytes = f.read()
        else:
            logger.warning(f"PDF file not found at {pdf_path}. Email will be dispatched without attachment.")

        for p in participants:
            name = p.get("name", "Colleague")
            email = p.get("email")
            status = p.get("status", "Attended")

            if not email:
                continue

            if status == "Attended":
                subject = f"Meeting Minutes & Action Items: {meeting_title}"
                html_body = cls._build_attended_email(name, meeting_title, summary, custom_message)
                attended_count += 1
            else:
                subject = f"Catch-Up Briefing: {meeting_title}"
                html_body = cls._build_absent_email(name, meeting_title, summary, custom_message)
                absent_count += 1

            send_status = cls._send_email(
                to_email=email,
                subject=subject,
                html_content=html_body,
                pdf_bytes=pdf_bytes,
                pdf_name=pdf_name
            )
            results.append({
                "recipient": email,
                "name": name,
                "status": status,
                "delivery": send_status
            })

        return {
            "status": "completed",
            "recipients_count": len(results),
            "attended_sent": attended_count,
            "absent_sent": absent_count,
            "details": results
        }

    @classmethod
    def _build_attended_email(cls, name: str, title: str, summary: Dict[str, Any], custom_msg: str = None) -> str:
        exec_sum = summary.get("executive_summary", "")
        action_items = summary.get("action_items", [])
        
        # Filter action items for this participant if name matches
        relevant_actions = [a for a in action_items if name.lower() in a.get("owner", "").lower()]
        if not relevant_actions:
            relevant_actions = action_items

        if relevant_actions:
            items_list = "".join([
                f"<li><strong>{a.get('task')}</strong> — Owner: {a.get('owner')} | Deadline: {a.get('deadline')}</li>"
                for a in relevant_actions
            ])
            action_html = f"<ul style='padding-left: 20px;'>{items_list}</ul>"
        else:
            action_html = "<p>No specific action items assigned to you.</p>"

        if custom_msg:
            exec_sum = f"<em>Note from Organizer:</em> {custom_msg}<br><br>{exec_sum}"

        return ATTENDED_HTML_TEMPLATE.format(
            name=name,
            meeting_title=title,
            executive_summary=exec_sum,
            action_items_html=action_html
        )

    @classmethod
    def _build_absent_email(cls, name: str, title: str, summary: Dict[str, Any], custom_msg: str = None) -> str:
        exec_sum = summary.get("executive_summary", "")
        decisions = summary.get("decisions", [])

        if decisions:
            items_list = "".join([
                f"<li><strong>{d.get('decision')}</strong> <span style='color: #718096; font-size: 11px;'>[{d.get('timestamp')}]</span></li>"
                for d in decisions
            ])
            decisions_html = f"<ul style='padding-left: 20px;'>{items_list}</ul>"
        else:
            decisions_html = "<p>Please refer to the attached PDF for comprehensive discussion notes.</p>"

        if custom_msg:
            exec_sum = f"<em>Note from Organizer:</em> {custom_msg}<br><br>{exec_sum}"

        return ABSENT_HTML_TEMPLATE.format(
            name=name,
            meeting_title=title,
            executive_summary=exec_sum,
            decisions_html=decisions_html
        )

    @classmethod
    def _send_email(cls, to_email: str, subject: str, html_content: str, pdf_bytes: bytes, pdf_name: str) -> str:
        # 1. Resend API
        if settings.RESEND_API_KEY and settings.RESEND_API_KEY.strip():
            try:
                import resend
                resend.api_key = settings.RESEND_API_KEY
                attachments = []
                if pdf_bytes:
                    attachments.append({
                        "filename": pdf_name,
                        "content": list(pdf_bytes)
                    })
                
                params = {
                    "from": settings.EMAIL_FROM,
                    "to": [to_email],
                    "subject": subject,
                    "html": html_content,
                    "attachments": attachments
                }
                resend.Emails.send(params)
                logger.info(f"Email sent to {to_email} via Resend API")
                return "sent_resend"
            except Exception as e:
                logger.error(f"Resend dispatch error: {e}. Attempting SMTP fallback...")

        # 2. SMTP Fallback
        if settings.SMTP_USERNAME and settings.SMTP_PASSWORD:
            try:
                msg = MIMEMultipart()
                msg["From"] = settings.SMTP_USERNAME
                msg["To"] = to_email
                msg["Subject"] = subject
                msg.attach(MIMEText(html_content, "html"))

                if pdf_bytes:
                    part = MIMEApplication(pdf_bytes, Name=pdf_name)
                    part["Content-Disposition"] = f'attachment; filename="{pdf_name}"'
                    msg.attach(part)

                with smtplib.SMTP(settings.SMTP_SERVER, settings.SMTP_PORT) as server:
                    if settings.SMTP_USE_TLS:
                        server.starttls()
                    server.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
                    server.send_message(msg)

                logger.info(f"Email sent to {to_email} via SMTP")
                return "sent_smtp"
            except Exception as e:
                logger.error(f"SMTP dispatch error: {e}")
                return f"failed_smtp: {str(e)}"

        # 3. Development / Zero-Config Simulation Fallback
        logger.info(f"[SIMULATION] Email prepared for {to_email} with subject '{subject}' and {len(pdf_bytes)} bytes PDF attached.")
        return "simulated_success"
