from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, ConfigDict


# ---------- Auth ----------
class UserCreate(BaseModel):
    email: EmailStr
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    is_admin: bool
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


class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    stock: Optional[int] = None
    image_url: Optional[str] = None


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: Optional[str]
    price: float
    stock: int
    image_url: Optional[str]
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
