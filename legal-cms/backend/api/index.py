import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

os.environ.setdefault("ENVIRONMENT", "prod")
os.environ.setdefault("DEBUG", "False")

from app.main import app

handler = app
