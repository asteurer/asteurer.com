<script lang="ts">
    import type { PageData } from './$types';

    export let data: PageData;
</script>

<br>
<a href="{data.previous_meme_id}">Previous</a>
<a href="{data.next_meme_id}">Next</a>
<br>
<br>
<img alt="Current Meme" src="/api/memes/{data.current_meme.file_name}">

<style>
  img {
    max-width: 100%;
    height: auto;
  }

	a {
	  margin-right: 1rem;  /* Adds spacing between links */
	}
  </style>