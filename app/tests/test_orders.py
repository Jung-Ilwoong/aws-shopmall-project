def test_checkout_empty_cart_fails(client, user_token):
    res = client.post("/orders", headers={"Authorization": f"Bearer {user_token}"})
    assert res.status_code == 400


def test_checkout_success_reduces_stock_and_clears_cart(client, user_token, sample_product):
    headers = {"Authorization": f"Bearer {user_token}"}
    client.post("/cart", json={"product_id": sample_product.id, "quantity": 2}, headers=headers)

    res = client.post("/orders", headers=headers)
    assert res.status_code == 201
    order = res.json()
    assert order["status"] == "PAID"
    assert order["total_price"] == sample_product.price * 2
    assert len(order["items"]) == 1

    product_res = client.get(f"/products/{sample_product.id}")
    assert product_res.json()["stock"] == sample_product.stock - 2

    cart_res = client.get("/cart", headers=headers)
    assert cart_res.json() == []


def test_order_history(client, user_token, sample_product):
    headers = {"Authorization": f"Bearer {user_token}"}
    client.post("/cart", json={"product_id": sample_product.id, "quantity": 1}, headers=headers)
    client.post("/orders", headers=headers)

    res = client.get("/orders", headers=headers)
    assert res.status_code == 200
    assert len(res.json()) == 1
