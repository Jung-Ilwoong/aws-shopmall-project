def test_cart_requires_auth(client):
    res = client.get("/cart")
    assert res.status_code == 401


def test_add_to_cart(client, user_token, sample_product):
    res = client.post(
        "/cart",
        json={"product_id": sample_product.id, "quantity": 2},
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert res.status_code == 201
    assert res.json()["quantity"] == 2


def test_add_to_cart_insufficient_stock(client, user_token, sample_product):
    res = client.post(
        "/cart",
        json={"product_id": sample_product.id, "quantity": 999},
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert res.status_code == 400


def test_update_cart_quantity(client, user_token, sample_product):
    headers = {"Authorization": f"Bearer {user_token}"}
    add_res = client.post("/cart", json={"product_id": sample_product.id, "quantity": 1}, headers=headers)
    item_id = add_res.json()["id"]

    res = client.put(f"/cart/{item_id}", json={"quantity": 3}, headers=headers)
    assert res.status_code == 200
    assert res.json()["quantity"] == 3


def test_remove_from_cart(client, user_token, sample_product):
    headers = {"Authorization": f"Bearer {user_token}"}
    add_res = client.post("/cart", json={"product_id": sample_product.id, "quantity": 1}, headers=headers)
    item_id = add_res.json()["id"]

    res = client.delete(f"/cart/{item_id}", headers=headers)
    assert res.status_code == 204

    list_res = client.get("/cart", headers=headers)
    assert list_res.json() == []
