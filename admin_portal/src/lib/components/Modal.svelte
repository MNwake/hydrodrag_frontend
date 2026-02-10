<script lang="ts">
	/**
	 * Modal dialog for future admin actions.
	 */

	export let open = false;
	export let title = '';

	function close() {
		open = false;
	}
</script>

<svelte:window on:keydown={(e) => open && e.key === 'Escape' && close()} />

{#if open}
	<div class="modal-backdrop-wrap">
		<button
			type="button"
			class="modal-backdrop"
			aria-label="Close modal"
			on:click={close}
		></button>
		<div
			class="modal"
			role="dialog"
			aria-modal="true"
			aria-labelledby={title ? 'modal-title' : undefined}
		>
			{#if title}
				<div class="modal-header" id="modal-title">{title}</div>
			{/if}
			<div class="modal-body">
				<slot />
			</div>
			<div class="modal-footer">
				<slot name="footer" />
			</div>
		</div>
	</div>
{/if}
