from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import ai, models, schemas
from app.auth import get_current_admin
from app.database import get_db

router = APIRouter(prefix="/products", tags=["products"])


@router.post(
    "/generate-description",
    response_model=schemas.DescriptionResponse,
    dependencies=[Depends(get_current_admin)],
)
def generate_description(payload: schemas.DescriptionRequest):
    description = ai.generate_product_description(payload.name, payload.category)
    return schemas.DescriptionResponse(description=description)


@router.get("", response_model=list[schemas.ProductOut])
def list_products(
    skip: int = 0,
    limit: int = 20,
    search: str | None = None,
    category: str | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(models.Product)
    if search:
        query = query.filter(models.Product.name.ilike(f"%{search}%"))
    if category:
        query = query.filter(models.Product.category == category)
    return query.offset(skip).limit(limit).all()


@router.get("/meta/categories", response_model=list[str])
def list_categories(db: Session = Depends(get_db)):
    rows = (
        db.query(models.Product.category)
        .filter(models.Product.category.isnot(None))
        .distinct()
        .all()
    )
    return [r[0] for r in rows]


@router.get("/{product_id}", response_model=schemas.ProductOut)
def get_product(product_id: int, db: Session = Depends(get_db)):
    product = db.query(models.Product).filter(models.Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="상품을 찾을 수 없습니다")
    return product


@router.post("", response_model=schemas.ProductOut, dependencies=[Depends(get_current_admin)])
def create_product(payload: schemas.ProductCreate, db: Session = Depends(get_db)):
    product = models.Product(**payload.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@router.put(
    "/{product_id}", response_model=schemas.ProductOut, dependencies=[Depends(get_current_admin)]
)
def update_product(product_id: int, payload: schemas.ProductUpdate, db: Session = Depends(get_db)):
    product = db.query(models.Product).filter(models.Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="상품을 찾을 수 없습니다")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(product, field, value)

    db.commit()
    db.refresh(product)
    return product


@router.delete("/{product_id}", status_code=204, dependencies=[Depends(get_current_admin)])
def delete_product(product_id: int, db: Session = Depends(get_db)):
    product = db.query(models.Product).filter(models.Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="상품을 찾을 수 없습니다")

    db.delete(product)
    db.commit()
