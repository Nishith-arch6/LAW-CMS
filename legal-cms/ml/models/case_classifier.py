import joblib
import numpy as np
from sklearn.pipeline import Pipeline
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier


class CaseTypeClassifier:
    def __init__(self):
        self.pipeline = Pipeline([
            ("tfidf", TfidfVectorizer(max_features=5000)),
            ("clf", RandomForestClassifier(n_estimators=100)),
        ])
        self._fitted = False

    def train(self, texts: list[str], labels: list[str]) -> None:
        self.pipeline.fit(texts, labels)
        self._fitted = True

    def predict(self, text: str) -> str:
        if not self._fitted:
            raise RuntimeError("Model not trained yet")
        return self.pipeline.predict([text])[0]

    def predict_proba(self, text: str) -> dict[str, float]:
        if not self._fitted:
            raise RuntimeError("Model not trained yet")
        classes = self.pipeline.classes_
        probs = self.pipeline.predict_proba([text])[0]
        return dict(zip(classes, probs))

    def save(self, path: str) -> None:
        joblib.dump(self.pipeline, path)

    def load(self, path: str) -> None:
        self.pipeline = joblib.load(path)
        self._fitted = True
