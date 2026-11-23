# 🎙️ Bilingual Meeting Intelligence & Automated Follow-Up System

[![Python 3.11+](https://img.shields.io/badge/Python-3.11%2B-blue?logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115%2B-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Flutter](https://img.shields.io/badge/Flutter-Android%20(API%2035)-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![ASR Model](https://img.shields.io/badge/ASR-Whisper%20Large--v3--Turbo%20(INT8)-orange?logo=huggingface&logoColor=white)](https://huggingface.co/openai/whisper-large-v3-turbo)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An end-to-end, **100% free-tier** full-stack mobile and AI backend application that records or ingests **Urdu, English, and mixed Urdu–English (code-switched)** meetings, identifies speakers, indexes searchable transcripts via RAG, synthesizes structured **English Minutes of Meeting (MoM) PDFs**, and dispatches tailored follow-up emails and WhatsApp shares to **both attending and absent participants**.

---

## ✨ Key Features

- **Bilingual Audio Capture & Ingestion:** Record live meetings directly from Android (with mandatory Google Play microphone consent prompt) or upload existing `.mp3`, `.wav`, or `.m4a` files.
- **CPU-Optimized Multilingual ASR:** Powered by `openai/whisper-large-v3-turbo` via `faster-whisper` (`INT8` CTranslate2 quantization), tuned to run smoothly on standard laptops (e.g., Dell XPS 13, 16 GB RAM, CPU-only) as well as free cloud instances.
- **Speaker Diarization & Roster Mapping:** Separates speaker turns (`SPEAKER_00`, `SPEAKER_01`) using `pyannote/speaker-diarization-3.1` and lets organizers map anonymous labels to real participants before publishing.
- **Cross-Lingual English Synthesis (LLM + RAG):** Converts mixed Urdu/English discussions into grounded, structured **English** outputs—Executive Summary, Key Decisions, Action Items (`Task`, `Owner`, `Deadline`, `Timestamp`), and Open Questions—plus interactive timestamp-cited Q&A.
- **Automated English PDF & Dual-Track Follow-Up:** Compiles a clean English MoM PDF via `WeasyPrint` and sends differentiated emails (one for **Attendees**, one for **Absentees**) via free email APIs or one-tap mobile sharing (`share_plus` for WhatsApp/Gmail).

---

## 🏗️ System Architecture

```text
┌───────────────────────────┐        Multipart Audio + Roster        ┌──────────────────────────────────────┐
│   Flutter Android App     │ ─────────────────────────────────────► │          FastAPI Backend             │
│  • Live Mic / File Upload │                                        │  1. FFmpeg (16kHz Mono WAV)          │
│  • Attended/Absent Roster │ ◄───────────────────────────────────── │  2. faster-whisper (large-v3-turbo)  │
│  • Speaker Name Mapping   │        JSON Minutes + English PDF      │  3. pyannote Diarization             │
│  • RAG Q&A & PDF Viewer   │                                        │  4. Multilingual Embeddings + RAG    │
│  • Email / WhatsApp Share │                                        │  5. Groq/Gemini LLM → English JSON   │
└───────────────────────────┘                                        │  6. WeasyPrint PDF + Resend/SMTP     │
                                                                     └──────────────────────────────────────┘
