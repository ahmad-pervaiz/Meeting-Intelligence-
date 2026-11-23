import logging
import os
from typing import List, Dict, Any, Optional
from ..core.config import settings

logger = logging.getLogger(__name__)

class VectorStoreService:
    _embedder = None
    _chroma_client = None

    @classmethod
    def get_embedder(cls):
        """
        Lazy-loads multilingual sentence transformer embedder on CPU.
        Lightweight (~470MB) and handles Urdu + English cross-lingual similarity.
        """
        if cls._embedder is None:
            try:
                from sentence_transformers import SentenceTransformer
                logger.info(f"Loading multilingual embedding model: {settings.EMBEDDING_MODEL_NAME} on CPU")
                cls._embedder = SentenceTransformer(settings.EMBEDDING_MODEL_NAME, device="cpu")
                logger.info("SentenceTransformer model loaded.")
            except Exception as e:
                logger.warning(f"Could not load SentenceTransformer ({e}). Fallback to token similarity.")
                cls._embedder = None
        return cls._embedder

    @classmethod
    def get_collection(cls, meeting_id: str):
        """
        Gets or creates a ChromaDB collection for the meeting.
        """
        try:
            import chromadb
            if cls._chroma_client is None:
                chroma_path = os.path.join(settings.STORAGE_DIR, "chromadb")
                os.makedirs(chroma_path, exist_ok=True)
                cls._chroma_client = chromadb.PersistentClient(path=chroma_path)
            
            clean_id = f"meeting_{meeting_id.replace('-', '_')}"
            return cls._chroma_client.get_or_create_collection(
                name=clean_id,
                metadata={"hnsw:space": "cosine"}
            )
        except Exception as e:
            logger.warning(f"ChromaDB initialization error: {e}. Falling back to in-memory store.")
            return None

    @classmethod
    def index_transcript(cls, meeting_id: str, segments: List[Dict[str, Any]]) -> int:
        """
        Chunks transcript segments into overlapping windows with timestamps and indexes them.
        """
        if not segments:
            return 0

        # Create chunks (window of 2-3 segments with overlapping context)
        chunks = []
        for i in range(0, len(segments)):
            sub_segs = segments[i:min(i + 3, len(segments))]
            text = " ".join([s["text"] for s in sub_segs])
            start = sub_segs[0]["start_time"]
            end = sub_segs[-1]["end_time"]
            speaker = sub_segs[0].get("speaker_label", "SPEAKER_00")
            time_range = f"{cls._format_time(start)} - {cls._format_time(end)}"
            
            chunks.append({
                "id": f"chunk_{meeting_id}_{i}",
                "text": text,
                "speaker": speaker,
                "start": start,
                "end": end,
                "timestamp_range": time_range
            })

        collection = cls.get_collection(meeting_id)
        if collection:
            embedder = cls.get_embedder()
            docs = [c["text"] for c in chunks]
            metadatas = [
                {
                    "speaker": c["speaker"],
                    "start": c["start"],
                    "end": c["end"],
                    "timestamp_range": c["timestamp_range"]
                }
                for c in chunks
            ]
            ids = [c["id"] for c in chunks]

            if embedder:
                embeddings = embedder.encode(docs, convert_to_numpy=True).tolist()
                collection.upsert(ids=ids, documents=docs, metadatas=metadatas, embeddings=embeddings)
            else:
                collection.upsert(ids=ids, documents=docs, metadatas=metadatas)

            logger.info(f"Indexed {len(chunks)} chunks into ChromaDB for meeting {meeting_id}.")
        return len(chunks)

    @classmethod
    def search(cls, meeting_id: str, query: str, top_k: int = 3) -> List[Dict[str, Any]]:
        """
        Executes semantic search against the meeting's vector index.
        """
        collection = cls.get_collection(meeting_id)
        if collection is None:
            return []

        try:
            embedder = cls.get_embedder()
            if embedder:
                q_emb = embedder.encode([query], convert_to_numpy=True).tolist()
                results = collection.query(query_embeddings=q_emb, n_results=top_k)
            else:
                results = collection.query(query_texts=[query], n_results=top_k)

            matches = []
            if results and results.get("documents") and len(results["documents"]) > 0:
                docs = results["documents"][0]
                metas = results["metadatas"][0]
                for doc, meta in zip(docs, metas):
                    matches.append({
                        "text": doc,
                        "speaker": meta.get("speaker", "SPEAKER_00"),
                        "start_time": meta.get("start", 0.0),
                        "end_time": meta.get("end", 0.0),
                        "timestamp_str": meta.get("timestamp_range", ""),
                    })
            return matches
        except Exception as e:
            logger.error(f"Vector search failed: {e}")
            return []

    @staticmethod
    def _format_time(seconds: float) -> str:
        m, s = divmod(int(seconds), 60)
        return f"{m:02d}:{s:02d}"
