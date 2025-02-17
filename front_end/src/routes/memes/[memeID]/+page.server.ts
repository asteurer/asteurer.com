import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
    // Parse the memeID
    if (!Number.isInteger(Number(params.memeID))) {
        throw error(400, `The memeID needs to be an integer. Received '${params.memeID}'.`);
    }

    let apiURL = `http://db-client:8080/meme/${params.memeID}`;

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