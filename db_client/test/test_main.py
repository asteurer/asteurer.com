import requests

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


# def test_can_read_all():
#     payloads = [
#         "example.com",
#         "test.com",
#         "demo.com"
#     ]

#     urls = {}
#     for url in payloads:
#         create_task_response = requests.put(ENDPOINT + "/meme", bytearray(url, "utf-8"))
#         assert create_task_response.status_code == 200
#         urls[create_task_response.json()["id"]] = url # Fill the dictionary with 'id: url'

#     get_all_task_response = requests.get(ENDPOINT + "/all_memes")
#     assert get_all_task_response.status_code == 200
#     get_all_task_data = get_all_task_response.json()

#     for id, url in get_all_task_data.items():
#         assert urls[id] == url
#         delete_task_response = requests.delete(ENDPOINT + f"/meme/{id}")
#         assert delete_task_response.status_code == 200


# def test_can_update():
#     payload = "example.com"

#     # Create the item
#     create_task_response = requests.put(ENDPOINT + "/meme", bytearray(payload, "utf-8"))
#     assert create_task_response.status_code == 200
#     create_task_id = create_task_response.json()["id"]

#     # Check that the item was properly created
#     get_task_response = requests.get(ENDPOINT + f"/meme/{create_task_id}")
#     assert get_task_response.status_code == 200
#     get_task_data = get_task_response.json()
#     assert get_task_data["id"] == create_task_id
#     assert get_task_data["url"] == payload

#     # Delete the item
#     delete_task_response = requests.delete(ENDPOINT + F"/meme/{create_task_id}")
#     assert delete_task_response.status_code == 200


# def test_can_delete():
#     payload = "example.com"

#     # Create the item
#     create_task_response = requests.put(ENDPOINT + "/meme", bytearray(payload, "utf-8"))
#     assert create_task_response.status_code == 200
#     create_task_id = create_task_response.json()["id"]

#     # Check that the item was properly created
#     get_task_response = requests.get(ENDPOINT + f"/meme/{create_task_id}")
#     assert get_task_response.status_code == 200
#     get_task_data = get_task_response.json()
#     assert get_task_data["id"] == create_task_id
#     assert get_task_data["url"] == payload

#     # Delete the item
#     delete_task_response = requests.delete(ENDPOINT + F"/meme/{create_task_id}")
#     assert delete_task_response.status_code == 200

#     # Check that the item was deleted
#     get_task_response = requests.get(ENDPOINT + f"/meme/{create_task_id}")
#     assert get_task_response.status_code == 404