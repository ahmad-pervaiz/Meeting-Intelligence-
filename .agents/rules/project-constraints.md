# Project & Hardware Constraints (Linux / Dell XPS 13 - 16GB RAM CPU)
- OS & Hardware: Linux (x86_64), 16GB RAM, NO NVIDIA GPU (CPU-only).
- Speech-to-Text: MUST use `faster-whisper` with `deepdml/faster-whisper-large-v3-turbo-ct2` (or `"large-v3-turbo"`), `device="cpu"`, `compute_type="int8"`, and `cpu_threads=4` to stay under 1.6GB RAM. Never load PyTorch `fp16` or `device="cuda"`.
- Python Environment: Always create and use a dedicated `venv` (`python3 -m venv .venv`) and target Python 3.10 or 3.11.
- Languages: Input audio is Urdu, English, or mixed Urdu-English code-switching (`language=None` or `"ur"`). All LLM summaries, action items, emails, and PDF outputs MUST be strictly in English.
- Zero Paid APIs: Use only free/open-source tiers (Groq/Gemini free API for LLM, Supabase free tier or local SQLite/ChromaDB for dev, Resend/Brevo/Gmail SMTP for email, WeasyPrint for PDF).
