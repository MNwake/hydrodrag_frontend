<script lang="ts">
	import { page } from '$app/stores';
	import { fetchRacer, type RacerProfile } from '$lib/api/resources';
	import { fetchRegistrationsByRacer } from '$lib/api/registrations';
	import type { EventRegistrationBase } from '$lib/api/events';

	let loading = true;
	let error: string | null = null;
	let racer: RacerProfile | null = null;
	let registrations: EventRegistrationBase[] = [];

	function fullName(r: RacerProfile): string {
		const full = (r.full_name ?? '').toString().trim();
		return full || '—';
	}

	function fmt(s: string | null | undefined): string {
		return s != null && String(s).trim() !== '' ? String(s).trim() : '—';
	}

	function fmtDate(iso: string | null | undefined): string {
		if (!iso) return '—';
		const d = new Date(iso);
		return Number.isNaN(d.getTime()) ? '—' : d.toLocaleDateString();
	}

	function fmtDateTime(iso: string | null | undefined): string {
		if (!iso) return '—';
		const d = new Date(iso);
		return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString();
	}

	function pwcDisplay(reg: EventRegistrationBase): string {
		if (reg.pwc_identifier != null && String(reg.pwc_identifier).trim()) return String(reg.pwc_identifier).trim();
		const p = reg.pwc;
		if (p?.identifier != null && String(p.identifier).trim()) return String(p.identifier).trim();
		if (p?.make != null || p?.model != null) {
			const parts = [p?.make, p?.model].filter(Boolean).map(String).map((s) => s.trim());
			if (parts.length) return parts.join(' ');
		}
		return '—';
	}

	async function load() {
		const id = $page.params.id;
		if (!id) return;
		loading = true;
		error = null;
		racer = null;
		registrations = [];
		const res = await fetchRacer(id);
		if (!res.ok) {
			loading = false;
			error = res.error ?? 'Racer not found';
			return;
		}
		racer = res.data;
		const regsRes = await fetchRegistrationsByRacer(id);
		loading = false;
		if (regsRes.ok && Array.isArray(regsRes.data)) {
			registrations = regsRes.data;
		}
	}

	$: id = $page.params.id;
	$: if (id) load();
</script>

<div class="page-header" style="display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 1rem;">
	<div>
		<h1 class="page-title">Racer profile</h1>
		<p class="page-subtitle">{racer ? fullName(racer) : '—'}</p>
	</div>
	<a href="/racers" class="btn btn-secondary">← Back to racers</a>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error || !racer}
	<div class="error-placeholder">
		{error ?? 'Racer not found'}
		<br />
		<a href="/racers">← Back to racers</a>
	</div>
{:else}
	<div class="racer-profile">
		<section class="profile-section">
			<h2 class="profile-section-title">Identity</h2>
			<dl class="profile-dl">
				<dt>Name</dt>
				<dd>{fullName(racer)}</dd>
				<dt>Email</dt>
				<dd>{fmt(racer.email)}</dd>
				<dt>Date of birth</dt>
				<dd>{fmtDate(racer.date_of_birth)}</dd>
				<dt>Gender</dt>
				<dd>{fmt(racer.gender)}</dd>
				<dt>Nationality</dt>
				<dd>{fmt(racer.nationality)}</dd>
			</dl>
		</section>

		<section class="profile-section">
			<h2 class="profile-section-title">Contact</h2>
			<dl class="profile-dl">
				<dt>Phone</dt>
				<dd>{fmt(racer.phone)}</dd>
				<dt>Emergency contact</dt>
				<dd>{fmt(racer.emergency_contact_name)}</dd>
				<dt>Emergency phone</dt>
				<dd>{fmt(racer.emergency_contact_phone)}</dd>
			</dl>
		</section>

		<section class="profile-section">
			<h2 class="profile-section-title">Address</h2>
			<dl class="profile-dl">
				<dt>Street</dt>
				<dd>{fmt(racer.street)}</dd>
				<dt>City</dt>
				<dd>{fmt(racer.city)}</dd>
				<dt>State / Province</dt>
				<dd>{fmt(racer.state_province)}</dd>
				<dt>Country</dt>
				<dd>{fmt(racer.country)}</dd>
				<dt>ZIP / Postal</dt>
				<dd>{fmt(racer.zip_postal_code)}</dd>
			</dl>
		</section>

		<section class="profile-section">
			<h2 class="profile-section-title">Racing</h2>
			<dl class="profile-dl">
				<dt>Class category</dt>
				<dd>{fmt(racer.class_category)}</dd>
				<dt>Organization</dt>
				<dd>{fmt(racer.organization)}</dd>
				<dt>Membership number</dt>
				<dd>{fmt(racer.membership_number)}</dd>
			</dl>
		</section>

		<section class="profile-section">
			<h2 class="profile-section-title">Waiver &amp; compliance</h2>
			<dl class="profile-dl">
				<dt>Waiver signed at</dt>
				<dd>{fmtDateTime(racer.waiver_signed_at)}</dd>
				<dt>Valid waiver</dt>
				<dd>{racer.has_valid_waiver === true ? 'Yes' : 'No'}</dd>
				<dt>Waiver path</dt>
				<dd>{fmt(racer.waiver_path)}</dd>
				<dt>Is of age</dt>
				<dd>{racer.is_of_age === true ? 'Yes' : 'No'}</dd>
				<dt>Profile complete</dt>
				<dd>{racer.profile_complete === true ? 'Yes' : 'No'}</dd>
			</dl>
		</section>

		{#if racer.bio || (racer.sponsors && racer.sponsors.length > 0)}
			<section class="profile-section">
				<h2 class="profile-section-title">Bio &amp; sponsors</h2>
				<dl class="profile-dl">
					{#if racer.bio}
						<dt>Bio</dt>
						<dd class="profile-bio">{fmt(racer.bio)}</dd>
					{/if}
					{#if racer.sponsors && racer.sponsors.length > 0}
						<dt>Sponsors</dt>
						<dd>{racer.sponsors.join(', ')}</dd>
					{/if}
				</dl>
			</section>
		{/if}

		<section class="profile-section">
			<h2 class="profile-section-title">IDs &amp; assets</h2>
			<dl class="profile-dl">
				<dt>ID</dt>
				<dd><code class="profile-id">{racer.id}</code></dd>
				<dt>Profile image</dt>
				<dd>{fmt(racer.profile_image_path)}</dd>
				<dt>Profile image updated</dt>
				<dd>{fmtDateTime(racer.profile_image_updated_at)}</dd>
				<dt>Banner image</dt>
				<dd>{fmt(racer.banner_image_path)}</dd>
				<dt>Banner image updated</dt>
				<dd>{fmtDateTime(racer.banner_image_updated_at)}</dd>
			</dl>
		</section>
	</div>

	<section class="profile-registrations">
		<h2 class="profile-section-title">Registrations</h2>
		{#if registrations.length === 0}
			<p class="profile-registrations-empty">No event registrations.</p>
		{:else}
			<div class="data-table-wrap">
				<table class="data-table">
					<thead>
						<tr>
							<th>Event</th>
							<th>Class</th>
							<th>PWC</th>
							<th>Price</th>
							<th>Paid</th>
							<th>Losses</th>
							<th>Eliminated</th>
							<th>Created</th>
						</tr>
					</thead>
					<tbody>
						{#each registrations as reg}
							<tr>
								<td data-label="Event">
									<a href="/events/{reg.event}/manage">Event {reg.event}</a>
								</td>
								<td data-label="Class">{reg.class_name || reg.class_key || '—'}</td>
								<td data-label="PWC">{pwcDisplay(reg)}</td>
								<td data-label="Price">${reg.price.toFixed(2)}</td>
								<td data-label="Paid">{reg.is_paid ? 'Yes' : 'No'}</td>
								<td data-label="Losses">{reg.losses ?? 0}</td>
								<td data-label="Eliminated">{reg.is_eliminated ? 'Yes' : 'No'}</td>
								<td data-label="Created">{fmtDateTime(reg.created_at)}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	</section>
{/if}

<style>
	.racer-profile {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
		gap: 1.5rem;
	}
	.profile-section {
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		box-shadow: var(--shadow);
		padding: 1.25rem;
	}
	.profile-section-title {
		font-size: 1rem;
		font-weight: 600;
		margin: 0 0 1rem;
		padding-bottom: 0.5rem;
		border-bottom: 1px solid var(--border);
		color: var(--text);
	}
	.profile-dl {
		display: grid;
		grid-template-columns: auto 1fr;
		gap: 0.35rem 1.5rem;
		margin: 0;
		font-size: 0.9rem;
	}
	.profile-dl dt {
		color: var(--text-muted);
		font-weight: 500;
	}
	.profile-dl dd {
		margin: 0;
		color: var(--text);
	}
	.profile-bio {
		white-space: pre-wrap;
		max-width: 40ch;
	}
	.profile-id {
		font-size: 0.85em;
		background: var(--bg-muted);
		padding: 0.2rem 0.4rem;
		border-radius: 4px;
	}
	.profile-registrations {
		margin-top: 2rem;
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		box-shadow: var(--shadow);
		padding: 1.25rem;
	}
	.profile-registrations .profile-section-title {
		margin-top: 0;
	}
	.profile-registrations-empty {
		margin: 0;
		color: var(--text-muted);
		font-size: 0.95rem;
	}
</style>
