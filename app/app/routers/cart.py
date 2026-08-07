from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas
from app.auth import get_current_user
from app.database import get_db

router = APIRouter(prefix="/cart", tags=["cart"])


@router.get("", response_model=list[schemas.CartItemOut])
def get_cart(
    user: models.User = Depends(get_current_user), db: Session = Depends(get_db)
):
    return db.query(models.CartItem).filter(models.CartItem.user_id == user.id).all()


@router.post("", response_model=schemas.CartItemOut, status_code=201)
def add_to_cart(
    payload: schemas.CartItemCreate,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    product = db.query(models.Product).filter(models.Product.id == payload.product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="상품을 찾을 수 없습니다")
    if product.stock < payload.quantity:
        raise HTTPException(status_code=400, detail="재고가 부족합니다")

    existing = (
        db.query(models.CartItem)
        .filter(models.CartItem.user_id == user.id, models.CartItem.product_id == payload.product_id)
        .first()
    )
    if existing:
        existing.quantity += payload.quantity
        db.commit()
        db.refresh(existing)
        return existing

    item = models.CartItem(user_id=user.id, product_id=payload.product_id, quantity=payload.quantity)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.put("/{item_id}", response_model=schemas.CartItemOut)
def update_cart_item(
    item_id: int,
    payload: schemas.CartItemUpdate,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    item = (
        db.query(models.CartItem)
        .filter(models.CartItem.id == item_id, models.CartItem.user_id == user.id)
        .first()
    )
    if not item:
        raise HTTPException(status_code=404, detail="장바구니 항목을 찾을 수 없습니다")
    if payload.quantity < 1:
        raise HTTPException(status_code=400, detail="수량은 1개 이상이어야 합니다")
    if item.product.stock < payload.quantity:
        raise HTTPException(status_code=400, detail="재고가 부족합니다")

    item.quantity = payload.quantity
    db.commit()
    db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=204)
def remove_from_cart(
    item_id: int, user: models.User = Depends(get_current_user), db: Session = Depends(get_db)
):
    item = (
        db.query(models.CartItem)
        .filter(models.CartItem.id == item_id, models.CartItem.user_id == user.id)
        .first()
    )
    if not item:
        raise HTTPException(status_code=404, detail="장바구니 항목을 찾을 수 없습니다")

    db.delete(item)
    db.commit()
