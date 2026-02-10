<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import EventForm from '$lib/components/EventForm.svelte';
	import Modal from '$lib/components/Modal.svelte';
	import { fetchEvent, updateEvent, deleteEvent, uploadEventImage } from '$lib/api/events';
	import { toast } from '$lib/stores/toast';
	import type { EventBase, EventUpdate } from '$lib/api/events';

	let loading = true;
	let saving = false;
	let error = '';
	let event: EventBase | null = null;
	let showDeleteModal = false;
	let deleting = false;

	async function load() {
		const id = $page.params.id;
		if (!id) return;
		loading = true;
		error = '';
		const res = await fetchEvent(id);
		loading = false;
		if (!res.ok) {
			error = res.error ?? 'Event not found';
			event = null;
			return;
		}
		event = res.data?.event ?? null;
	}

	async function handleSubmit(payload: EventUpdate) {
		if (!event) return;
		saving = true;
		error = '';
		const res = await updateEvent(event.id, payload);
		saving = false;
		if (res.ok && res.data) {
			toast('Changes saved', 'success');
			event = res.data;
		} else {
			error = res.error ?? 'Save failed';
		}
	}

	async function handleUploadImage(file: File) {
		if (!event) return;
		const res = await uploadEventImage(event.id, file);
		if (res.ok && res.data) {
			toast('Image uploaded', 'success');
			event = res.data;
		} else {
			toast(res.error ?? 'Image upload failed', 'error');
		}
	}

	async function handleDelete() {
		if (!event) return;
		deleting = true;
		const res = await deleteEvent(event.id);
		deleting = false;
		showDeleteModal = false;
		if (res.ok) {
			toast('Event deleted', 'success');
			await goto('/events');
		} else {
			toast(res.error ?? 'Delete failed', 'error');
		}
	}

	$: id = $page.params.id;
	$: if (id) load();
</script>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error && !event}
	<div class="error-placeholder">
		{error}
		<br />
		<a href="/events">← Back to events</a>
	</div>
{:else if event}
	<div class="page-header" style="display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 1rem;">
		<div>
			<h1 class="page-title">Edit event</h1>
			<p class="page-subtitle">{event.name}</p>
		</div>
		<a href="/events/{event.id}/manage" class="btn btn-secondary">Manage registrations</a>
	</div>

	<EventForm
		mode="edit"
		initial={event}
		loading={saving}
		{error}
		onsubmit={handleSubmit}
		ondelete={() => (showDeleteModal = true)}
		onUploadImage={handleUploadImage}
	/>
{/if}

<Modal open={showDeleteModal} title="Delete event">
	{#if event}
		<p>Delete <strong>{event.name}</strong>? This cannot be undone.</p>
	{/if}
	<svelte:fragment slot="footer">
		<button type="button" class="btn btn-secondary" on:click={() => (showDeleteModal = false)}>
			Cancel
		</button>
		<button
			type="button"
			class="btn btn-danger btn-sm"
			disabled={deleting}
			on:click={handleDelete}
		>
			{deleting ? 'Deleting…' : 'Delete'}
		</button>
	</svelte:fragment>
</Modal>
