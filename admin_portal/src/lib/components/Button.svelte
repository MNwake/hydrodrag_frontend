<script lang="ts">
	/**
	 * Generic Button. variant: 'primary' | 'secondary' | 'text', size?: 'sm'
	 */

	export let variant: 'primary' | 'secondary' | 'text' = 'primary';
	export let size: 'sm' | 'md' = 'md';
	export let type: 'button' | 'submit' = 'button';
	export let disabled = false;
</script>

<button
	{type}
	{disabled}
	class="btn btn-{variant} {size === 'sm' ? 'btn-sm' : ''}"
	on:click
>
	<slot />
</button>
