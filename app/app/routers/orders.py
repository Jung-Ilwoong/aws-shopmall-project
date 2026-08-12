from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas
from app.auth import get_current_user
from app.database import get_db

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post("", response_model=schemas.OrderOut, status_code=201)
def checkout(user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not user.is_email_verified:
        raise HTTPException(status_code=403, detail="이메일 인증 후 주문할 수 있습니다")

    cart_items = db.query(models.CartItem).filter(models.CartItem.user_id == user.id).all()
    if not cart_items:
        raise HTTPException(status_code=400, detail="장바구니가 비어있습니다")

    for item in cart_items:
        if item.product.stock < item.quantity:
            raise HTTPException(status_code=400, detail=f"'{item.product.name}' 재고가 부족합니다")

    total_price = sum(item.product.price * item.quantity for item in cart_items)
    order = models.Order(user_id=user.id, total_price=total_price, status="PAID")
    db.add(order)
    db.flush()  # order.id 확보

    for item in cart_items:
        db.add(
            models.OrderItem(
                order_id=order.id,
                product_id=item.product_id,
                quantity=item.quantity,
                price_at_order=item.product.price,
            )
        )
        item.product.stock -= item.quantity
        db.delete(item)

    db.commit()
    db.refresh(order)
    return order


@router.get("", response_model=list[schemas.OrderOut])
def order_history(user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(models.Order).filter(models.Order.user_id == user.id).all()


@router.get("/{order_id}", response_model=schemas.OrderOut)
def order_detail(
    order_id: int, user: models.User = Depends(get_current_user), db: Session = Depends(get_db)
):
    order = (
        db.query(models.Order)
        .filter(models.Order.id == order_id, models.Order.user_id == user.id)
        .first()
    )
    if not order:
        raise HTTPException(status_code=404, detail="주문을 찾을 수 없습니다")
    return order
