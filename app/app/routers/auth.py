from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app import models, schemas
from app.auth import hash_password, verify_password, create_access_token, get_current_user
from app.database import get_db
from app.email import generate_verification_code, send_verification_email

router = APIRouter(prefix="/auth", tags=["auth"])

VERIFICATION_CODE_TTL_MINUTES = 5
RESEND_COOLDOWN_SECONDS = 60


@router.post("/register", response_model=schemas.UserOut, status_code=status.HTTP_201_CREATED)
def register(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="이미 가입된 이메일입니다")

    code = generate_verification_code()
    user = models.User(
        email=payload.email,
        hashed_password=hash_password(payload.password),
        name=payload.name,
        phone=payload.phone,
        postcode=payload.postcode,
        address=payload.address,
        address_detail=payload.address_detail,
        terms_agreed=payload.terms_agreed,
        privacy_agreed=payload.privacy_agreed,
        marketing_agreed=payload.marketing_agreed,
        email_verification_code=code,
        email_verification_expires_at=datetime.utcnow() + timedelta(minutes=VERIFICATION_CODE_TTL_MINUTES),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    send_verification_email(user.email, code)
    return user


@router.post("/verify-email")
def verify_email(payload: schemas.EmailVerifyRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == payload.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="가입된 이메일이 아닙니다")
    if user.is_email_verified:
        return {"message": "이미 인증된 이메일입니다"}
    if not user.email_verification_code or user.email_verification_code != payload.code:
        raise HTTPException(status_code=400, detail="인증 코드가 올바르지 않습니다")
    if not user.email_verification_expires_at or user.email_verification_expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="인증 코드가 만료되었습니다. 재발송해주세요")

    user.is_email_verified = True
    user.email_verification_code = None
    user.email_verification_expires_at = None
    db.commit()
    return {"message": "이메일 인증이 완료되었습니다"}


@router.post("/resend-verification")
def resend_verification(payload: schemas.ResendCodeRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == payload.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="가입된 이메일이 아닙니다")
    if user.is_email_verified:
        return {"message": "이미 인증된 이메일입니다"}

    if user.email_verification_expires_at:
        sent_at = user.email_verification_expires_at - timedelta(minutes=VERIFICATION_CODE_TTL_MINUTES)
        elapsed = (datetime.utcnow() - sent_at).total_seconds()
        if elapsed < RESEND_COOLDOWN_SECONDS:
            wait = int(RESEND_COOLDOWN_SECONDS - elapsed)
            raise HTTPException(status_code=429, detail=f"{wait}초 후 다시 시도해주세요")

    code = generate_verification_code()
    user.email_verification_code = code
    user.email_verification_expires_at = datetime.utcnow() + timedelta(minutes=VERIFICATION_CODE_TTL_MINUTES)
    db.commit()

    send_verification_email(user.email, code)
    return {"message": "인증 코드를 재발송했습니다"}


@router.post("/login", response_model=schemas.Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="이메일 또는 비밀번호가 올바르지 않습니다")

    token = create_access_token({"sub": str(user.id)})
    return schemas.Token(access_token=token)


@router.get("/me", response_model=schemas.UserOut)
def me(user: models.User = Depends(get_current_user)):
    return user
