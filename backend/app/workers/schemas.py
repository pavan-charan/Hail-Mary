from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class WorkerRegisterSchema(BaseModel):
    phone: str = Field(..., example="+919876543211")
    full_name: str = Field(..., example="Ramesh Kumar")
    ward: str = Field(..., example="Ward-12")

class WorkerEnrollFaceSchema(BaseModel):
    worker_id: int
    face_image_base64: str

class WorkerResponseSchema(BaseModel):
    id: int
    user_id: int
    worker_code: str
    ward: str
    full_name: Optional[str] = None
    phone: Optional[str] = None
    face_enrolled: bool
    active_workload_count: int
    total_resolved_count: int
    penalty_count: int
    current_latitude: Optional[float] = None
    current_longitude: Optional[float] = None

    class Config:
        from_attributes = True
