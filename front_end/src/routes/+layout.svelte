<script lang="ts">
	let { children } = $props();
</script>

<nav>
	<h3><a href="/">Home</a></h3>
	<h3><a href="/memes">Memes</a></h3>
	<h3><a href="/resume">Resume</a></h3>
</nav>

{@render children()}

<style>
	nav {
		display: flex;
		justify-content: left;
		text-align: left;
	}
	nav h3 {
	  margin-right: 1rem;  /* Adds spacing between links */
	}
	nav h3:last-child { /* Remove margin from last link */
	  margin-right: 0;
	}
  </style>