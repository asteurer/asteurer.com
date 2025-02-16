<script lang="ts">
    import { onMount } from 'svelte';
    import { page } from '$app/stores';

    interface Meme {
        url: string;
        id: number;
    }

    interface MemeResponse {
        current_meme: Meme;
        previous_meme_id: number | null;
        next_meme_id: number | null;
    }

    let memeData: MemeResponse | null = null;
    let error: string | null = null;
    let loading = true;

    async function fetchMeme(id?: number) {
        loading = true;
        error = null;

        try {
            const baseUrl = 'http://10.0.0.4:30080';
            const url = id !== undefined
                ? `${baseUrl}/meme/${id}`
                : `${baseUrl}/latest_meme`;

            const response = await fetch(url);

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            memeData = await response.json();
        } catch (e) {
            error = e instanceof Error ? e.message : 'An error occurred while fetching the meme';
        } finally {
            loading = false;
        }
    }

    $: if ($page.params.id) {
        fetchMeme(parseInt($page.params.id));
    } else {
        fetchMeme();
    }
</script>

{#if loading}
    <div class="loading">Loading...</div>
{:else if error}
    <div class="error">{error}</div>
{:else if memeData}
    <nav>
        {#if memeData.previous_meme_id !== null}
            <a href="/memes/{memeData.previous_meme_id}">Previous Meme</a>
        {/if}

        {#if memeData.previous_meme_id !== null && memeData.next_meme_id !== null}
            <span>|</span>
        {/if}

        {#if memeData.next_meme_id !== null}
            <a href="/memes/{memeData.next_meme_id}">Next Meme</a>
        {/if}
    </nav>

    <div class="meme-container">
        <img
            src={memeData.current_meme.url}
            alt="Meme Image"
            width="600"
        />
    </div>
{/if}

<style>
    .loading, .error {
        text-align: center;
        padding: 1rem;
    }

    .error {
        color: red;
    }

    nav {
        margin-bottom: 1rem;
        text-align: center;
    }

    nav span {
        margin: 0 0.5rem;
    }

    .meme-container {
        text-align: center;
        margin-top: 1rem;
    }

    img {
        max-width: 100%;
        height: auto;
    }
</style>