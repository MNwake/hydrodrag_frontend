<script lang="ts">
	import { page } from '$app/stores';
	import {
		fetchRacer,
		downloadRacerWaiver,
		updateRacer,
		type RacerProfile
	} from '$lib/api/resources';
	import { fetchRegistrationsByRacer } from '$lib/api/registrations';
	import type { EventRegistrationAdmin } from '$lib/api/registrations';
	import { toast } from '$lib/stores/toast';

	let loading = true;
	let error: string | null = null;
	let racer: RacerProfile | null = null;
	let registrations: EventRegistrationAdmin[] = [];
	let waiverDownloading: number | null = null;

	let editing = false;
	let saving = false;

	type RacerEditForm = {
		email: string;
		first_name: string;
		last_name: string;
		date_of_birth: string;
		gender: string;
		nationality: string;
		phone: string;
		emergency_contact_name: string;
		emergency_contact_phone: string;
		street: string;
		city: string;
		state_province: string;
		country: string;
		zip_postal_code: string;
		class_category: string;
		organization: string;
		membership_number: string;
		membership_purchased_at_local: string;
		bio: string;
		sponsorsText: string;
		pwcIdsText: string;
		profile_image_path: string;
		banner_image_path: string;
		profile_image_updated_at_local: string;
		banner_image_updated_at_local: string;
		waiverPathsText: string;
		waiver_signed_at_local: string;
	};

	let form: RacerEditForm = emptyForm();

	function emptyForm(): RacerEditForm {
		return {
			email: '',
			first_name: '',
			last_name: '',
			date_of_birth: '',
			gender: '',
			nationality: '',
			phone: '',
			emergency_contact_name: '',
			emergency_contact_phone: '',
			street: '',
			city: '',
			state_province: '',
			country: '',
			zip_postal_code: '',
			class_category: '',
			organization: '',
			membership_number: '',
			membership_purchased_at_local: '',
			bio: '',
			sponsorsText: '',
			pwcIdsText: '',
			profile_image_path: '',
			banner_image_path: '',
			profile_image_updated_at_local: '',
			banner_image_updated_at_local: '',
			waiverPathsText: '',
			waiver_signed_at_local: ''
		};
	}

	function toDateInput(iso: string | null | undefined): string {
		if (!iso) return '';
		const s = String(iso);
		return s.length >= 10 ? s.slice(0, 10) : s;
	}

	function toDatetimeLocal(iso: string | null | undefined): string {
		if (!iso) return '';
		const d = new Date(iso);
		if (Number.isNaN(d.getTime())) return '';
		const p = (n: number) => String(n).padStart(2, '0');
		return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
	}

	function fromDatetimeLocal(s: string): string | null {
		const t = s.trim();
		if (!t) return null;
		const d = new Date(t);
		if (Number.isNaN(d.getTime())) return null;
		return d.toISOString();
	}

	function syncFormFromRacer(r: RacerProfile) {
		form = {
			email: (r.email ?? '').toString(),
			first_name: (r.first_name ?? '').toString(),
			last_name: (r.last_name ?? '').toString(),
			date_of_birth: toDateInput(r.date_of_birth),
			gender: (r.gender ?? '').toString(),
			nationality: (r.nationality ?? '').toString(),
			phone: (r.phone ?? '').toString(),
			emergency_contact_name: (r.emergency_contact_name ?? '').toString(),
			emergency_contact_phone: (r.emergency_contact_phone ?? '').toString(),
			street: (r.street ?? '').toString(),
			city: (r.city ?? '').toString(),
			state_province: (r.state_province ?? '').toString(),
			country: (r.country ?? '').toString(),
			zip_postal_code: (r.zip_postal_code ?? '').toString(),
			class_category: (r.class_category ?? '').toString(),
			organization: (r.organization ?? '').toString(),
			membership_number: (r.membership_number ?? '').toString(),
			membership_purchased_at_local: toDatetimeLocal(r.membership_purchased_at),
			bio: (r.bio ?? '').toString(),
			sponsorsText: (r.sponsors ?? []).join('\n'),
			pwcIdsText: (r.pwc_id ?? []).join(', '),
			profile_image_path: (r.profile_image_path ?? '').toString(),
			banner_image_path: (r.banner_image_path ?? '').toString(),
			profile_image_updated_at_local: toDatetimeLocal(r.profile_image_updated_at),
			banner_image_updated_at_local: toDatetimeLocal(r.banner_image_updated_at),
			waiverPathsText: (r.waiver_paths ?? []).join('\n'),
			waiver_signed_at_local: toDatetimeLocal(r.waiver_signed_at)
		};
	}

	function buildPatchBody(): Record<string, unknown> {
		const sponsors = form.sponsorsText
			.split('\n')
			.map((s) => s.trim())
			.filter(Boolean);
		const pwc_id = form.pwcIdsText
			.split(/[\n,]+/)
			.map((s) => s.trim())
			.filter(Boolean);
		const waiver_paths = form.waiverPathsText
			.split('\n')
			.map((s) => s.trim())
			.filter(Boolean);

		const dob = form.date_of_birth.trim();

		return {
			email: form.email.trim(),
			first_name: form.first_name.trim() || null,
			last_name: form.last_name.trim() || null,
			date_of_birth: dob ? dob : null,
			gender: form.gender.trim() || null,
			nationality: form.nationality.trim() || null,
			phone: form.phone.trim() || null,
			emergency_contact_name: form.emergency_contact_name.trim() || null,
			emergency_contact_phone: form.emergency_contact_phone.trim() || null,
			street: form.street.trim() || null,
			city: form.city.trim() || null,
			state_province: form.state_province.trim() || null,
			country: form.country.trim() || null,
			zip_postal_code: form.zip_postal_code.trim() || null,
			class_category: form.class_category.trim() || null,
			organization: form.organization.trim() || null,
			membership_number: form.membership_number.trim() || null,
			membership_purchased_at: fromDatetimeLocal(form.membership_purchased_at_local),
			bio: form.bio.trim() || null,
			sponsors,
			pwc_id,
			profile_image_path: form.profile_image_path.trim() || null,
			banner_image_path: form.banner_image_path.trim() || null,
			profile_image_updated_at: fromDatetimeLocal(form.profile_image_updated_at_local),
			banner_image_updated_at: fromDatetimeLocal(form.banner_image_updated_at_local),
			waiver_paths,
			waiver_signed_at: fromDatetimeLocal(form.waiver_signed_at_local)
		};
	}

	async function saveProfile() {
		if (!racer || saving) return;
		if (!form.email.trim()) {
			toast('Email is required', 'error');
			return;
		}
		saving = true;
		const res = await updateRacer(racer.id, buildPatchBody());
		saving = false;
		if (res.ok && res.data) {
			racer = res.data;
			editing = false;
			toast('Profile saved', 'success');
			return;
		}
		toast(res.error ?? 'Failed to save profile', 'error');
	}

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

	async function onDownloadWaiver(racerId: string, index: number) {
		waiverDownloading = index;
		const result = await downloadRacerWaiver(racerId, index);
		waiverDownloading = null;
		if (!result.ok && result.error) {
			console.error(result.error);
			toast(result.error, 'error');
		}
	}

	function pwcDisplay(reg: EventRegistrationAdmin): string {
		if (reg.pwc_identifier != null && String(reg.pwc_identifier).trim())
			return String(reg.pwc_identifier).trim();
		return '—';
	}

	async function load() {
		const id = $page.params.id;
		if (!id) return;
		editing = false;
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

	function startEditing() {
		if (racer) syncFormFromRacer(racer);
		editing = true;
	}

	$: id = $page.params.id;
	$: if (id) load();
</script>

<div
	class="page-header"
	style="display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 1rem;"
>
	<div>
		<h1 class="page-title">Racer profile</h1>
		<p class="page-subtitle">{racer ? fullName(racer) : '—'}</p>
	</div>
	<div class="page-header-actions">
		{#if racer}
			{#if !editing}
				<button type="button" class="btn btn-primary" on:click={startEditing}>Edit profile</button>
			{:else}
				<button type="button" class="btn btn-secondary" on:click={() => (editing = false)} disabled={saving}
					>Cancel</button
				>
				<button type="submit" form="racer-edit-form" class="btn btn-primary" disabled={saving}>
					{saving ? 'Saving…' : 'Save changes'}
				</button>
			{/if}
		{/if}
		<a href="/racers" class="btn btn-secondary">← Back to racers</a>
	</div>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error || !racer}
	<div class="error-placeholder">
		{error ?? 'Racer not found'}
		<br />
		<a href="/racers">← Back to racers</a>
	</div>
{:else if !editing}
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
				<dt>Membership purchased at</dt>
				<dd>{fmtDateTime(racer.membership_purchased_at)}</dd>
			</dl>
		</section>

		<section class="profile-section">
			<h2 class="profile-section-title">Bio &amp; sponsors</h2>
			<dl class="profile-dl">
				<dt>Bio</dt>
				<dd class="profile-bio">{fmt(racer.bio)}</dd>
				<dt>Sponsors</dt>
				<dd>{racer.sponsors && racer.sponsors.length > 0 ? racer.sponsors.join(', ') : '—'}</dd>
			</dl>
		</section>

		<section class="profile-section">
			<h2 class="profile-section-title">PWC IDs</h2>
			<dl class="profile-dl">
				<dt>Linked PWC IDs</dt>
				<dd>
					{#if racer.pwc_id && racer.pwc_id.length > 0}
						<ul class="inline-list">
							{#each racer.pwc_id as pid}
								<li><code>{pid}</code></li>
							{/each}
						</ul>
					{:else}
						—
					{/if}
				</dd>
			</dl>
		</section>

		<section class="profile-section">
			<h2 class="profile-section-title">Waiver &amp; compliance</h2>
			<dl class="profile-dl">
				<dt>Waiver signed at</dt>
				<dd>{fmtDateTime(racer.waiver_signed_at)}</dd>
				<dt>Valid waiver</dt>
				<dd>{racer.has_valid_waiver === true ? 'Yes' : 'No'}</dd>
				<dt>Waivers</dt>
				<dd>
					{#if racer.waiver_paths && racer.waiver_paths.length > 0}
						<ul class="waiver-list">
							{#each racer.waiver_paths as path, i}
								<li class="waiver-item">
									<span class="waiver-path" title={path}>{path.split(/[/\\]/).pop() ?? path}</span>
									<button
										type="button"
										class="btn btn-secondary btn-sm"
										disabled={waiverDownloading === i}
										on:click={() => racer && onDownloadWaiver(racer.id, i)}
									>
										{waiverDownloading === i ? 'Downloading…' : 'Download'}
									</button>
								</li>
							{/each}
						</ul>
					{:else}
						—
					{/if}
				</dd>
				<dt>Is of age</dt>
				<dd>{racer.is_of_age === true ? 'Yes' : 'No'}</dd>
				<dt>Profile complete</dt>
				<dd>{racer.profile_complete === true ? 'Yes' : 'No'}</dd>
			</dl>
		</section>

		<section class="profile-section">
			<h2 class="profile-section-title">Assets</h2>
			<dl class="profile-dl">
				<dt>ID</dt>
				<dd><code class="profile-id">{racer.id}</code></dd>
				<dt>Profile image path</dt>
				<dd>{fmt(racer.profile_image_path)}</dd>
				<dt>Profile image updated</dt>
				<dd>{fmtDateTime(racer.profile_image_updated_at)}</dd>
				<dt>Banner image path</dt>
				<dd>{fmt(racer.banner_image_path)}</dd>
				<dt>Banner image updated</dt>
				<dd>{fmtDateTime(racer.banner_image_updated_at)}</dd>
			</dl>
		</section>
	</div>
{:else}
	{#if racer}
	{@const racerId = racer.id}
	<form id="racer-edit-form" class="racer-edit-form" on:submit|preventDefault={saveProfile}>
		<div class="form-card">
			<h2 class="form-section-title">Identity</h2>
			<div class="form-grid">
				<div class="form-group" style="grid-column: span 2;">
					<label for="edit-email">Email <span class="label-required" aria-hidden="true">*</span></label>
					<input id="edit-email" type="email" bind:value={form.email} autocomplete="off" required />
				</div>
				<div class="form-group">
					<label for="edit-first">First name</label>
					<input id="edit-first" type="text" bind:value={form.first_name} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-last">Last name</label>
					<input id="edit-last" type="text" bind:value={form.last_name} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-dob">Date of birth</label>
					<input id="edit-dob" type="date" bind:value={form.date_of_birth} />
				</div>
				<div class="form-group">
					<label for="edit-gender">Gender</label>
					<input id="edit-gender" type="text" bind:value={form.gender} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-nationality">Nationality</label>
					<input id="edit-nationality" type="text" bind:value={form.nationality} autocomplete="off" />
				</div>
			</div>
		</div>

		<div class="form-card">
			<h2 class="form-section-title">Contact</h2>
			<div class="form-grid">
				<div class="form-group">
					<label for="edit-phone">Phone</label>
					<input id="edit-phone" type="text" bind:value={form.phone} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-ec-name">Emergency contact</label>
					<input id="edit-ec-name" type="text" bind:value={form.emergency_contact_name} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-ec-phone">Emergency phone</label>
					<input id="edit-ec-phone" type="text" bind:value={form.emergency_contact_phone} autocomplete="off" />
				</div>
			</div>
		</div>

		<div class="form-card">
			<h2 class="form-section-title">Address</h2>
			<div class="form-grid">
				<div class="form-group" style="grid-column: span 2;">
					<label for="edit-street">Street</label>
					<input id="edit-street" type="text" bind:value={form.street} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-city">City</label>
					<input id="edit-city" type="text" bind:value={form.city} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-state">State / Province</label>
					<input id="edit-state" type="text" bind:value={form.state_province} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-country">Country</label>
					<input id="edit-country" type="text" bind:value={form.country} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-zip">ZIP / Postal</label>
					<input id="edit-zip" type="text" bind:value={form.zip_postal_code} autocomplete="off" />
				</div>
			</div>
		</div>

		<div class="form-card">
			<h2 class="form-section-title">Racing</h2>
			<div class="form-grid">
				<div class="form-group">
					<label for="edit-class">Class category</label>
					<input id="edit-class" type="text" bind:value={form.class_category} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-org">Organization</label>
					<input id="edit-org" type="text" bind:value={form.organization} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-membership">Membership number</label>
					<input id="edit-membership" type="text" bind:value={form.membership_number} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-membership-purchased">Membership purchased at</label>
					<input
						id="edit-membership-purchased"
						type="datetime-local"
						bind:value={form.membership_purchased_at_local}
					/>
				</div>
			</div>
		</div>

		<div class="form-card">
			<h2 class="form-section-title">Bio &amp; sponsors</h2>
			<div class="form-group">
				<label for="edit-bio">Bio</label>
				<textarea id="edit-bio" bind:value={form.bio} rows="4"></textarea>
			</div>
			<div class="form-group">
				<label for="edit-sponsors">Sponsors (one per line)</label>
				<textarea id="edit-sponsors" bind:value={form.sponsorsText} rows="3"></textarea>
			</div>
		</div>

		<div class="form-card">
			<h2 class="form-section-title">PWC links</h2>
			<div class="form-group">
				<label for="edit-pwc">PWC IDs (comma or newline separated)</label>
				<textarea id="edit-pwc" bind:value={form.pwcIdsText} rows="2"></textarea>
			</div>
		</div>

		<div class="form-card">
			<h2 class="form-section-title">Waivers</h2>
			<div class="form-group">
				<label for="edit-waiver-paths">Waiver file paths (one per line)</label>
				<textarea id="edit-waiver-paths" bind:value={form.waiverPathsText} rows="3"></textarea>
				<p class="form-hint">
					Changing paths does not move files on disk. Use downloads below only for existing files.
				</p>
			</div>
			<div class="form-group">
				<label for="edit-waiver-signed">Waiver signed at</label>
				<input id="edit-waiver-signed" type="datetime-local" bind:value={form.waiver_signed_at_local} />
			</div>
			{#if racer.waiver_paths && racer.waiver_paths.length > 0}
				<ul class="waiver-list waiver-list--compact">
					{#each racer.waiver_paths as path, i}
						<li class="waiver-item">
							<span class="waiver-path" title={path}>{path.split(/[/\\]/).pop() ?? path}</span>
							<button
								type="button"
								class="btn btn-secondary btn-sm"
								disabled={waiverDownloading === i}
								on:click={() => onDownloadWaiver(racerId, i)}
							>
								{waiverDownloading === i ? 'Downloading…' : 'Download'}
							</button>
						</li>
					{/each}
				</ul>
			{/if}
		</div>

		<div class="form-card">
			<h2 class="form-section-title">Image assets</h2>
			<div class="form-grid">
				<div class="form-group" style="grid-column: span 2;">
					<label for="edit-profile-path">Profile image path</label>
					<input id="edit-profile-path" type="text" bind:value={form.profile_image_path} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-profile-updated">Profile image updated</label>
					<input
						id="edit-profile-updated"
						type="datetime-local"
						bind:value={form.profile_image_updated_at_local}
					/>
				</div>
				<div class="form-group" style="grid-column: span 2;">
					<label for="edit-banner-path">Banner image path</label>
					<input id="edit-banner-path" type="text" bind:value={form.banner_image_path} autocomplete="off" />
				</div>
				<div class="form-group">
					<label for="edit-banner-updated">Banner image updated</label>
					<input
						id="edit-banner-updated"
						type="datetime-local"
						bind:value={form.banner_image_updated_at_local}
					/>
				</div>
			</div>
			<p class="form-hint">
				Racer ID (
				<code class="profile-id">{racerId}</code>
				) is read-only. Image uploads are still done from the mobile app unless you add an admin upload flow.
			</p>
		</div>
	</form>
	{/if}
{/if}

{#if racer && !loading && !error}
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
									<a href="/events/{reg.event.id}/manage">{reg.event.name ?? reg.event.id}</a>
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
	.page-header-actions {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
		align-items: center;
	}

	.label-required {
		color: var(--error);
		font-weight: 600;
	}

	.racer-edit-form {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.racer-edit-form .form-card {
		margin-bottom: 0;
	}

	.racer-edit-form .form-section-title {
		margin-top: 0;
	}

	.form-hint {
		margin: 0.5rem 0 0;
		font-size: 0.85rem;
		color: var(--text-muted);
	}

	.inline-list {
		margin: 0;
		padding-left: 1.25rem;
	}

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
	.waiver-list {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}
	.waiver-list--compact {
		margin-top: 0.75rem;
	}
	.waiver-item {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		flex-wrap: wrap;
	}
	.waiver-path {
		font-size: 0.85em;
		color: var(--text-muted);
		max-width: 24ch;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
</style>
