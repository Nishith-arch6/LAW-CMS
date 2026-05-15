from transformers import pipeline


class LegalNER:
    def __init__(self, model_name: str = "dslim/bert-base-NER"):
        self.nlp = pipeline("ner", model=model_name, aggregation_strategy="simple")

    def extract_entities(self, text: str) -> list[dict]:
        return self.nlp(text)
