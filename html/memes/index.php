<!-- Thanks ChatGPT -->

<?php
// Check if a specific meme ID is provided via GET parameter
if (isset($_GET['id'])) {
    $current_meme_id = intval($_GET['id']);
    $api_url = "https://asteurer.com/memes-api/{$current_meme_id}";
} else {
    $api_url = "https://asteurer.com/memes-api/";
}

// Fetch the JSON data from the API
$json_data = file_get_contents($api_url);
if ($json_data === false) {
    die("Error fetching data from API.");
}

// Decode the JSON data into an associative array
$data = json_decode($json_data, true);
if ($data === null) {
    die("Error decoding JSON data.");
}

// Extract current meme, previous and next IDs
$current_meme = $data['currentMeme'];
$previous_meme_id = $data['previousMemeID'];
$next_meme_id = $data['nextMemeID'];

// Construct the previous and next meme URLs
// Update these links to point to /meme/{id}
$previous_link = "/memes/{$previous_meme_id}";
$next_link = "/memes/{$next_meme_id}";

// Display the current meme and navigation links
echo "<img src='" . htmlspecialchars($current_meme['url']) . "' alt='Meme Image' width='600'><br><br>";

echo "<a href='{$previous_link}'>Previous Meme</a> | ";
echo "<a href='{$next_link}'>Next Meme</a>";
?>
