from datetime import datetime

from pydantic import BaseModel


class TimelineEventSchema(BaseModel):
    event_type: str
    description: str
    timestamp: datetime
    metadata: dict = {}
