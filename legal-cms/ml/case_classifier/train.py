"""
Train case-type classifiers: TF-IDF + Logistic Regression (baseline)
and TensorFlow (Embedding + GlobalAvgPool). Saves the best model.
"""

import argparse
import json
import os
import pickle
import sys

import joblib
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, f1_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, PROJECT_ROOT)

CATEGORIES = ["CIVIL", "CRIMINAL", "FAMILY", "CORPORATE", "OTHER"]

MODEL_DIR = os.path.join(PROJECT_ROOT, "models", "case_classifier")
os.makedirs(MODEL_DIR, exist_ok=True)

SAMPLE_DATA = [
    ("breach of contract between two businesses", "CIVIL"),
    ("personal injury claim from car accident", "CIVIL"),
    ("property dispute over land boundaries", "CIVIL"),
    ("tenant suing landlord for deposit return", "CIVIL"),
    ("medical malpractice lawsuit against hospital", "CIVIL"),
    ("defamation case regarding false statements", "CIVIL"),
    ("insurance claim dispute after property damage", "CIVIL"),
    ("debt recovery proceedings against individual", "CIVIL"),
    ("consumer complaint about defective product", "CIVIL"),
    ("employment termination dispute with severance", "CIVIL"),
    ("fraudulent transaction recovery in civil court", "CIVIL"),
    ("negligence claim after workplace accident", "CIVIL"),
    ("neighbor dispute over nuisance and noise", "CIVIL"),
    ("partnership dissolution and asset division", "CIVIL"),
    ("intellectual property infringement lawsuit", "CIVIL"),
    ("murder trial with premeditation evidence", "CRIMINAL"),
    ("armed robbery at convenience store", "CRIMINAL"),
    ("drug trafficking across state lines", "CRIMINAL"),
    ("assault and battery charges in bar fight", "CRIMINAL"),
    ("burglary of residential property at night", "CRIMINAL"),
    ("fraud and embezzlement by company executive", "CRIMINAL"),
    ("kidnapping and unlawful detention charges", "CRIMINAL"),
    ("sexual assault allegations in workplace", "CRIMINAL"),
    ("possession of illegal firearms without license", "CRIMINAL"),
    ("driving under influence causing accident", "CRIMINAL"),
    ("hate crime vandalism against religious institution", "CRIMINAL"),
    ("money laundering through shell corporations", "CRIMINAL"),
    ("cybercrime including identity theft ring", "CRIMINAL"),
    ("domestic violence violation of protection order", "CRIMINAL"),
    ("public intoxication and disorderly conduct", "CRIMINAL"),
    ("child custody dispute between divorced parents", "FAMILY"),
    ("divorce proceedings with asset division", "FAMILY"),
    ("adoption petition by foster parents", "FAMILY"),
    ("child support modification request by father", "FAMILY"),
    ("domestic violence restraining order application", "FAMILY"),
    ("paternity establishment and visitation rights", "FAMILY"),
    ("marital property division after separation", "FAMILY"),
    ("guardianship petition for elderly parent", "FAMILY"),
    ("emancipation of minor request by teenager", "FAMILY"),
    ("prenuptial agreement enforcement in divorce", "FAMILY"),
    ("spousal maintenance modification hearing", "FAMILY"),
    ("relocation dispute with custodial parent moving", "FAMILY"),
    ("adult adoption of stepchild by stepparent", "FAMILY"),
    ("same-sex marriage dissolution and custody", "FAMILY"),
    ("inheritance dispute among siblings after death", "FAMILY"),
    ("merger acquisition due diligence review", "CORPORATE"),
    ("shareholder derivative lawsuit against directors", "CORPORATE"),
    ("contract negotiation for software licensing deal", "CORPORATE"),
    ("insider trading investigation by securities board", "CORPORATE"),
    ("corporate restructuring and bankruptcy filing", "CORPORATE"),
    ("intellectual property licensing agreement dispute", "CORPORATE"),
    ("antitrust violation investigation by commission", "CORPORATE"),
    ("board of directors governance compliance review", "CORPORATE"),
    ("securities fraud class action by investors", "CORPORATE"),
    ("joint venture agreement between two companies", "CORPORATE"),
    ("trade secret misappropriation by ex-employee", "CORPORATE"),
    ("corporate tax evasion investigation by authority", "CORPORATE"),
    ("hostile takeover defense strategy implementation", "CORPORATE"),
    ("commercial lease dispute between landlord tenant", "CORPORATE"),
    ("regulatory compliance audit for pharmaceutical firm", "CORPORATE"),
    ("probate of will after testator death", "OTHER"),
    ("immigration visa application for skilled worker", "OTHER"),
    ("social security disability benefits appeal", "OTHER"),
    ("tax court appeal for irs deficiency notice", "OTHER"),
    ("bankruptcy filing under chapter seven", "OTHER"),
    ("consumer protection complaint about false advertising", "OTHER"),
    ("whistleblower retaliation against employer", "OTHER"),
    ("veteran disability benefits claim review", "OTHER"),
    ("unemployment compensation appeal by former worker", "OTHER"),
    ("condominium association governance dispute", "OTHER"),
    ("zoning variance application for commercial property", "OTHER"),
    ("environmental regulation compliance for factory", "OTHER"),
    ("animal cruelty investigation by local authority", "OTHER"),
    ("school expulsion hearing for student conduct", "OTHER"),
    ("public records request under freedom of information", "OTHER"),
]

TF_VOCAB_SIZE = 8000
TF_MAX_LEN = 200
EMBEDDING_DIM = 128


def _build_dataset():
    texts = [item[0] for item in SAMPLE_DATA]
    labels = [item[1] for item in SAMPLE_DATA]
    return texts, labels


def _train_sklearn(texts, labels):
    print("[SKLEARN] Training TF-IDF + Logistic Regression ...")
    vectorizer = TfidfVectorizer(max_features=TF_VOCAB_SIZE, ngram_range=(1, 2))
    X = vectorizer.fit_transform(texts)
    le = LabelEncoder()
    y = le.fit_transform(labels)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    model = LogisticRegression(max_iter=500, multi_class="multinomial")
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)
    f1 = f1_score(y_test, y_pred, average="weighted")
    print(f"[SKLEARN] Weighted F1: {f1:.4f}")
    report = classification_report(y_test, y_pred, target_names=le.classes_)
    print(report)
    return model, vectorizer, le, f1


def _train_tensorflow(texts, labels):
    print("[TENSORFLOW] Building and training Embedding + GlobalAvgPool model ...")
    import tensorflow as tf
    from tensorflow.keras import layers

    vectorizer = TfidfVectorizer(max_features=TF_VOCAB_SIZE)
    vectorizer.fit(texts)
    vocab = vectorizer.get_feature_names_out()
    vocab_size = len(vocab) + 2

    le = LabelEncoder()
    y = le.fit_transform(labels)
    num_classes = len(le.classes_)

    tokenizer = tf.keras.layers.TextVectorization(
        max_tokens=TF_VOCAB_SIZE, output_sequence_length=TF_MAX_LEN
    )
    tokenizer.adapt(tf.data.Dataset.from_tensor_slices(texts))
    X = tokenizer(tf.constant(texts)).numpy()

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    model = tf.keras.Sequential([
        layers.Embedding(vocab_size, EMBEDDING_DIM, mask_zero=True),
        layers.GlobalAveragePooling1D(),
        layers.Dense(64, activation="relu"),
        layers.Dropout(0.3),
        layers.Dense(num_classes, activation="softmax"),
    ])
    model.compile(
        optimizer="adam",
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.fit(
        X_train,
        y_train,
        validation_split=0.2,
        epochs=30,
        batch_size=8,
        verbose=1,
        callbacks=[tf.keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True)],
    )
    y_pred = np.argmax(model.predict(X_test), axis=1)
    f1 = f1_score(y_test, y_pred, average="weighted")
    print(f"[TENSORFLOW] Weighted F1: {f1:.4f}")
    report = classification_report(y_test, y_pred, target_names=le.classes_)
    print(report)
    return model, tokenizer, le, f1


def _save_sklearn(model, vectorizer, le, path):
    joblib.dump(model, os.path.join(path, "sklearn_model.pkl"))
    joblib.dump(vectorizer, os.path.join(path, "vectorizer.pkl"))
    joblib.dump(le, os.path.join(path, "label_encoder.pkl"))
    with open(os.path.join(path, "framework.txt"), "w") as f:
        f.write("sklearn")


def _save_tensorflow(model, tokenizer, le, path):
    model.save(os.path.join(path, "tf_model"))
    import pickle
    with open(os.path.join(path, "tf_tokenizer.pkl"), "wb") as f:
        pickle.dump(tokenizer.get_config(), f)
    joblib.dump(le, os.path.join(path, "label_encoder.pkl"))
    with open(os.path.join(path, "framework.txt"), "w") as f:
        f.write("tensorflow")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force-tf", action="store_true", help="Force TensorFlow even if not best")
    args = parser.parse_args()

    texts, labels = _build_dataset()
    print(f"Dataset: {len(texts)} samples, {len(set(labels))} classes: {sorted(set(labels))}")

    sk_model, sk_vectorizer, sk_le, sk_f1 = _train_sklearn(texts, labels)

    use_tf = False
    try:
        import tensorflow as tf
        tf_model, tf_tokenizer, tf_le, tf_f1 = _train_tensorflow(texts, labels)
        use_tf = args.force_tf or tf_f1 >= sk_f1
        print(f"\nBest model: {'TensorFlow' if use_tf else 'Sklearn'} "
              f"(TF F1={tf_f1:.4f} vs SK F1={sk_f1:.4f})")
    except ImportError:
        print("\nTensorFlow not available — saving sklearn model only")
        tf_f1 = -1.0

    if use_tf:
        _save_tensorflow(tf_model, tf_tokenizer, tf_le, MODEL_DIR)
    else:
        _save_sklearn(sk_model, sk_vectorizer, sk_le, MODEL_DIR)

    results = {
        "sklearn_f1": round(sk_f1, 4),
        "tensorflow_f1": round(float(tf_f1), 4) if not isinstance(tf_f1, float) else tf_f1,
        "saved": "tensorflow" if use_tf else "sklearn",
        "samples": len(texts),
        "classes": CATEGORIES,
        "best_f1": max(sk_f1, tf_f1),
    }
    with open(os.path.join(MODEL_DIR, "results.json"), "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nSaved to {MODEL_DIR}")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
