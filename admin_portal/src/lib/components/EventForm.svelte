<script lang="ts">
	import type {
		EventBase,
		EventCreate,
		EventUpdate,
		EventScheduleItem,
		EventInfo,
		EventLocation,
		EventRule,
		EventClass,
		EventRegistrationStatus,
		EventFormat
	} from '$lib/api/events';
	import {
		toDatetimeLocal,
		fromDatetimeLocal,
		isoToTime,
		timeToIso,
		eventImageFullUrl
	} from '$lib/api/events';

	export let initial: EventBase | null = null;
	export let mode: 'create' | 'edit' = 'create';
	export let loading = false;
	export let error = '';
	export let onsubmit: (payload: EventCreate | EventUpdate, pendingImageFile?: File | null) => void = () => {};
	export let ondelete: (() => void) | undefined = undefined;
	export let onUploadImage: ((file: File) => Promise<void>) | undefined = undefined;

	let selectedImageFile: File | null = null;
	let imageInputEl: HTMLInputElement;
	let uploadingImage = false;

	const statusOptions: { value: EventRegistrationStatus; label: string }[] = [
		{ value: 'upcoming', label: 'Upcoming' },
		{ value: 'open', label: 'Open' },
		{ value: 'closed', label: 'Closed' },
		{ value: 'past', label: 'Past' }
	];

	const formatOptions: { value: EventFormat; label: string }[] = [
		{ value: 'double_elimination', label: 'Double elimination (bracket)' },
		{ value: 'top_speed', label: 'Top speed' }
	];

	function defaultLocation(): EventLocation {
		return {
			name: '',
			address: null,
			city: null,
			state: null,
			zip_code: null,
			country: null,
			latitude: null,
			longitude: null,
			full_address: null
		};
	}

	function defaultEventInfo(): EventInfo {
		return {
			parking: null,
			tickets: null,
			food_and_drink: null,
			seating: null,
			additional_info: {}
		};
	}

	function defaultScheduleItem(): EventScheduleItem {
		return {
			id: crypto.randomUUID(),
			day: '',
			start_time: '',
			end_time: '',
			description: ''
		};
	}

	function defaultRule(): EventRule {
		return { category: '', description: '' };
	}

	function defaultClass(): EventClass & { id: string } {
		return {
			id: crypto.randomUUID(),
			key: '',
			name: '',
			price: 0,
			description: '',
			is_active: true
		};
	}

	let name = initial?.name ?? '';
	let description = initial?.description ?? '';
	let startDate = initial ? toDatetimeLocal(initial.start_date) : '';
	let endDate = initial?.end_date ? toDatetimeLocal(initial.end_date) : '';
	let regOpen = initial?.registration_open_date ? toDatetimeLocal(initial.registration_open_date) : '';
	let regClose = initial?.registration_close_date ? toDatetimeLocal(initial.registration_close_date) : '';
	let location: EventLocation = initial?.location
		? { ...initial.location }
		: defaultLocation();
	const scheduleSource = initial?.ordered_schedule ?? initial?.schedule;
	let schedule: EventScheduleItem[] = scheduleSource?.length
		? scheduleSource.map((s) => ({
				...s,
				start_time: isoToTime(s.start_time ?? null) || '',
				end_time: isoToTime(s.end_time ?? null) || ''
			}))
		: [defaultScheduleItem()];
	let eventInfo: EventInfo = initial?.event_info
		? { ...initial.event_info, additional_info: { ...(initial.event_info.additional_info ?? {}) } }
		: defaultEventInfo();
	let format: EventFormat = (initial?.format as EventFormat) ?? 'double_elimination';
	let registrationStatus: EventRegistrationStatus = initial?.registration_status ?? 'upcoming';
	let isPublished = initial?.is_published ?? false;
	let resultsUrl = initial?.results_url ?? '';

	/** additional_info as editable list: Name (key) → Description (value) */
	let additionalInfoList: { key: string; value: string }[] = initial?.event_info?.additional_info
		? Object.entries(initial.event_info.additional_info).map(([k, v]) => ({ key: k, value: String(v ?? '') }))
		: [];

	/** rules (category + description), separate from event_info */
	let rulesList: EventRule[] = initial?.rules?.length
		? initial.rules.map((r) => ({ category: r.category, description: r.description }))
		: [];

	/** event classes (key, name, price, etc.); id is client-only for list keying */
	let classesList: (EventClass & { id: string })[] = (initial?.classes?.length)
		? initial.classes.map((c) => ({
				...c,
				id: crypto.randomUUID(),
				description: c.description ?? '',
				is_active: c.is_active ?? true
			}))
		: [];

	function addScheduleItem() {
		schedule = [...schedule, defaultScheduleItem()];
	}

	function removeScheduleItem(id: string) {
		schedule = schedule.filter((s) => s.id !== id);
	}

	function addAdditionalInfo() {
		additionalInfoList = [...additionalInfoList, { key: '', value: '' }];
	}

	function removeAdditionalInfo(idx: number) {
		additionalInfoList = additionalInfoList.filter((_, i) => i !== idx);
	}

	function addRule() {
		rulesList = [...rulesList, defaultRule()];
	}

	function removeRule(idx: number) {
		rulesList = rulesList.filter((_, i) => i !== idx);
	}

	function addClass() {
		classesList = [...classesList, defaultClass()];
	}

	function removeClass(id: string) {
		classesList = classesList.filter((c) => c.id !== id);
	}

	const WEEKDAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

	/** Weekdays that fall within start date → end date, in order of first occurrence. */
	function getScheduleDayOptions(): { value: string; label: string }[] {
		if (!startDate || !startDate.trim()) return [];
		const start = new Date(startDate);
		if (Number.isNaN(start.getTime())) return [];
		const endRaw = endDate?.trim() ? endDate : startDate;
		let end = new Date(endRaw);
		if (Number.isNaN(end.getTime())) end = new Date(start);
		if (end < start) end = new Date(start);

		const startDay = new Date(start);
		startDay.setHours(0, 0, 0, 0);
		const endDay = new Date(end);
		endDay.setHours(0, 0, 0, 0);

		const seen = new Set<string>();
		const order: string[] = [];
		const d = new Date(startDay);
		while (d <= endDay) {
			const name = WEEKDAY_NAMES[d.getDay()];
			if (!seen.has(name)) {
				seen.add(name);
				order.push(name);
			}
			d.setDate(d.getDate() + 1);
		}
		return order.map((value) => ({ value, label: value }));
	}

	$: scheduleDayOptions = getScheduleDayOptions();

	function additionalInfoToRecord(): Record<string, string> {
		const out: Record<string, string> = {};
		for (const { key, value } of additionalInfoList) {
			if (key.trim()) out[key.trim()] = value.trim();
		}
		return out;
	}

	function buildPayload(): EventCreate | EventUpdate {
		const loc: EventLocation = {
			name: location.name || 'Untitled',
			address: location.address || null,
			city: location.city || null,
			state: location.state || null,
			zip_code: location.zip_code || null,
			country: location.country || null,
			latitude: location.latitude ?? null,
			longitude: location.longitude ?? null,
			full_address: location.full_address || null
		};
		const info: EventInfo = {
			parking: eventInfo.parking || null,
			tickets: eventInfo.tickets || null,
			food_and_drink: eventInfo.food_and_drink || null,
			seating: eventInfo.seating || null,
			additional_info: additionalInfoToRecord()
		};
		const dateBase = startDate.slice(0, 10);
		const sched: EventScheduleItem[] = schedule
			.filter((s) => s.day.trim() && s.description.trim())
			.map((s) => ({
				id: s.id,
				day: s.day,
				start_time: timeToIso(dateBase + 'T00:00', String(s.start_time ?? '')) || null,
				end_time: timeToIso(dateBase + 'T00:00', String(s.end_time ?? '')) || null,
				description: s.description
			}));

		const rulesFiltered: EventRule[] = rulesList
			.filter((r) => r.category.trim() && r.description.trim())
			.map((r) => ({ category: r.category.trim(), description: r.description.trim() }));

		const classesFiltered: EventClass[] = classesList
			.filter((c) => c.key.trim() && c.name.trim())
			.map((c) => ({
				key: c.key.trim(),
				name: c.name.trim(),
				price: Number.isFinite(Number(c.price)) ? Number(c.price) : 0,
				description: (c.description ?? '').trim() || null,
				is_active: !!c.is_active
			}));

		if (mode === 'create') {
			const start = fromDatetimeLocal(startDate);
			if (!start) throw new Error('Start date is required');
			return {
				name: name.trim() || 'Untitled Event',
				description: description.trim() || null,
				start_date: start,
				end_date: fromDatetimeLocal(endDate) || null,
				registration_open_date: fromDatetimeLocal(regOpen) || null,
				registration_close_date: fromDatetimeLocal(regClose) || null,
				location: loc,
				schedule: sched,
				event_info: info,
				format,
				registration_status: registrationStatus,
				is_published: isPublished
			};
		}

		const update: EventUpdate = {
			name: name.trim() || undefined,
			description: description.trim() || null,
			start_date: fromDatetimeLocal(startDate) || undefined,
			end_date: fromDatetimeLocal(endDate) || null,
			registration_open_date: fromDatetimeLocal(regOpen) || null,
			registration_close_date: fromDatetimeLocal(regClose) || null,
			location: loc,
			schedule: sched,
			event_info: info,
			format,
			classes: classesFiltered,
			rules: rulesFiltered,
			registration_status: registrationStatus,
			results_url: resultsUrl.trim() || null,
			is_published: isPublished
		};
		return update;
	}

	async function handleUploadClick() {
		if (!onUploadImage || !imageInputEl?.files?.length) return;
		const file = imageInputEl.files[0];
		if (!file) return;
		uploadingImage = true;
		try {
			await onUploadImage(file);
			selectedImageFile = null;
			imageInputEl.value = '';
		} finally {
			uploadingImage = false;
		}
	}

	function handleSubmit(e: Event) {
		e.preventDefault();
		try {
			onsubmit(buildPayload(), mode === 'create' ? selectedImageFile : undefined);
		} catch (err) {
			error = err instanceof Error ? err.message : 'Invalid form';
		}
	}
</script>

<form class="event-form" on:submit|preventDefault={handleSubmit}>
	{#if error}
		<div class="form-error" role="alert">{error}</div>
	{/if}

	<details class="form-card form-card--collapsible" open>
		<summary class="form-section-header">
			<span class="form-section-title">Basic information</span>
			<span class="form-section-chevron" aria-hidden="true">▾</span>
		</summary>
		<div class="form-section-body">
		<div class="form-grid">
			<div class="form-group" style="grid-column: 1 / -1;">
				<label for="name">Name *</label>
				<input id="name" type="text" bind:value={name} required placeholder="Event name" />
			</div>
			<div class="form-group" style="grid-column: 1 / -1;">
				<label for="description">Description</label>
				<textarea id="description" bind:value={description} placeholder="Event description"></textarea>
			</div>
			<div class="form-group">
				<label for="format">Event format</label>
				<select id="format" bind:value={format}>
					{#each formatOptions as opt}
						<option value={opt.value}>{opt.label}</option>
					{/each}
				</select>
			</div>
			{#if mode === 'edit'}
				<div class="form-group form-group-image" style="grid-column: 1 / -1;">
					<label for="event-image-edit">Event image</label>
					{#if initial?.image_url}
						<div class="image-preview-wrap">
							<img
								src={eventImageFullUrl(initial.image_url)}
								alt="Event"
								class="image-preview"
							/>
						</div>
					{/if}
					<div class="image-upload-actions">
						<input
							id="event-image-edit"
							type="file"
							accept="image/*"
							bind:this={imageInputEl}
							on:change={(e) => (selectedImageFile = (e.currentTarget.files ?? [])[0] ?? null)}
						/>
						{#if onUploadImage}
							<button
								type="button"
								class="btn btn-secondary btn-sm"
								disabled={!selectedImageFile || uploadingImage}
								on:click={handleUploadClick}
							>
								{uploadingImage ? 'Uploading…' : 'Upload / replace image'}
							</button>
						{/if}
						{#if selectedImageFile}
							<span class="image-filename">{selectedImageFile.name}</span>
						{/if}
					</div>
				</div>
			{:else}
				<div class="form-group form-group-image" style="grid-column: 1 / -1;">
					<label for="event-image-create">Event image (optional)</label>
					<input
						id="event-image-create"
						type="file"
						accept="image/*"
						on:change={(e) => (selectedImageFile = (e.currentTarget.files ?? [])[0] ?? null)}
					/>
					{#if selectedImageFile}
						<span class="image-filename">Selected: {selectedImageFile.name}</span>
					{/if}
				</div>
			{/if}
		</div>
		</div>
	</details>

	<details class="form-card form-card--collapsible">
		<summary class="form-section-header">
			<span class="form-section-title">Dates</span>
			<span class="form-section-chevron" aria-hidden="true">▾</span>
		</summary>
		<div class="form-section-body">
		<div class="form-grid">
			<div class="form-group">
				<label for="start_date">Start date *</label>
				<input id="start_date" type="datetime-local" bind:value={startDate} required />
			</div>
			<div class="form-group">
				<label for="end_date">End date</label>
				<input id="end_date" type="datetime-local" bind:value={endDate} />
			</div>
			<div class="form-group">
				<label for="reg_open">Registration open</label>
				<input id="reg_open" type="datetime-local" bind:value={regOpen} />
			</div>
			<div class="form-group">
				<label for="reg_close">Registration close</label>
				<input id="reg_close" type="datetime-local" bind:value={regClose} />
			</div>
		</div>
		</div>
	</details>

	<details class="form-card form-card--collapsible">
		<summary class="form-section-header">
			<span class="form-section-title">Location</span>
			<span class="form-section-chevron" aria-hidden="true">▾</span>
		</summary>
		<div class="form-section-body">
		<div class="form-grid">
			<div class="form-group" style="grid-column: 1 / -1;">
				<label for="loc_name">Venue name *</label>
				<input id="loc_name" type="text" bind:value={location.name} required placeholder="e.g. Burt Aaronson Park" />
			</div>
			<div class="form-group" style="grid-column: 1 / -1;">
				<label for="loc_address">Address</label>
				<input id="loc_address" type="text" bind:value={location.address} placeholder="Street address" />
			</div>
			<div class="form-group">
				<label for="loc_city">City</label>
				<input id="loc_city" type="text" bind:value={location.city} />
			</div>
			<div class="form-group">
				<label for="loc_state">State</label>
				<input id="loc_state" type="text" bind:value={location.state} />
			</div>
			<div class="form-group">
				<label for="loc_zip">ZIP</label>
				<input id="loc_zip" type="text" bind:value={location.zip_code} />
			</div>
			<div class="form-group">
				<label for="loc_country">Country</label>
				<input id="loc_country" type="text" bind:value={location.country} />
			</div>
			<div class="form-group" style="grid-column: 1 / -1;">
				<label for="loc_full">Full address (display)</label>
				<input id="loc_full" type="text" bind:value={location.full_address} placeholder="Formatted address" />
			</div>
		</div>
		</div>
	</details>

	<details class="form-card form-card--collapsible">
		<summary class="form-section-header">
			<span class="form-section-title">Schedule</span>
			<span class="form-section-chevron" aria-hidden="true">▾</span>
		</summary>
		<div class="form-section-body">
		<p class="form-hint">Day (from event start→end), optional times, and description for each slot. Set start and end dates first.</p>
		<div class="form-array">
			{#each schedule as item (item.id)}
				<div class="form-array-item">
					<div class="form-group" style="min-width: 120px;">
						<label for="sched-day-{item.id}">Day</label>
						{#if scheduleDayOptions.length > 0}
							<select id="sched-day-{item.id}" bind:value={item.day} class="schedule-day-select">
								<option value="">Select day</option>
								{#each scheduleDayOptions as opt}
									<option value={opt.value}>{opt.label}</option>
								{/each}
							</select>
						{:else}
							<select id="sched-day-{item.id}" bind:value={item.day} disabled class="schedule-day-select">
								<option value="">Set start & end dates</option>
							</select>
						{/if}
					</div>
					<div class="form-group" style="min-width: 140px;">
						<label for="sched-start-{item.id}">Start time</label>
						<input id="sched-start-{item.id}" type="time" bind:value={item.start_time} placeholder="09:00" />
					</div>
					<div class="form-group" style="min-width: 140px;">
						<label for="sched-end-{item.id}">End time</label>
						<input id="sched-end-{item.id}" type="time" bind:value={item.end_time} placeholder="17:00" />
					</div>
					<div class="form-group" style="flex: 2; min-width: 200px;">
						<label for="sched-desc-{item.id}">Description</label>
						<input id="sched-desc-{item.id}" type="text" bind:value={item.description} placeholder="e.g. Stock and Spec Classes" />
					</div>
					<button type="button" class="btn btn-text btn-remove" on:click={() => removeScheduleItem(item.id)} title="Remove">✕</button>
				</div>
			{/each}
		</div>
		<button type="button" class="btn btn-secondary btn-sm btn-add" on:click={addScheduleItem}>+ Add schedule item</button>
		</div>
	</details>

	<details class="form-card form-card--collapsible">
		<summary class="form-section-header">
			<span class="form-section-title">Event info</span>
			<span class="form-section-chevron" aria-hidden="true">▾</span>
		</summary>
		<div class="form-section-body">
		<p class="form-hint">Parking, tickets, seating, etc. Shown to participants.</p>
		<div class="form-grid">
			<div class="form-group" style="grid-column: 1 / -1;">
				<label for="parking">Parking</label>
				<input id="parking" type="text" bind:value={eventInfo.parking} placeholder="e.g. FREE for everyone" />
			</div>
			<div class="form-group" style="grid-column: 1 / -1;">
				<label for="tickets">Tickets</label>
				<input id="tickets" type="text" bind:value={eventInfo.tickets} placeholder="e.g. $30 day / $40 weekend" />
			</div>
			<div class="form-group" style="grid-column: 1 / -1;">
				<label for="food">Food &amp; drink</label>
				<input id="food" type="text" bind:value={eventInfo.food_and_drink} placeholder="e.g. Bring your own" />
			</div>
			<div class="form-group" style="grid-column: 1 / -1;">
				<label for="seating">Seating</label>
				<input id="seating" type="text" bind:value={eventInfo.seating} placeholder="e.g. Bring chairs" />
			</div>
		</div>
		<p class="form-hint" style="margin-top: 1rem;">Additional info (Name → Description). Shown to participants.</p>
		<div class="form-array">
			{#each additionalInfoList as item, idx}
				<div class="form-array-item">
					<div class="form-group" style="min-width: 140px;">
						<label for="addinfo-name-{idx}">Name</label>
						<input id="addinfo-name-{idx}" type="text" bind:value={item.key} placeholder="e.g. Cooler policy" />
					</div>
					<div class="form-group" style="flex: 1; min-width: 200px;">
						<label for="addinfo-desc-{idx}">Description</label>
						<input id="addinfo-desc-{idx}" type="text" bind:value={item.value} placeholder="e.g. No glass containers" />
					</div>
					<button type="button" class="btn btn-text btn-remove" on:click={() => removeAdditionalInfo(idx)} title="Remove">✕</button>
				</div>
			{/each}
		</div>
		<button type="button" class="btn btn-secondary btn-sm btn-add" on:click={addAdditionalInfo}>+ Add additional info</button>
		</div>
	</details>

	<details class="form-card form-card--collapsible">
		<summary class="form-section-header">
			<span class="form-section-title">Classes</span>
			<span class="form-section-chevron" aria-hidden="true">▾</span>
		</summary>
		<div class="form-section-body">
		<p class="form-hint">Registration classes (e.g. Pro Stock, Novice). Key = stable id (e.g. pro_stock), name = display label, price = registration cost.</p>
		<div class="form-array form-array--rules">
			{#each classesList as cl, idx (cl.id)}
				<div class="form-array-item form-array-item--vertical rule-card">
					<div class="form-array-item-fields">
						<div class="form-row form-row--classes">
							<div class="form-group">
								<label for="class-key-{idx}">Key</label>
								<input id="class-key-{idx}" type="text" bind:value={cl.key} placeholder="e.g. pro_stock" />
							</div>
							<div class="form-group">
								<label for="class-name-{idx}">Name</label>
								<input id="class-name-{idx}" type="text" bind:value={cl.name} placeholder="e.g. Pro Stock" />
							</div>
							<div class="form-group form-group--price">
								<label for="class-price-{idx}">Price</label>
								<input id="class-price-{idx}" type="number" step="0.01" min="0" bind:value={cl.price} placeholder="0" />
							</div>
							<div class="form-group form-group--active">
								<label>
									<input type="checkbox" bind:checked={cl.is_active} />
									Active
								</label>
							</div>
						</div>
						<div class="form-group">
							<label for="class-desc-{idx}">Description</label>
							<textarea id="class-desc-{idx}" bind:value={cl.description} placeholder="Optional" rows="2"></textarea>
						</div>
					</div>
					<button type="button" class="btn btn-text btn-remove" on:click={() => removeClass(cl.id)} title="Remove class">✕</button>
				</div>
			{/each}
		</div>
		<button type="button" class="btn btn-secondary btn-sm btn-add" on:click={addClass}>+ Add class</button>
		</div>
	</details>

	<details class="form-card form-card--collapsible">
		<summary class="form-section-header">
			<span class="form-section-title">Rules</span>
			<span class="form-section-chevron" aria-hidden="true">▾</span>
		</summary>
		<div class="form-section-body">
		<p class="form-hint">Category (e.g. Safety, Equipment, Conduct) and full rule text.</p>
		<div class="form-array form-array--rules">
			{#each rulesList as rule, idx}
				<div class="form-array-item form-array-item--vertical rule-card">
					<div class="form-array-item-fields">
						<div class="form-group">
							<label for="rule-cat-{idx}">Category</label>
							<input id="rule-cat-{idx}" type="text" bind:value={rule.category} placeholder="e.g. Safety, Equipment" />
						</div>
						<div class="form-group">
							<label for="rule-desc-{idx}">Description</label>
							<textarea id="rule-desc-{idx}" bind:value={rule.description} placeholder="Full rule text" rows="3"></textarea>
						</div>
					</div>
					<button type="button" class="btn btn-text btn-remove" on:click={() => removeRule(idx)} title="Remove rule">✕</button>
				</div>
			{/each}
		</div>
		<button type="button" class="btn btn-secondary btn-sm btn-add" on:click={addRule}>+ Add rule</button>
		</div>
	</details>

	<details class="form-card form-card--collapsible">
		<summary class="form-section-header">
			<span class="form-section-title">Status</span>
			<span class="form-section-chevron" aria-hidden="true">▾</span>
		</summary>
		<div class="form-section-body">
		<div class="form-grid">
			<div class="form-group">
				<label for="reg_status">Registration status</label>
				<select id="reg_status" bind:value={registrationStatus}>
					{#each statusOptions as opt}
						<option value={opt.value}>{opt.label}</option>
					{/each}
				</select>
			</div>
			<div class="form-group">
				<label>
					<input type="checkbox" bind:checked={isPublished} />
					Published (visible to participants)
				</label>
			</div>
			{#if mode === 'edit'}
				<div class="form-group" style="grid-column: 1 / -1;">
					<label for="results_url">Results URL</label>
					<input id="results_url" type="url" bind:value={resultsUrl} placeholder="https://..." />
				</div>
			{/if}
		</div>
		</div>
	</details>

	<div class="form-actions">
		{#if mode === 'edit' && ondelete}
			<button type="button" class="btn btn-danger btn-sm" on:click={ondelete} disabled={loading}>
				Delete event
			</button>
		{/if}
		<div style="margin-left: auto; display: flex; gap: 0.5rem;">
			<a href="/events" class="btn btn-secondary">Cancel</a>
			<button type="submit" class="btn btn-primary" disabled={loading}>
				{loading ? 'Saving…' : mode === 'create' ? 'Create event' : 'Save changes'}
			</button>
		</div>
	</div>
</form>

<style>
	.form-hint {
		margin: 0 0 1rem;
		font-size: 0.9rem;
		color: var(--text-muted);
	}
	.form-error {
		margin-bottom: 1rem;
		padding: 0.75rem 1rem;
		background: #fef2f2;
		color: var(--error);
		border-radius: var(--radius);
		font-size: 0.9rem;
	}
	.form-group-image {
		margin-top: 0.5rem;
	}
	.image-preview-wrap {
		margin-bottom: 0.75rem;
	}
	.image-preview {
		display: block;
		max-width: 320px;
		max-height: 180px;
		object-fit: contain;
		border-radius: var(--radius);
		border: 1px solid var(--border);
		background: var(--bg);
	}
	.image-upload-actions {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		flex-wrap: wrap;
	}
	.image-upload-actions input[type="file"] {
		font-size: 0.9rem;
	}
	.image-filename {
		font-size: 0.9rem;
		color: var(--text-muted);
	}
</style>
