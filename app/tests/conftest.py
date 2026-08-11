import os

os.environ.setdefault("DB_HOST", "127.0.0.1")
os.environ.setdefault("DB_PORT", "3306")
os.environ.setdefault("DB_USER", "root")
os.environ.setdefault("DB_PASSWORD", "test")
os.environ.setdefault("DB_NAME", "shopmall_test")
os.environ.setdefault("JWT_SECRET", "test-secret")

import pytest
from fastapi.testclient import TestClient

from app import models
from app.database import Base, SessionLocal, engine
from app.main import app


@pytest.fixture(autouse=True)
def reset_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def register_and_login(client, email="user@example.com", password="testpass123"):
    client.post("/auth/register", json={"email": email, "password": password})
    res = client.post(
        "/auth/login",
        data={"username": email, "password": password},
    )
    return res.json()["access_token"]


@pytest.fixture
def user_token(client):
    return register_and_login(client)


@pytest.fixture
def admin_token(client, db_session):
    token = register_and_login(client, email="admin@example.com")
    user = db_session.query(models.User).filter(models.User.email == "admin@example.com").first()
    user.is_admin = True
    db_session.commit()
    return token


@pytest.fixture
def sample_product(db_session):
    product = models.Product(name="테스트 상품", price=10000, stock=5)
    db_session.add(product)
    db_session.commit()
    db_session.refresh(product)
    return product
