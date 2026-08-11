def test_list_products_empty(client):
    res = client.get("/products")
    assert res.status_code == 200
    assert res.json() == []


def test_create_product_requires_admin(client, user_token):
    res = client.post(
        "/products",
        json={"name": "이어폰", "price": 10000, "stock": 5},
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert res.status_code == 403


def test_create_product_as_admin_succeeds(client, admin_token):
    res = client.post(
        "/products",
        json={"name": "이어폰", "price": 10000, "stock": 5, "category": "전자기기"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert res.status_code == 200
    assert res.json()["name"] == "이어폰"


def test_list_products_after_create(client, admin_token):
    client.post(
        "/products",
        json={"name": "이어폰", "price": 10000, "stock": 5},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    res = client.get("/products")
    assert len(res.json()) == 1


def test_search_filter(client, admin_token):
    headers = {"Authorization": f"Bearer {admin_token}"}
    client.post("/products", json={"name": "블루투스 이어폰", "price": 10000, "stock": 5}, headers=headers)
    client.post("/products", json={"name": "기계식 키보드", "price": 50000, "stock": 3}, headers=headers)

    res = client.get("/products", params={"search": "이어폰"})
    assert len(res.json()) == 1
    assert res.json()[0]["name"] == "블루투스 이어폰"


def test_category_filter(client, admin_token):
    headers = {"Authorization": f"Bearer {admin_token}"}
    client.post(
        "/products",
        json={"name": "이어폰", "price": 10000, "stock": 5, "category": "음향"},
        headers=headers,
    )
    client.post(
        "/products",
        json={"name": "키보드", "price": 50000, "stock": 3, "category": "주변기기"},
        headers=headers,
    )

    res = client.get("/products", params={"category": "음향"})
    assert len(res.json()) == 1
    assert res.json()[0]["name"] == "이어폰"
