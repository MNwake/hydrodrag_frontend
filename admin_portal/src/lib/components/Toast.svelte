<script lang="ts">
	import { toastMessages, dismissToast } from '$lib/stores/toast';
</script>

<div class="toast-container" role="region" aria-label="Notifications">
	{#each $toastMessages as t}
		<button
			type="button"
			class="toast {t.kind}"
			aria-label="Dismiss notification"
			on:click={() => dismissToast(t.id)}
		>
			{t.text}
		</button>
	{/each}
</div>
