<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { fetchWaiverSession, type WaiverSessionDetail } from '$lib/api/waiver_sessions';
	import { apiGetBlob } from '$lib/api/client';
	import { formatDateTimeLocal } from '$lib/format/datetime';

	let session: WaiverSessionDetail | null = null;
	let loading = true;
	let error: string | null = null;
	let govFrontUrl = '';
	let govBackUrl = '';
	let selfieUrl = '';

	$: id = $page.params.id;

	onMount(load);

	async function loadBlob(path: string): Promise<string> {
		const res = await apiGetBlob(path);
		if (!res.ok || !res.data) return '';
		return URL.createObjectURL(res.data);
	}

	async function load() {
		loading = true;
		error = null;
		const res = await fetchWaiverSession(id);
		loading = false;
		if (!res.ok || !res.data) {
			error = res.error ?? 'Waiver session not found';
			return;
		}
		session = res.data;
		if (session.has_government_id_front) {
			govFrontUrl = await loadBlob(`/admin/waiver-sessions/${id}/government-id?side=front`);
		}
		if (session.has_government_id_back) {
			govBackUrl = await loadBlob(`/admin/waiver-sessions/${id}/government-id?side=back`);
		}
		if (session.has_selfie) {
			selfieUrl = await loadBlob(`/admin/waiver-sessions/${id}/selfie`);
		}
	}

	function uploadProgress(s: WaiverSessionDetail): string {
		const parts: string[] = [];
		parts.push(s.government_id_front_uploaded ? 'ID front ✓' : 'ID front —');
		parts.push(s.government_id_back_uploaded ? 'ID back ✓' : 'ID back —');
		parts.push(s.selfie_uploaded ? 'Selfie ✓' : 'Selfie —');
		return parts.join(' · ');
	}
</script>

<svelte:head>
	<title>Waiver session {id} — HydroDrags Admin</title>
</svelte:head>

{#if loading}
	<p>Loading…</p>
{:else if error}
	<p class="error">{error}</p>
{:else if session}
	<div class="page-header">
		<a href="/racers/{session.racer_id}" class="back">← Racer profile</a>
		<h1>{session.event_name}</h1>
		<p class="muted">
			{session.status} · created {formatDateTimeLocal(session.created_at)} · expires
			{formatDateTimeLocal(session.expires_at)}
		</p>
	</div>

	<div class="grid">
		<section class="card">
			<h2>Session details</h2>
			<dl class="meta">
				<dt>Status</dt><dd>{session.status}</dd>
				<dt>Event</dt><dd>{session.event_name}</dd>
				<dt>Gov ID type</dt><dd>{session.government_id_type ?? '—'}</dd>
				<dt>Upload progress</dt><dd>{uploadProgress(session)}</dd>
				<dt>Created</dt><dd>{formatDateTimeLocal(session.created_at)}</dd>
				<dt>Updated</dt><dd>{formatDateTimeLocal(session.updated_at)}</dd>
				<dt>Expires</dt><dd>{formatDateTimeLocal(session.expires_at)}</dd>
			</dl>
		</section>

		<section class="card">
			<h2>Uploaded images</h2>
			<div class="images">
				{#if govFrontUrl}
					<figure>
						<figcaption>Government ID (front)</figcaption>
						<img src={govFrontUrl} alt="Government ID front" />
					</figure>
				{/if}
				{#if govBackUrl}
					<figure>
						<figcaption>Government ID (back)</figcaption>
						<img src={govBackUrl} alt="Government ID back" />
					</figure>
				{/if}
				{#if selfieUrl}
					<figure>
						<figcaption>Selfie</figcaption>
						<img src={selfieUrl} alt="Selfie" />
					</figure>
				{/if}
				{#if !govFrontUrl && !govBackUrl && !selfieUrl}
					<p class="muted">No images uploaded yet.</p>
				{/if}
			</div>
		</section>
	</div>
{/if}

<style>
	.page-header {
		margin-bottom: 1.5rem;
	}
	.back {
		display: inline-block;
		margin-bottom: 0.5rem;
		color: var(--color-text-muted, #666);
		text-decoration: none;
	}
	.back:hover {
		text-decoration: underline;
	}
	.muted {
		color: var(--color-text-muted, #666);
		margin: 0.25rem 0 0;
	}
	.error {
		color: #c00;
	}
	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
		gap: 1rem;
	}
	.card {
		background: var(--bg-card, #fff);
		border: 1px solid var(--border, #ddd);
		border-radius: 8px;
		padding: 1.25rem;
	}
	.card h2 {
		margin: 0 0 1rem;
		font-size: 1rem;
	}
	.meta {
		display: grid;
		grid-template-columns: auto 1fr;
		gap: 0.35rem 1rem;
		margin: 0;
		font-size: 0.9rem;
	}
	.meta dt {
		color: var(--color-text-muted, #666);
	}
	.meta dd {
		margin: 0;
	}
	.images {
		display: flex;
		flex-wrap: wrap;
		gap: 1rem;
	}
	figure {
		margin: 0;
	}
	figcaption {
		font-size: 0.85rem;
		color: var(--color-text-muted, #666);
		margin-bottom: 0.35rem;
	}
	img {
		max-width: 100%;
		max-height: 240px;
		border-radius: 4px;
		border: 1px solid var(--border, #ddd);
	}
</style>
