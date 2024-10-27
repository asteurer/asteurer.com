import requests
import json

ENDPOINT = "http://localhost:8080"

def test_can_create():
    payload = "example.com"

    # Create the item
    create_task_response = requests.put(ENDPOINT + "/meme", bytearray(payload, "utf-8"))
    assert create_task_response.status_code == 200
    create_task_id = create_task_response.json()["id"]

    # Check that the item was properly created
    get_task_response = requests.get(ENDPOINT + f"/meme/{create_task_id}")
    assert get_task_response.status_code == 200
    get_task_data = get_task_response.json()
    assert get_task_data["current_meme"]["id"] == create_task_id
    assert get_task_data["current_meme"]["url"] == payload
    assert get_task_data["previous_meme_id"] == create_task_id
    assert get_task_data["next_meme_id"] == create_task_id

    # Delete the item
    delete_task_response = requests.delete(ENDPOINT + F"/meme/{create_task_id}")
    assert delete_task_response.status_code == 200


def test_can_read():
    payload_1 = "example.com" # Oldest
    payload_2= "test.com" # Newest

    # Create the items
    create_task_response_1 = requests.put(ENDPOINT + "/meme", bytearray(payload_1, "utf-8"))
    assert create_task_response_1.status_code == 200
    id_1 = create_task_response_1.json()["id"]

    create_task_response_2 = requests.put(ENDPOINT + "/meme", bytearray(payload_2, "utf-8"))
    assert create_task_response_2.status_code == 200
    id_2 = create_task_response_2.json()["id"]

    # Check that we can retrieve the oldest item
    get_task_response_1 = requests.get(ENDPOINT + f"/meme/{id_1}")
    assert get_task_response_1.status_code == 200
    get_task_data = get_task_response_1.json()
    assert get_task_data["current_meme"]["id"] == id_1
    assert get_task_data["current_meme"]["url"] == payload_1
    assert get_task_data["previous_meme_id"] == id_2
    assert get_task_data["next_meme_id"] == id_2

    # Check that we can retrieve the latest item
    get_task_response_2 = requests.get(ENDPOINT + f"/latest_meme")
    assert get_task_response_1.status_code == 200
    get_task_data = get_task_response_2.json()
    assert get_task_data["current_meme"]["id"] == id_2
    assert get_task_data["current_meme"]["url"] == payload_2
    assert get_task_data["previous_meme_id"] == id_1
    assert get_task_data["next_meme_id"] == id_1

    # Delete the items
    delete_task_response = requests.delete(ENDPOINT + F"/meme/{id_1}")
    assert delete_task_response.status_code == 200
    delete_task_response = requests.delete(ENDPOINT + F"/meme/{id_2}")
    assert delete_task_response.status_code == 200

    # Check for a non-existent item
    get_task_response = requests.get(ENDPOINT + f"/meme/{id_1}")
    assert get_task_response.status_code == 404

    # Query an empty database
    get_task_response = requests.get(ENDPOINT + f"/latest_meme")
    assert get_task_response.status_code == 204


def test_can_read_all():
    payloads = [
        "example.com",
        "test.com",
        "demo.com"
    ]

    urls = {}
    for url in payloads:
        create_task_response = requests.put(ENDPOINT + "/meme", bytearray(url, "utf-8"))
        assert create_task_response.status_code == 200
        urls[create_task_response.json()["id"]] = url # Fill the dictionary with 'id: url'

    # Retrieve all_memes: {id: int, url: string}
    get_all_task_response = requests.get(ENDPOINT + "/all_memes")
    assert get_all_task_response.status_code == 200
    get_all_task_data = get_all_task_response.json()

    for obj in get_all_task_data:
        assert urls[obj["id"]] == obj["url"]
        delete_task_response = requests.delete(ENDPOINT + f"/meme/{obj["id"]}")
        assert delete_task_response.status_code == 200

    # Query an empty database
    get_all_task_response = requests.get(ENDPOINT + "/all_memes")
    print(get_all_task_response.status_code)
    assert get_all_task_response.status_code == 204


def test_can_update():
    payload = "example.com"

    # Create the item
    create_task_response = requests.put(ENDPOINT + "/meme", bytearray(payload, "utf-8"))
    assert create_task_response.status_code == 200
    create_task_id = create_task_response.json()["id"]

    # Check that the item was properly created
    get_task_response = requests.get(ENDPOINT + f"/meme/{create_task_id}")
    assert get_task_response.status_code == 200
    get_task_data = get_task_response.json()
    assert get_task_data["current_meme"]["id"] == create_task_id
    assert get_task_data["current_meme"]["url"] == payload
    assert get_task_data["previous_meme_id"] == create_task_id
    assert get_task_data["next_meme_id"] == create_task_id

    # Update the item
    update_payload = {
        "id": create_task_id,
        "url": "updated-example.com"
    }
    update_task_response = requests.post(ENDPOINT + "/meme", json.dumps(update_payload))
    assert update_task_response.status_code == 200
    validate_update_task_response = requests.get(ENDPOINT + f"/meme/{create_task_id}")
    validate_update_task_data = validate_update_task_response.json()
    assert validate_update_task_data["current_meme"]["id"] == create_task_id
    assert validate_update_task_data["current_meme"]["url"] == update_payload["url"]
    assert validate_update_task_data["previous_meme_id"] == create_task_id
    assert validate_update_task_data["next_meme_id"] == create_task_id

    # Delete the item
    delete_task_response = requests.delete(ENDPOINT + F"/meme/{create_task_id}")
    assert delete_task_response.status_code == 200


def test_can_delete():
    payload = "example.com"

    # Create the item
    create_task_response = requests.put(ENDPOINT + "/meme", bytearray(payload, "utf-8"))
    assert create_task_response.status_code == 200
    create_task_id = create_task_response.json()["id"]

    # Delete the item
    delete_task_response = requests.delete(ENDPOINT + F"/meme/{create_task_id}")
    assert delete_task_response.status_code == 200

    # Check that the item was deleted
    get_task_response = requests.get(ENDPOINT + f"/meme/{create_task_id}")
    assert get_task_response.status_code == 404