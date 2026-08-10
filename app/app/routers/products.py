import uuid

import boto3
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import ai, models, schemas
from app.auth import get_current_admin
from app.config import settings
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


@router.post(
    "/upload-url",
    response_model=schemas.UploadUrlResponse,
    dependencies=[Depends(get_current_admin)],
)
def get_upload_url(payload: schemas.UploadUrlRequest):
    # 브라우저가 이 URL로 파일을 S3에 직접 PUT한다 (서버를 거치지 않음)
    key = f"products/{uuid.uuid4()}-{payload.filename}"
    s3 = boto3.client("s3", region_name=settings.aws_region)
    upload_url = s3.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": settings.s3_uploads_bucket,
            "Key": key,
            "ContentType": payload.content_type,
        },
        ExpiresIn=300,
    )
    public_url = f"https://{settings.uploads_cloudfront_domain}/{key}"
    return schemas.UploadUrlResponse(upload_url=upload_url, public_url=public_url)


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
