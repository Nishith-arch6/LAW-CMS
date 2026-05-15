import pytesseract
from PIL import Image

from app.core.config import settings

pytesseract.pytesseract.tesseract_cmd = settings.tesseract_cmd


def extract_text_from_image(image_path: str) -> str:
    image = Image.open(image_path)
    return pytesseract.image_to_string(image)


def extract_text_from_bytes(image_bytes: bytes) -> str:
    import io
    image = Image.open(io.BytesIO(image_bytes))
    return pytesseract.image_to_string(image)
