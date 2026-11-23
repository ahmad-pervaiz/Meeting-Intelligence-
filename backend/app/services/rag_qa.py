import logging
from typing import List, Dict, Any
from ..core.config import settings
from ..models.schemas import AskQuestionResponse, Citation
from .vector_store import VectorStoreService

logger = logging.getLogger(__name__)

RAG_PROMPT_TEMPLATE = """You are an intelligent corporate meeting assistant.
Answer the user's question accurately in 100% PROFESSIONAL ENGLISH based ONLY on the provided meeting context.
If the answer is not mentioned in the context, clearly state: "This topic was not discussed in the meeting transcript."
Include relevant speaker references and timestamps in your English explanation.

CONTEXT:
{context}

QUESTION:
{question}

PROFESSIONAL ENGLISH ANSWER:"""

class RAGQAService:
    @classmethod
    def answer_question(cls, meeting_id: str, question: str) -> AskQuestionResponse:
        """
        Retrieves relevant transcript chunks and generates a grounded English response with citations.
        """
        matches = VectorStoreService.search(meeting_id, question, top_k=3)
        
        citations = [
            Citation(
                speaker=m["speaker"],
                start_time=m["start_time"],
                end_time=m["end_time"],
                timestamp_str=m["timestamp_str"],
                text=m["text"]
            )
            for m in matches
        ]

        if not matches:
            return AskQuestionResponse(
                answer="No relevant meeting segments were found for this query.",
                citations=[]
            )

        context_blocks = "\n".join([
            f"[{m['timestamp_str']}] {m['speaker']}: {m['text']}"
            for m in matches
        ])

        # Attempt Groq LLM
        if settings.GROQ_API_KEY and settings.GROQ_API_KEY.strip():
            try:
                from groq import Groq
                client = Groq(api_key=settings.GROQ_API_KEY)
                prompt = RAG_PROMPT_TEMPLATE.format(context=context_blocks, question=question)
                resp = client.chat.completions.create(
                    model=settings.GROQ_MODEL,
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.1,
                    max_tokens=600
                )
                answer = resp.choices[0].message.content.strip()
                return AskQuestionResponse(answer=answer, citations=citations)
            except Exception as e:
                logger.error(f"Groq RAG answer failed: {e}")

        # Attempt Gemini LLM
        if settings.GEMINI_API_KEY and settings.GEMINI_API_KEY.strip():
            try:
                import google.generativeai as genai
                genai.configure(api_key=settings.GEMINI_API_KEY)
                model = genai.GenerativeModel(settings.GEMINI_MODEL)
                prompt = RAG_PROMPT_TEMPLATE.format(context=context_blocks, question=question)
                resp = model.generate_content(prompt)
                answer = resp.text.strip()
                return AskQuestionResponse(answer=answer, citations=citations)
            except Exception as e:
                logger.error(f"Gemini RAG answer failed: {e}")

        # Fallback response grounded directly on top match
        top_match = matches[0]
        answer = (
            f"Based on the meeting transcript at [{top_match['timestamp_str']}], "
            f"{top_match['speaker']} discussed: \"{top_match['text']}\"."
        )
        return AskQuestionResponse(answer=answer, citations=citations)
