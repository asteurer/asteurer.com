import { error } from '@sveltejs/kit';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params }) => {
    // Parse the memeID and determine the apiURL
    let apiURL = "http://db-client:8080/latest_meme";

    // Fetch the JSON data from the API
    try {
        const response = await fetch(apiURL);
        if (!response.ok) {
            throw error(response.status, `failed to fetch meme: ${response.statusText}`);
        }

        const data = await response.json();
        return data;
    } catch (err) {
        console.error(err);
        throw error(500, 'Failed to load meme data');
    }
}