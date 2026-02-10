<script lang="ts">
	import { goto } from '$app/navigation';
	import EventForm from '$lib/components/EventForm.svelte';
	import { createEvent, uploadEventImage, type EventCreate } from '$lib/api/events';
	import { toast } from '$lib/stores/toast';

	let loading = false;
	let error = '';

	async function handleSubmit(
		payload: EventCreate | import('$lib/api/events').EventUpdate,
		pendingImageFile?: File | null
	) {
		loading = true;
		error = '';
		const res = await createEvent(payload as EventCreate);
		if (!res.ok || !res.data) {
			loading = false;
			error = res.error ?? 'Create failed';
			return;
		}
		const eventId = res.data.id;
		if (pendingImageFile) {
			const up = await uploadEventImage(eventId, pendingImageFile);
			if (!up.ok) toast(up.error ?? 'Image upload failed', 'error');
			else toast('Event created', 'success');
		} else {
			toast('Event created', 'success');
		}
		loading = false;
		await goto(`/events/${eventId}`);
	}
</script>

<div class="page-header">
	<h1 class="page-title">New event</h1>
	<p class="page-subtitle">Create an event and set schedule, location, and rules.</p>
</div>

<EventForm
	mode="create"
	initial={null}
	{loading}
	{error}
	onsubmit={handleSubmit}
/>
