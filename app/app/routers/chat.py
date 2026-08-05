from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app import ai, schemas
from app.database import get_db

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("", response_model=schemas.ChatResponse)
def chat(payload: schemas.ChatRequest, db: Session = Depends(get_db)):
    reply = ai.chat_with_context(payload.message, db)
    return schemas.ChatResponse(reply=reply)
