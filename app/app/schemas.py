import re
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, ConfigDict, field_validator, model_validator


# ---------- Auth ----------
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    password_confirm: str
    name: str
    phone: str
    postcode: str
    address: str
    address_detail: str
    terms_agreed: bool
    privacy_agreed: bool
    marketing_agreed: bool = False

    @field_validator("password")
    @classmethod
    def password_complexity(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("비밀번호는 8자 이상이어야 합니다")
        if not re.search(r"[A-Za-z]", v):
            raise ValueError("비밀번호에 영문을 포함해야 합니다")
        if not re.search(r"\d", v):
            raise ValueError("비밀번호에 숫자를 포함해야 합니다")
        if not re.search(r"[^A-Za-z0-9]", v):
            raise ValueError("비밀번호에 특수문자를 포함해야 합니다")
        return v

    @field_validator("terms_agreed", "privacy_agreed")
    @classmethod
    def required_agreement(cls, v: bool) -> bool:
        if not v:
            raise ValueError("필수 약관에 동의해야 합니다")
        return v

    @model_validator(mode="after")
    def passwords_match(self) -> "UserCreate":
        if self.password != self.password_confirm:
            raise ValueError("비밀번호가 일치하지 않습니다")
        return self


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class EmailVerifyRequest(BaseModel):
    email: EmailStr
    code: str


class ResendCodeRequest(BaseModel):
    email: EmailStr


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    name: Optional[str]
    phone: Optional[str]
    is_admin: bool
    is_email_verified: bool
    created_at: datetime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ---------- Product ----------
class ProductCreate(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    stock: int = 0
    image_url: Optional[str] = None
    category: Optional[str] = None


class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    stock: Optional[int] = None
    image_url: Optional[str] = None
    category: Optional[str] = None


class UploadUrlRequest(BaseModel):
    filename: str
    content_type: str


class UploadUrlResponse(BaseModel):
    upload_url: str
    public_url: str


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: Optional[str]
    price: float
    stock: int
    image_url: Optional[str]
    category: Optional[str]
    created_at: datetime


# ---------- AI ----------
class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str


class DescriptionRequest(BaseModel):
    name: str
    category: Optional[str] = None


class DescriptionResponse(BaseModel):
    description: str


# ---------- Cart ----------
class CartItemCreate(BaseModel):
    product_id: int
    quantity: int = 1


class CartItemUpdate(BaseModel):
    quantity: int


class CartItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product: ProductOut
    quantity: int


# ---------- Order ----------
class OrderItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    product_id: int
    quantity: int
    price_at_order: float


class OrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    total_price: float
    status: str
    created_at: datetime
    items: list[OrderItemOut]
