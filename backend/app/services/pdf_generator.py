import os
import logging
from typing import Dict, Any, List
from jinja2 import Environment, FileSystemLoader
from ..core.config import settings

logger = logging.getLogger(__name__)

class PDFGeneratorService:
    @classmethod
    def generate_mom_pdf(
        cls,
        meeting_id: str,
        title: str,
        date_str: str,
        summary: Dict[str, Any],
        participants: List[Dict[str, Any]],
        speaker_mapping: Dict[str, str] = None
    ) -> str:
        """
        Renders the Executive English Minutes of Meeting (MoM) HTML template
        and compiles it into a high-quality PDF using WeasyPrint.
        """
        import weasyprint

        # Apply speaker mapping if provided
        processed_summary = dict(summary)
        if speaker_mapping:
            # Remap action items owners if matching speaker labels
            if "action_items" in processed_summary:
                updated_actions = []
                for item in processed_summary["action_items"]:
                    item_copy = dict(item)
                    owner = item_copy.get("owner", "")
                    if owner in speaker_mapping:
                        item_copy["owner"] = speaker_mapping[owner]
                    updated_actions.append(item_copy)
                processed_summary["action_items"] = updated_actions

        template_dir = os.path.join(os.path.dirname(__file__), "..", "templates")
        env = Environment(loader=FileSystemLoader(template_dir))
        template = env.get_template("mom_template.html")

        context = {
            "meeting": {
                "id": meeting_id,
                "title": title,
                "date_str": date_str,
            },
            "summary": processed_summary,
            "participants": participants,
        }

        rendered_html = template.render(**context)

        output_filename = f"mom_{meeting_id}.pdf"
        output_path = os.path.join(settings.PDF_STORAGE_DIR, output_filename)
        os.makedirs(settings.PDF_STORAGE_DIR, exist_ok=True)

        logger.info(f"Compiling WeasyPrint PDF for meeting {meeting_id} -> {output_path}")
        weasyprint.HTML(string=rendered_html).write_pdf(output_path)
        logger.info(f"PDF generated successfully at {output_path}")

        return output_path
