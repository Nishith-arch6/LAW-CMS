"""
FastAPI wrapper for the case-type classifier.
Caches the loaded model in memory for the app lifetime.
"""

import os
import sys
import logging

logger = logging.getLogger("legal_cms.ml")

ML_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "ml"))
sys.path.insert(0, ML_DIR)

_loaded = False


def load_models():
    global _loaded
    if _loaded:
        return
    try:
        from case_classifier.predict import load_model as _load

        _load()
        _loaded = True
        logger.info("Case classifier models loaded successfully")
    except Exception as e:
        logger.warning("Failed to load case classifier models: %s", e)


def classify_text(text: str) -> dict:
    from case_classifier.predict import predict_category

    return predict_category(text)


def suggest_category(title: str, description: str = "") -> dict:
    combined = f"{title}. {description}".strip()
    if not combined:
        return {
            "category": "OTHER",
            "confidence": 0.0,
            "alternatives": [],
        }
    from case_classifier.predict import predict_category, predict_top_k

    result = predict_category(combined)
    alternatives = predict_top_k(combined, k=4)
    result["alternatives"] = [a for a in alternatives if a["category"] != result["category"]][:3]
    return result
