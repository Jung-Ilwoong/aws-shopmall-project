from anthropic import Anthropic
from sqlalchemy.orm import Session

from app.config import settings
from app import models

MODEL = "claude-sonnet-4-5"


def _client() -> Anthropic:
    return Anthropic(api_key=settings.anthropic_api_key)


def _product_context(db: Session, limit: int = 30) -> str:
    """간단한 RAG: 현재 판매 중인 상품 목록을 요약해서 프롬프트에 끼워 넣는다."""
    products = db.query(models.Product).order_by(models.Product.id.desc()).limit(limit).all()
    if not products:
        return "(현재 등록된 상품이 없습니다)"

    lines = [
        f"- {p.name} | 가격: {p.price:,.0f}원 | 재고: {p.stock}개"
        for p in products
    ]
    return "\n".join(lines)


def chat_with_context(message: str, db: Session) -> str:
    context = _product_context(db)
    system_prompt = (
        "당신은 쇼핑몰 'Shopmall'의 고객 상담 챗봇입니다. "
        "친절하고 간결하게 한국어로 답변하세요. "
        "아래는 현재 판매 중인 상품 목록입니다. 이 정보를 참고해서 답변하세요. "
        "목록에 없는 상품에 대해 질문받으면, 모르는 상품이라고 솔직히 답변하세요.\n\n"
        f"[현재 상품 목록]\n{context}"
    )

    response = _client().messages.create(
        model=MODEL,
        max_tokens=500,
        system=system_prompt,
        messages=[{"role": "user", "content": message}],
    )
    return response.content[0].text


def generate_product_description(name: str, category: str | None = None) -> str:
    prompt = f"상품명: {name}"
    if category:
        prompt += f"\n카테고리: {category}"
    prompt += (
        "\n\n위 상품에 대한 매력적인 쇼핑몰 상품 설명을 한국어로 2~3문장 작성해주세요. "
        "과장된 표현 없이, 구매욕을 자극하는 톤으로 작성하세요."
    )

    response = _client().messages.create(
        model=MODEL,
        max_tokens=300,
        messages=[{"role": "user", "content": prompt}],
    )
    return response.content[0].text
