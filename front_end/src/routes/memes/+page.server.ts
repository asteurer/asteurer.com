import { error } from '@sveltejs/kit';
import type { PageLoad } from './$types';
import { env } from '$env/dynamic/private';

export const load: PageLoad = async ({ params }) => {
    // Parse the memeID and determine the apiURL
    let apiURL = `${env.API_URL}/latest_meme`;

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
        throw error(500, `Failed to load meme data`);
    }
}