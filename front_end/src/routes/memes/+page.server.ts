import { error } from '@sveltejs/kit';
import type { PageLoad } from './$types';
import { getDBClientEndpoint } from '$lib/config.js';
import { env } from '$env/dynamic/private';

export const load: PageLoad = async ({ params }) => {
    let url = `${getDBClientEndpoint()}/latest_meme`;

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