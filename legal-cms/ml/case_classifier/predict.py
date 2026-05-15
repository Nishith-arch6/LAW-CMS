"""
Inference for case-type classification.
Loads the best saved model (sklearn or TensorFlow) and predicts categories.
"""

import json
import os
import pickle
import sys

import joblib
import numpy as np

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, PROJECT_ROOT)

MODEL_DIR = os.path.join(PROJECT_ROOT, "models", "case_classifier")

_model = None
_vectorizer = None
_tokenizer = None
_label_encoder = None
_framework = None


def _load_framework() -> str | None:
    path = os.path.join(MODEL_DIR, "framework.txt")
    if os.path.exists(path):
        with open(path) as f:
            return f.read().strip()
    return None


def _load_sklearn():
    global _model, _vectorizer, _label_encoder, _framework
    _model = joblib.load(os.path.join(MODEL_DIR, "sklearn_model.pkl"))
    _vectorizer = joblib.load(os.path.join(MODEL_DIR, "vectorizer.pkl"))
    _label_encoder = joblib.load(os.path.join(MODEL_DIR, "label_encoder.pkl"))
    _framework = "sklearn"
    print(f"[SKLEARN] Model loaded with classes: {_label_encoder.classes_}")


def _load_tensorflow():
    global _model, _tokenizer, _label_encoder, _framework
    import tensorflow as tf

    _model = tf.keras.models.load_model(os.path.join(MODEL_DIR, "tf_model"))
    with open(os.path.join(MODEL_DIR, "tf_tokenizer.pkl"), "rb") as f:
        config = pickle.load(f)
    _tokenizer = tf.keras.layers.TextVectorization.from_config(config)
    _label_encoder = joblib.load(os.path.join(MODEL_DIR, "label_encoder.pkl"))
    _framework = "tensorflow"
    print(f"[TENSORFLOW] Model loaded with classes: {_label_encoder.classes_}")


def load_model():
    if _model is not None:
        return
    if not os.path.exists(MODEL_DIR):
        raise FileNotFoundError(f"Model directory not found: {MODEL_DIR}")

    framework = _load_framework() or "sklearn"
    if framework == "tensorflow":
        _load_tensorflow()
    else:
        _load_sklearn()


def predict_category(text: str) -> dict:
    load_model()
    if _framework == "sklearn":
        X = _vectorizer.transform([text])
        probs = _model.predict_proba(X)[0]
        pred_idx = int(np.argmax(probs))
        category = _label_encoder.inverse_transform([pred_idx])[0]
        confidence = float(probs[pred_idx])
        return {"category": category, "confidence": round(confidence, 4)}
    else:
        import tensorflow as tf
        X = _tokenizer(tf.constant([text])).numpy()
        probs = _model.predict(X, verbose=0)[0]
        pred_idx = int(np.argmax(probs))
        category = _label_encoder.inverse_transform([pred_idx])[0]
        confidence = float(probs[pred_idx])
        return {"category": category, "confidence": round(confidence, 4)}


def predict_top_k(text: str, k: int = 3) -> list[dict]:
    load_model()
    if _framework == "sklearn":
        X = _vectorizer.transform([text])
        probs = _model.predict_proba(X)[0]
    else:
        import tensorflow as tf
        X = _tokenizer(tf.constant([text])).numpy()
        probs = _model.predict(X, verbose=0)[0]

    top_indices = np.argsort(probs)[::-1][:k]
    return [
        {
            "category": _label_encoder.inverse_transform([int(i)])[0],
            "confidence": round(float(probs[i]), 4),
        }
        for i in top_indices
    ]


if __name__ == "__main__":
    load_model()
    samples = [
        "breach of contract between two companies",
        "murder trial with evidence of premeditation",
        "child custody dispute after divorce",
        "merger and acquisition due diligence",
        "probate of will after testator death",
    ]
    for s in samples:
        result = predict_category(s)
        print(f"  {result['category']:>10} ({result['confidence']:.2f})  ←  {s}")
