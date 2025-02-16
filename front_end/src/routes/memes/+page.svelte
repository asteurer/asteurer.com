<script lang="ts">
    import type { PageData } from './$types';

    export let data: PageData;
</script>

<br>
<a href="memes/{data.previous_meme_id}">Previous</a>
<a href="memes/{data.next_meme_id}">Next</a>
<br>
<br>
<img alt="current_meme" src={data.current_meme.url}>

<style>
	a {
	  margin-right: 1rem;  /* Adds spacing between links */
	}
  </style>
