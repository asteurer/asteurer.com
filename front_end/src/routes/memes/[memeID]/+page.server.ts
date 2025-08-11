import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import { env } from '$env/dynamic/private';
import { getDBClientEndpoint } from '$lib/config.js';

export const load: PageServerLoad = async ({ params }) => {
    if (!Number.isInteger(Number(params.memeID))) {
        throw error(400, `The memeID needs to be an integer. Received '${params.memeID}'.`);
    }

    let url = `${getDBClientEndpoint()}/meme/${params.memeID}`;

    try {
        const response = await fetch(url);
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