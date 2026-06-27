<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import {
		downloadWaiverPdf,
		fetchWaiver,
		waiverImageUrl,
		type WaiverDetail
	} from '$lib/api/waivers';
	import { apiGetBlob } from '$lib/api/client';
	import { formatDateTimeLocal } from '$lib/format/datetime';

	let waiver: WaiverDetail | null = null;
	let loading = true;
	let error: string | null = null;
	let govFrontUrl = '';
	let govBackUrl = '';
	let selfieUrl = '';
	let signatureUrl = '';

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
		const res = await fetchWaiver(id);
		loading = false;
		if (!res.ok || !res.data) {
			error = res.error ?? 'Waiver not found';
			return;
		}
		waiver = res.data;
		govFrontUrl = await loadBlob(`/admin/waivers/${id}/government-id?side=front`);
		selfieUrl = await loadBlob(`/admin/waivers/${id}/selfie`);
		signatureUrl = await loadBlob(`/admin/waivers/${id}/signature`);
		if (waiver.has_government_id_back) {
			govBackUrl = await loadBlob(`/admin/waivers/${id}/government-id?side=back`);
		}
	}

	async function downloadPdf() {
		await downloadWaiverPdf(id, `waiver_${id}.pdf`);
	}
</script>

<svelte:head>
	<title>Waiver {id} — HydroDrags Admin</title>
</svelte:head>

{#if loading}
	<p>Loading…</p>
{:else if error}
	<p class="error">{error}</p>
{:else if waiver}
	<div class="page-header">
		<a href="/waivers" class="back">← Waivers</a>
		<h1>{waiver.event_name}</h1>
		<p class="muted">{waiver.typed_legal_name} · {formatDateTimeLocal(waiver.signed_at_utc)}</p>
		<div class="actions">
			<button type="button" class="btn btn-primary" on:click={downloadPdf}>Download PDF</button>
		</div>
	</div>

	<div class="grid">
		<section class="card">
			<h2>Identity images</h2>
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
				{#if signatureUrl}
					<figure>
						<figcaption>Signature</figcaption>
						<img src={signatureUrl} alt="Signature" />
					</figure>
				{/if}
			</div>
		</section>

		<section class="card">
			<h2>Evidence metadata</h2>
			<dl class="meta">
				<dt>Waiver version</dt><dd>{waiver.waiver_version}</dd>
				<dt>Waiver SHA-256</dt><dd class="mono">{waiver.waiver_sha256}</dd>
				<dt>Gov ID type</dt><dd>{waiver.government_id_type}</dd>
				<dt>Email</dt><dd>{waiver.authenticated_email ?? '—'}</dd>
				<dt>Phone</dt><dd>{waiver.authenticated_phone ?? '—'}</dd>
				<dt>IP</dt><dd>{waiver.ip_address ?? '—'}</dd>
				<dt>Platform</dt><dd>{waiver.platform ?? '—'} / {waiver.operating_system ?? '—'}</dd>
				<dt>App</dt><dd>{waiver.app_version ?? '—'} ({waiver.build_number ?? '—'})</dd>
				<dt>Timezone</dt><dd>{waiver.timezone_name ?? '—'} ({waiver.timezone_offset_minutes ?? '—'} min)</dd>
				<dt>Venue</dt><dd>{waiver.venue_name ?? '—'}{waiver.venue_address ? ` — ${waiver.venue_address}` : ''}</dd>
			</dl>
		</section>

		<section class="card full">
			<h2>Waiver text</h2>
			<div class="waiver-html">{@html waiver.waiver_text}</div>
		</section>
	</div>
{/if}

<style>
	.page-header { margin-bottom: 1.5rem; }
	.back { display: inline-block; margin-bottom: 0.5rem; }
	.muted { color: #666; }
	.actions { margin-top: 1rem; }
	.grid { display: grid; gap: 1rem; grid-template-columns: 1fr 1fr; }
	.full { grid-column: 1 / -1; }
	.card { background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 1rem; }
	.images { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 1rem; }
	figure img { max-width: 100%; border: 1px solid #eee; border-radius: 4px; }
	.meta { display: grid; grid-template-columns: 140px 1fr; gap: 0.35rem 1rem; font-size: 0.9rem; }
	.mono { font-family: monospace; font-size: 0.75rem; word-break: break-all; }
	.waiver-html { max-height: 400px; overflow: auto; font-size: 0.9rem; }
	.error { color: #c00; }
	@media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }
</style>
