from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from app.face_verification.service import extract_face_embedding, verify_face_match

router = APIRouter(prefix="/face-verification", tags=["Face Verification"])

class FaceVerifyRequest(BaseModel):
    enrolled_embedding: str
    live_face_image_base64: str

class FaceVerifyResponse(BaseModel):
    is_match: bool
    score: float
    message: str

@router.post("/verify", response_model=FaceVerifyResponse)
def verify_live_face(data: FaceVerifyRequest):
    live_embedding = extract_face_embedding(data.live_face_image_base64)
    if not live_embedding:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No face detected in live camera image")
        
    is_match, score = verify_face_match(data.enrolled_embedding, live_embedding)
    return FaceVerifyResponse(
        is_match=is_match,
        score=score,
        message="Face match verified" if is_match else "Face verification failed. Person does not match enrolled worker."
    )
