<script lang="ts">
	import { onMount } from 'svelte';
	import {
		fetchHydroDragsConfig,
		updateHydroDragsConfig,
		addSponsor,
		updateSponsor,
		deleteSponsor,
		addMediaPartner,
		updateMediaPartner,
		deleteMediaPartner,
		addHeroNews,
		updateHeroNews,
		deleteHeroNews,
		uploadSponsorImage,
		uploadMediaPartnerImage,
		uploadLogo,
		deleteLogo,
		uploadBanner,
		deleteBanner,
		type HydroDragsConfigResponse,
		type HydroDragsConfigUpdate,
		type Sponsor,
		type SocialLink,
		type NewsItem
	} from '$lib/api/hydrodrags';
	import { toast } from '$lib/stores/toast';

	let loading = true;
	let saving = false;
	let error: string | null = null;
	let config: HydroDragsConfigResponse | null = null;

	// Form state (main config)
	let headline = '';
	let about = '';
	let tagline = '';
	let aboutEs = '';
	let taglineEs = '';

	let email = '';
	let supportEmail = '';
	let phone = '';
	let websiteUrl = '';

	let ihraMembershipPrice = 85;
	let spectatorSingleDayPrice = 0;
	let spectatorWeekendPrice = 35;

	let socialLinks: (SocialLink & { _id: string })[] = [];

	// Sponsor add form
	let showAddSponsor = false;
	let newSponsorName = '';
	let newSponsorLogoFile: File | null = null;
	let newSponsorWebsite = '';
	let newSponsorActive = true;
	let addSponsorPending = false;
	let sponsorLogoInput: HTMLInputElement;

	// Media partner add form
	let showAddMediaPartner = false;
	let newMediaPartnerName = '';
	let newMediaPartnerLogoFile: File | null = null;
	let newMediaPartnerWebsite = '';
	let newMediaPartnerActive = true;
	let addMediaPartnerPending = false;
	let mediaPartnerLogoInput: HTMLInputElement;

	// Track replacement logo file per index (sponsors and media partners)
	let sponsorLogoReplacement: Map<number, File> = new Map();
	let mediaPartnerLogoReplacement: Map<number, File> = new Map();

	// News add form
	let showAddNews = false;
	let newNewsTitle = '';
	let newNewsDescription = '';
	let newNewsMediaUrl = '';
	let newNewsActive = true;
	let addNewsPending = false;

	// Collapsible sections (default collapsed)
	type SectionKey = 'about' | 'pricing' | 'contact' | 'news' | 'sponsors' | 'mediaPartners' | 'socialLinks';
	let openSections: Record<SectionKey, boolean> = {
		about: false,
		pricing: false,
		contact: false,
		news: false,
		sponsors: false,
		mediaPartners: false,
		socialLinks: false
	};
	function toggleSection(key: SectionKey) {
		openSections[key] = !openSections[key];
		openSections = openSections;
	}

	function mapConfigToForm(c: HydroDragsConfigResponse) {
		headline = c.headline ?? '';
		about = c.about ?? '';
		tagline = c.tagline ?? '';
		aboutEs = c.es?.about ?? '';
		taglineEs = c.es?.tagline ?? '';
		email = c.email ?? '';
		supportEmail = c.support_email ?? '';
		phone = c.phone ?? '';
		websiteUrl = c.website_url ?? '';
		ihraMembershipPrice = c.ihra_membership_price ?? 85;
		spectatorSingleDayPrice = c.spectator_single_day_price ?? 0;
		spectatorWeekendPrice = c.spectator_weekend_price ?? 35;
		socialLinks = (c.social_links ?? []).map((l) => ({
			...l,
			_id: crypto.randomUUID()
		}));
	}

	async function load() {
		loading = true;
		error = null;
		const res = await fetchHydroDragsConfig();
		loading = false;
		if (!res.ok) {
			error = res.error ?? 'Failed to load config';
			config = null;
			return;
		}
		config = res.data ?? null;
		if (config) mapConfigToForm(config);
		else socialLinks = [];
		sponsorLogoReplacement = new Map();
		mediaPartnerLogoReplacement = new Map();
	}

	// ---------- Main config submit (no sponsors / media_partners) ----------
	function buildPayload(): HydroDragsConfigUpdate {
		return {
			headline: headline || undefined,
			about: about || undefined,
			tagline: tagline || undefined,
			es: { about: aboutEs || undefined, tagline: taglineEs || undefined },
			email: email || undefined,
			support_email: supportEmail || undefined,
			phone: phone || undefined,
			website_url: websiteUrl || undefined,
			ihra_membership_price: ihraMembershipPrice,
			spectator_single_day_price: spectatorSingleDayPrice,
			spectator_weekend_price: spectatorWeekendPrice,
			is_active: true
		};
	}

	async function handleSubmit(e: Event) {
		e.preventDefault();
		saving = true;
		error = null;
		const res = await updateHydroDragsConfig(buildPayload());
		saving = false;
		if (res.ok) {
			toast('Company info saved', 'success');
			await load();
		} else {
			error = res.error ?? 'Save failed';
		}
	}

	// ---------- Social links (inline in main form) ----------
	function addSocialLink() {
		socialLinks = [...socialLinks, { platform: '', url: '', _id: crypto.randomUUID() }];
	}

	function removeSocialLink(id: string) {
		socialLinks = socialLinks.filter((l) => l._id !== id);
	}

	// ---------- Sponsors CRUD ----------
	function openAddSponsor() {
		showAddSponsor = true;
		newSponsorName = '';
		newSponsorLogoFile = null;
		newSponsorWebsite = '';
		newSponsorActive = true;
		if (sponsorLogoInput) sponsorLogoInput.value = '';
	}

	function cancelAddSponsor() {
		showAddSponsor = false;
	}

	async function submitAddSponsor() {
		if (!newSponsorLogoFile) {
			toast('Please select a logo image', 'error');
			return;
		}
		if (!newSponsorName.trim()) {
			toast('Please enter sponsor name', 'error');
			return;
		}
		addSponsorPending = true;
		const uploadRes = await uploadSponsorImage(newSponsorLogoFile);
		if (!uploadRes.ok || !uploadRes.data?.logo_url) {
			addSponsorPending = false;
			toast(uploadRes.error ?? 'Logo upload failed', 'error');
			return;
		}
		const createRes = await addSponsor({
			name: newSponsorName.trim(),
			logo_url: uploadRes.data.logo_url,
			website_url: newSponsorWebsite.trim() || undefined,
			is_active: newSponsorActive
		});
		addSponsorPending = false;
		if (createRes.ok) {
			toast('Sponsor added', 'success');
			showAddSponsor = false;
			await load();
		} else {
			toast(createRes.error ?? 'Failed to add sponsor', 'error');
		}
	}

	async function saveSponsor(index: number) {
		const s = config?.sponsors?.[index];
		if (!s) return;
		const replacementFile = sponsorLogoReplacement.get(index);
		let logoUrl = s.logo_url ?? '';
		if (replacementFile) {
			const uploadRes = await uploadSponsorImage(replacementFile);
			if (!uploadRes.ok || !uploadRes.data?.logo_url) {
				toast(uploadRes.error ?? 'Logo upload failed', 'error');
				return;
			}
			logoUrl = uploadRes.data.logo_url;
			sponsorLogoReplacement.delete(index);
		}
		const res = await updateSponsor(index, {
			name: s.name,
			logo_url: logoUrl || undefined,
			website_url: s.website_url ?? undefined,
			is_active: s.is_active
		});
		if (res.ok) {
			toast('Sponsor updated', 'success');
			await load();
		} else {
			toast(res.error ?? 'Update failed', 'error');
		}
	}

	async function removeSponsor(index: number) {
		const res = await deleteSponsor(index);
		if (res.ok) {
			toast('Sponsor removed', 'success');
			await load();
		} else {
			toast(res.error ?? 'Delete failed', 'error');
		}
	}

	function setSponsorLogoReplacement(index: number, file: File | null) {
		if (file) sponsorLogoReplacement.set(index, file);
		else sponsorLogoReplacement.delete(index);
		sponsorLogoReplacement = sponsorLogoReplacement;
	}

	// ---------- Media partners CRUD ----------
	function openAddMediaPartner() {
		showAddMediaPartner = true;
		newMediaPartnerName = '';
		newMediaPartnerLogoFile = null;
		newMediaPartnerWebsite = '';
		newMediaPartnerActive = true;
		if (mediaPartnerLogoInput) mediaPartnerLogoInput.value = '';
	}

	function cancelAddMediaPartner() {
		showAddMediaPartner = false;
	}

	async function submitAddMediaPartner() {
		if (!newMediaPartnerLogoFile) {
			toast('Please select a logo image', 'error');
			return;
		}
		if (!newMediaPartnerName.trim()) {
			toast('Please enter media partner name', 'error');
			return;
		}
		addMediaPartnerPending = true;
		const uploadRes = await uploadMediaPartnerImage(newMediaPartnerLogoFile);
		if (!uploadRes.ok || !uploadRes.data?.logo_url) {
			addMediaPartnerPending = false;
			toast(uploadRes.error ?? 'Logo upload failed', 'error');
			return;
		}
		const createRes = await addMediaPartner({
			name: newMediaPartnerName.trim(),
			logo_url: uploadRes.data.logo_url,
			website_url: newMediaPartnerWebsite.trim() || undefined,
			is_active: newMediaPartnerActive
		});
		addMediaPartnerPending = false;
		if (createRes.ok) {
			toast('Media partner added', 'success');
			showAddMediaPartner = false;
			await load();
		} else {
			toast(createRes.error ?? 'Failed to add media partner', 'error');
		}
	}

	async function saveMediaPartner(index: number) {
		const m = config?.media_partners?.[index];
		if (!m) return;
		const replacementFile = mediaPartnerLogoReplacement.get(index);
		let logoUrl = m.logo_url ?? '';
		if (replacementFile) {
			const uploadRes = await uploadMediaPartnerImage(replacementFile);
			if (!uploadRes.ok || !uploadRes.data?.logo_url) {
				toast(uploadRes.error ?? 'Logo upload failed', 'error');
				return;
			}
			logoUrl = uploadRes.data.logo_url;
			mediaPartnerLogoReplacement.delete(index);
		}
		const res = await updateMediaPartner(index, {
			name: m.name,
			logo_url: logoUrl || undefined,
			website_url: m.website_url ?? undefined,
			is_active: m.is_active
		});
		if (res.ok) {
			toast('Media partner updated', 'success');
			await load();
		} else {
			toast(res.error ?? 'Update failed', 'error');
		}
	}

	async function removeMediaPartner(index: number) {
		const res = await deleteMediaPartner(index);
		if (res.ok) {
			toast('Media partner removed', 'success');
			await load();
		} else {
			toast(res.error ?? 'Delete failed', 'error');
		}
	}

	function setMediaPartnerLogoReplacement(index: number, file: File | null) {
		if (file) mediaPartnerLogoReplacement.set(index, file);
		else mediaPartnerLogoReplacement.delete(index);
		mediaPartnerLogoReplacement = mediaPartnerLogoReplacement;
	}

	// ---------- Hero news CRUD ----------
	function openAddNews() {
		showAddNews = true;
		newNewsTitle = '';
		newNewsDescription = '';
		newNewsMediaUrl = '';
		newNewsActive = true;
	}

	function cancelAddNews() {
		showAddNews = false;
	}

	async function submitAddNews() {
		if (!newNewsTitle.trim()) {
			toast('Please enter a title', 'error');
			return;
		}
		addNewsPending = true;
		const res = await addHeroNews({
			title: newNewsTitle.trim(),
			description: newNewsDescription.trim() || undefined,
			media_url: newNewsMediaUrl.trim() || undefined,
			is_active: newNewsActive
		});
		addNewsPending = false;
		if (res.ok) {
			toast('News item added', 'success');
			showAddNews = false;
			await load();
		} else {
			toast(res.error ?? 'Failed to add news item', 'error');
		}
	}

	async function saveNewsItem(index: number) {
		const item = config?.news?.[index];
		if (!item) return;
		const res = await updateHeroNews(index, {
			title: item.title,
			description: item.description ?? undefined,
			media_url: item.media_url ?? undefined,
			is_active: item.is_active
		});
		if (res.ok) {
			toast('News item updated', 'success');
			await load();
		} else {
			toast(res.error ?? 'Update failed', 'error');
		}
	}

	async function removeNewsItem(index: number) {
		const res = await deleteHeroNews(index);
		if (res.ok) {
			toast('News item removed', 'success');
			await load();
		} else {
			toast(res.error ?? 'Delete failed', 'error');
		}
	}

	// Logo display URL (prepend API base if relative)
	function logoFullUrl(url: string | null | undefined): string {
		if (!url || !url.trim()) return '';
		if (url.startsWith('http')) return url;
		const base = import.meta.env.VITE_API_BASE_URL ?? '';
		return base.replace(/\/$/, '') + (url.startsWith('/') ? url : `/${url}`);
	}

	// ---------- Logo & banner (About) ----------
	let logoUploadPending = false;
	let bannerUploadPending = false;
	let logoDeletePending = false;
	let bannerDeletePending = false;
	let logoFileInput: HTMLInputElement;
	let bannerFileInput: HTMLInputElement;

	async function onLogoFileChange(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		if (!file) return;
		logoUploadPending = true;
		const res = await uploadLogo(file);
		logoUploadPending = false;
		if (res.ok) {
			toast('Logo updated', 'success');
			await load();
		} else {
			toast(res.error ?? 'Logo upload failed', 'error');
		}
		if (logoFileInput) logoFileInput.value = '';
	}

	async function onRemoveLogo() {
		logoDeletePending = true;
		const res = await deleteLogo();
		logoDeletePending = false;
		if (res.ok) {
			toast('Logo removed', 'success');
			await load();
		} else {
			toast(res.error ?? 'Failed to remove logo', 'error');
		}
	}

	async function onBannerFileChange(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		if (!file) return;
		bannerUploadPending = true;
		const res = await uploadBanner(file);
		bannerUploadPending = false;
		if (res.ok) {
			toast('Banner updated', 'success');
			await load();
		} else {
			toast(res.error ?? 'Banner upload failed', 'error');
		}
		if (bannerFileInput) bannerFileInput.value = '';
	}

	async function onRemoveBanner() {
		bannerDeletePending = true;
		const res = await deleteBanner();
		bannerDeletePending = false;
		if (res.ok) {
			toast('Banner removed', 'success');
			await load();
		} else {
			toast(res.error ?? 'Failed to remove banner', 'error');
		}
	}

	onMount(load);
</script>

<div class="page-header">
	<h1 class="page-title">Company information</h1>
	<p class="page-subtitle">About, pricing, contact, sponsors, media partners, and social links</p>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error && !config}
	<div class="error-placeholder">
		{error}
		<br />
		<button type="button" class="btn btn-secondary btn-sm" on:click={load}>Retry</button>
	</div>
{:else}
	<form on:submit={handleSubmit}>
		{#if error}
			<div class="error-placeholder" style="margin-bottom: 1rem;">{error}</div>
		{/if}

		<!-- About -->
		<div class="collapse-card form-card">
			<button type="button" class="collapse-header" on:click={() => toggleSection('about')} aria-expanded={openSections.about}>
				<span class="collapse-title">About</span>
				<span class="collapse-icon" aria-hidden="true">{openSections.about ? '▼' : '▶'}</span>
			</button>
			<div class="collapse-body" class:open={openSections.about}>
				<div class="collapse-inner">
				<div class="about-assets">
					<div class="form-group about-asset">
						<label for="logo-upload">Logo</label>
						{#if config?.logo_url}
							<div class="asset-preview-wrap">
								<img src={logoFullUrl(config.logo_url)} alt="Company logo" class="asset-preview asset-preview--logo" />
								<div class="asset-actions">
									<label for="logo-upload" class="btn btn-secondary btn-sm" style="margin-right: 0.5rem;">
										{logoUploadPending ? 'Uploading…' : 'Replace'}
									</label>
									<input
										bind:this={logoFileInput}
										id="logo-upload"
										type="file"
										accept="image/*"
										on:change={onLogoFileChange}
										hidden
									/>
									<button type="button" class="btn btn-text btn-sm" disabled={logoDeletePending} on:click={onRemoveLogo}>
										{logoDeletePending ? 'Removing…' : 'Remove'}
									</button>
								</div>
							</div>
						{:else}
							<div class="asset-actions">
								<label for="logo-upload" class="btn btn-secondary btn-sm">
									{logoUploadPending ? 'Uploading…' : 'Upload logo'}
								</label>
								<input
									bind:this={logoFileInput}
									id="logo-upload"
									type="file"
									accept="image/*"
									on:change={onLogoFileChange}
									hidden
								/>
							</div>
						{/if}
					</div>
					<div class="form-group about-asset">
						<label for="banner-upload">Banner</label>
						{#if config?.banner_url}
							<div class="asset-preview-wrap">
								<img src={logoFullUrl(config.banner_url)} alt="Banner" class="asset-preview asset-preview--banner" />
								<div class="asset-actions">
									<label for="banner-upload" class="btn btn-secondary btn-sm" style="margin-right: 0.5rem;">
										{bannerUploadPending ? 'Uploading…' : 'Replace'}
									</label>
									<input
										bind:this={bannerFileInput}
										id="banner-upload"
										type="file"
										accept="image/*"
										on:change={onBannerFileChange}
										hidden
									/>
									<button type="button" class="btn btn-text btn-sm" disabled={bannerDeletePending} on:click={onRemoveBanner}>
										{bannerDeletePending ? 'Removing…' : 'Remove'}
									</button>
								</div>
							</div>
						{:else}
							<div class="asset-actions">
								<label for="banner-upload" class="btn btn-secondary btn-sm">
									{bannerUploadPending ? 'Uploading…' : 'Upload banner'}
								</label>
								<input
									bind:this={bannerFileInput}
									id="banner-upload"
									type="file"
									accept="image/*"
									on:change={onBannerFileChange}
									hidden
								/>
							</div>
						{/if}
					</div>
				</div>
				<div class="form-group">
					<label for="headline">Headline</label>
					<input id="headline" type="text" bind:value={headline} placeholder="HydroDrags" />
				</div>
				<div class="form-group">
					<label for="tagline">Tagline</label>
					<input id="tagline" type="text" bind:value={tagline} placeholder="Short tagline" />
				</div>
				<div class="form-group">
					<label for="about">About (English)</label>
					<textarea id="about" bind:value={about} rows="4" placeholder="Company description…"></textarea>
				</div>
				<div class="form-group">
					<label for="about-es">About (Spanish, optional)</label>
					<textarea id="about-es" bind:value={aboutEs} rows="3" placeholder="Descripción en español…"></textarea>
				</div>
				<div class="form-group">
					<label for="tagline-es">Tagline (Spanish, optional)</label>
					<input id="tagline-es" type="text" bind:value={taglineEs} placeholder="Tagline en español" />
				</div>
				</div>
			</div>
		</div>

		<!-- Pricing -->
		<div class="collapse-card form-card">
			<button type="button" class="collapse-header" on:click={() => toggleSection('pricing')} aria-expanded={openSections.pricing}>
				<span class="collapse-title">Pricing</span>
				<span class="collapse-icon" aria-hidden="true">{openSections.pricing ? '▼' : '▶'}</span>
			</button>
			<div class="collapse-body" class:open={openSections.pricing}>
				<div class="collapse-inner">
				<div class="form-row form-row--pricing">
					<div class="form-group">
						<label for="ihra-price">IHRA membership price ($)</label>
						<input
							id="ihra-price"
							type="number"
							step="0.01"
							min="0"
							bind:value={ihraMembershipPrice}
						/>
					</div>
					<div class="form-group">
						<label for="single-day-price">Spectator single day ($)</label>
						<input
							id="single-day-price"
							type="number"
							step="0.01"
							min="0"
							bind:value={spectatorSingleDayPrice}
						/>
					</div>
					<div class="form-group">
						<label for="weekend-price">Spectator weekend ($)</label>
						<input
							id="weekend-price"
							type="number"
							step="0.01"
							min="0"
							bind:value={spectatorWeekendPrice}
						/>
					</div>
				</div>
				</div>
			</div>
		</div>

		<!-- Contact -->
		<div class="collapse-card form-card">
			<button type="button" class="collapse-header" on:click={() => toggleSection('contact')} aria-expanded={openSections.contact}>
				<span class="collapse-title">Contact Info</span>
				<span class="collapse-icon" aria-hidden="true">{openSections.contact ? '▼' : '▶'}</span>
			</button>
			<div class="collapse-body" class:open={openSections.contact}>
				<div class="collapse-inner">
				<div class="form-group">
					<label for="email">Email</label>
					<input id="email" type="email" bind:value={email} placeholder="info@example.com" />
				</div>
				<div class="form-group">
					<label for="support-email">Support email</label>
					<input id="support-email" type="email" bind:value={supportEmail} placeholder="support@example.com" />
				</div>
				<div class="form-group">
					<label for="phone">Phone</label>
					<input id="phone" type="text" bind:value={phone} placeholder="+1 234 567 8900" />
				</div>
				<div class="form-group">
					<label for="website-url">Website URL</label>
					<input id="website-url" type="url" bind:value={websiteUrl} placeholder="https://…" />
				</div>
				</div>
			</div>
		</div>

		<!-- News -->
		<div class="collapse-card form-card">
			<button type="button" class="collapse-header" on:click={() => toggleSection('news')} aria-expanded={openSections.news}>
				<span class="collapse-title">News</span>
				<span class="collapse-icon" aria-hidden="true">{openSections.news ? '▼' : '▶'}</span>
			</button>
			<div class="collapse-body" class:open={openSections.news}>
				<div class="collapse-inner">
			{#if config?.news?.length}
				{#each config.news as item, index}
					<div class="form-array-item form-array-item--vertical form-array-item--news">
						<div class="form-array-item-fields">
							{#if item.media_url}
								<div class="form-group form-group--media">
									<label for="news-media-{index}">Media</label>
									<img src={logoFullUrl(item.media_url)} alt="" class="news-media-preview" />
								</div>
							{/if}
							<div class="form-group">
								<label for="news-title-{index}">Title</label>
								<input id="news-title-{index}" type="text" bind:value={item.title} placeholder="News title" />
							</div>
							<div class="form-group form-group--full">
								<label for="news-desc-{index}">Description</label>
								<textarea id="news-desc-{index}" bind:value={item.description} rows="2" placeholder="Optional description…"></textarea>
							</div>
							<div class="form-group">
								<label for="news-media-url-{index}">Media URL</label>
								<input id="news-media-url-{index}" type="url" bind:value={item.media_url} placeholder="https://…" />
							</div>
							<div class="form-group form-group--checkbox">
								<label>
									<input type="checkbox" bind:checked={item.is_active} />
									Active
								</label>
							</div>
						</div>
						<div class="form-array-item-actions">
							<button type="button" class="btn btn-secondary btn-sm" on:click={() => saveNewsItem(index)}>
								Update
							</button>
							<button
								type="button"
								class="btn btn-text btn-sm"
								on:click={() => removeNewsItem(index)}
								aria-label="Remove news item"
							>
								Remove
							</button>
						</div>
					</div>
				{/each}
			{:else}
				<p class="form-hint">No news items yet. Add one below.</p>
			{/if}

			{#if showAddNews}
				<div class="form-array-item form-array-item--vertical form-array-item--new">
					<div class="form-array-item-fields form-array-item-fields--news">
						<div class="form-group">
							<label for="new-news-title">Title</label>
							<input id="new-news-title" type="text" bind:value={newNewsTitle} placeholder="News title" />
						</div>
						<div class="form-group form-group--full">
							<label for="new-news-desc">Description</label>
							<textarea id="new-news-desc" bind:value={newNewsDescription} rows="2" placeholder="Optional description…"></textarea>
						</div>
						<div class="form-group">
							<label for="new-news-media-url">Media URL</label>
							<input id="new-news-media-url" type="url" bind:value={newNewsMediaUrl} placeholder="https://…" />
						</div>
						<div class="form-group form-group--checkbox">
							<label>
								<input type="checkbox" bind:checked={newNewsActive} />
								Active
							</label>
						</div>
					</div>
					<div class="form-array-item-actions">
						<button type="button" class="btn btn-primary btn-sm" on:click={submitAddNews} disabled={addNewsPending}>
							{addNewsPending ? 'Adding…' : 'Add'}
						</button>
						<button type="button" class="btn btn-text btn-sm" on:click={cancelAddNews}>Cancel</button>
					</div>
				</div>
			{:else}
				<button type="button" class="btn btn-secondary btn-sm" on:click={openAddNews}>
					+ Add news item
				</button>
			{/if}
				</div>
			</div>
		</div>

		<!-- Sponsors (CRUD) -->
		<div class="collapse-card form-card">
			<button type="button" class="collapse-header" on:click={() => toggleSection('sponsors')} aria-expanded={openSections.sponsors}>
				<span class="collapse-title">Sponsors</span>
				<span class="collapse-icon" aria-hidden="true">{openSections.sponsors ? '▼' : '▶'}</span>
			</button>
			<div class="collapse-body" class:open={openSections.sponsors}>
				<div class="collapse-inner">
			{#if config?.sponsors?.length}
				{#each config.sponsors as s, index}
					<div class="form-array-item form-array-item--vertical form-array-item--sponsor">
						<div class="form-array-item-fields">
							{#if s.logo_url}
								<div class="form-group form-group--logo">
									<label for="sponsor-logo-replace-{index}">Logo</label>
									<img src={logoFullUrl(s.logo_url)} alt="" class="logo-preview" />
									<input
										id="sponsor-logo-replace-{index}"
										type="file"
										accept="image/*"
										on:change={(e) => setSponsorLogoReplacement(index, e.currentTarget.files?.[0] ?? null)}
									/>
								</div>
							{/if}
							<div class="form-group">
								<label for="sponsor-name-{index}">Name</label>
								<input id="sponsor-name-{index}" type="text" bind:value={s.name} placeholder="Sponsor name" />
							</div>
							<div class="form-group">
								<label for="sponsor-website-{index}">Website URL</label>
								<input id="sponsor-website-{index}" type="url" bind:value={s.website_url} placeholder="https://…" />
							</div>
							<div class="form-group form-group--checkbox">
								<label>
									<input type="checkbox" bind:checked={s.is_active} />
									Active
								</label>
							</div>
						</div>
						<div class="form-array-item-actions">
							<button type="button" class="btn btn-secondary btn-sm" on:click={() => saveSponsor(index)}>
								Update
							</button>
							<button
								type="button"
								class="btn btn-text btn-sm"
								on:click={() => removeSponsor(index)}
								aria-label="Remove sponsor"
							>
								Remove
							</button>
						</div>
					</div>
				{/each}
			{:else}
				<p class="form-hint">No sponsors yet. Add one below.</p>
			{/if}

			{#if showAddSponsor}
				<div class="form-array-item form-array-item--vertical form-array-item--new">
					<div class="form-array-item-fields">
						<div class="form-group">
							<label for="new-sponsor-name">Name</label>
							<input id="new-sponsor-name" type="text" bind:value={newSponsorName} placeholder="Sponsor name" />
						</div>
						<div class="form-group">
							<label for="new-sponsor-logo">Logo (required)</label>
							<input
								bind:this={sponsorLogoInput}
								id="new-sponsor-logo"
								type="file"
								accept="image/*"
								on:change={(e) => (newSponsorLogoFile = e.currentTarget.files?.[0] ?? null)}
							/>
						</div>
						<div class="form-group">
							<label for="new-sponsor-website">Website URL</label>
							<input id="new-sponsor-website" type="url" bind:value={newSponsorWebsite} placeholder="https://…" />
						</div>
						<div class="form-group form-group--checkbox">
							<label>
								<input type="checkbox" bind:checked={newSponsorActive} />
								Active
							</label>
						</div>
					</div>
					<div class="form-array-item-actions">
						<button type="button" class="btn btn-primary btn-sm" on:click={submitAddSponsor} disabled={addSponsorPending}>
							{addSponsorPending ? 'Adding…' : 'Add'}
						</button>
						<button type="button" class="btn btn-text btn-sm" on:click={cancelAddSponsor}>Cancel</button>
					</div>
				</div>
			{:else}
				<button type="button" class="btn btn-secondary btn-sm" on:click={openAddSponsor}>
					+ Add sponsor
				</button>
			{/if}
				</div>
			</div>
		</div>

		<!-- Media partners (CRUD) -->
		<div class="collapse-card form-card">
			<button type="button" class="collapse-header" on:click={() => toggleSection('mediaPartners')} aria-expanded={openSections.mediaPartners}>
				<span class="collapse-title">Media Partners</span>
				<span class="collapse-icon" aria-hidden="true">{openSections.mediaPartners ? '▼' : '▶'}</span>
			</button>
			<div class="collapse-body" class:open={openSections.mediaPartners}>
				<div class="collapse-inner">
			{#if config?.media_partners?.length}
				{#each config.media_partners as m, index}
					<div class="form-array-item form-array-item--vertical form-array-item--sponsor">
						<div class="form-array-item-fields">
							{#if m.logo_url}
								<div class="form-group form-group--logo">
									<label for="media-logo-replace-{index}">Logo</label>
									<img src={logoFullUrl(m.logo_url)} alt="" class="logo-preview" />
									<input
										id="media-logo-replace-{index}"
										type="file"
										accept="image/*"
										on:change={(e) => setMediaPartnerLogoReplacement(index, e.currentTarget.files?.[0] ?? null)}
									/>
								</div>
							{/if}
							<div class="form-group">
								<label for="media-name-{index}">Name</label>
								<input id="media-name-{index}" type="text" bind:value={m.name} placeholder="Media partner name" />
							</div>
							<div class="form-group">
								<label for="media-website-{index}">Website URL</label>
								<input id="media-website-{index}" type="url" bind:value={m.website_url} placeholder="https://…" />
							</div>
							<div class="form-group form-group--checkbox">
								<label>
									<input type="checkbox" bind:checked={m.is_active} />
									Active
								</label>
							</div>
						</div>
						<div class="form-array-item-actions">
							<button type="button" class="btn btn-secondary btn-sm" on:click={() => saveMediaPartner(index)}>
								Update
							</button>
							<button
								type="button"
								class="btn btn-text btn-sm"
								on:click={() => removeMediaPartner(index)}
								aria-label="Remove media partner"
							>
								Remove
							</button>
						</div>
					</div>
				{/each}
			{:else}
				<p class="form-hint">No media partners yet. Add one below.</p>
			{/if}

			{#if showAddMediaPartner}
				<div class="form-array-item form-array-item--vertical form-array-item--new">
					<div class="form-array-item-fields">
						<div class="form-group">
							<label for="new-media-name">Name</label>
							<input id="new-media-name" type="text" bind:value={newMediaPartnerName} placeholder="Media partner name" />
						</div>
						<div class="form-group">
							<label for="new-media-logo">Logo (required)</label>
							<input
								bind:this={mediaPartnerLogoInput}
								id="new-media-logo"
								type="file"
								accept="image/*"
								on:change={(e) => (newMediaPartnerLogoFile = e.currentTarget.files?.[0] ?? null)}
							/>
						</div>
						<div class="form-group">
							<label for="new-media-website">Website URL</label>
							<input id="new-media-website" type="url" bind:value={newMediaPartnerWebsite} placeholder="https://…" />
						</div>
						<div class="form-group form-group--checkbox">
							<label>
								<input type="checkbox" bind:checked={newMediaPartnerActive} />
								Active
							</label>
						</div>
					</div>
					<div class="form-array-item-actions">
						<button type="button" class="btn btn-primary btn-sm" on:click={submitAddMediaPartner} disabled={addMediaPartnerPending}>
							{addMediaPartnerPending ? 'Adding…' : 'Add'}
						</button>
						<button type="button" class="btn btn-text btn-sm" on:click={cancelAddMediaPartner}>Cancel</button>
					</div>
				</div>
			{:else}
				<button type="button" class="btn btn-secondary btn-sm" on:click={openAddMediaPartner}>
					+ Add media partner
				</button>
			{/if}
				</div>
			</div>
		</div>

		<!-- Social links (saved with main form) -->
		<div class="collapse-card form-card">
			<button type="button" class="collapse-header" on:click={() => toggleSection('socialLinks')} aria-expanded={openSections.socialLinks}>
				<span class="collapse-title">Social Links</span>
				<span class="collapse-icon" aria-hidden="true">{openSections.socialLinks ? '▼' : '▶'}</span>
			</button>
			<div class="collapse-body" class:open={openSections.socialLinks}>
				<div class="collapse-inner">
			{#each socialLinks as link (link._id)}
				<div class="form-array-item form-array-item--vertical">
					<div class="form-array-item-fields">
						<div class="form-group">
							<label for="social-platform-{link._id}">Platform</label>
							<input
								id="social-platform-{link._id}"
								type="text"
								bind:value={link.platform}
								placeholder="e.g. Facebook, Instagram, YouTube"
							/>
						</div>
						<div class="form-group">
							<label for="social-url-{link._id}">URL</label>
							<input id="social-url-{link._id}" type="url" bind:value={link.url} placeholder="https://…" />
						</div>
					</div>
					<button
						type="button"
						class="btn btn-text btn-sm"
						on:click={() => removeSocialLink(link._id)}
						aria-label="Remove link"
					>
						Remove
					</button>
				</div>
			{/each}
			<button type="button" class="btn btn-secondary btn-sm" on:click={addSocialLink}>
				+ Add social link
			</button>
				</div>
			</div>
		</div>

		<div class="form-actions">
			<button type="submit" class="btn btn-primary" disabled={saving}>
				{saving ? 'Saving…' : 'Save changes'}
			</button>
		</div>
	</form>
{/if}

<style>
	.collapse-card {
		padding: 0;
		overflow: hidden;
		border-radius: var(--radius);
	}
	.collapse-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		padding: 1rem 1.25rem;
		font: inherit;
		font-size: 1.1rem;
		font-weight: 600;
		color: var(--text);
		background: var(--bg-card);
		border: none;
		border-bottom: 1px solid var(--border);
		cursor: pointer;
		text-align: left;
		transition: background 0.15s, border-color 0.15s;
	}
	.collapse-header:hover {
		background: var(--bg-muted);
	}
	.collapse-header:focus {
		outline: none;
		box-shadow: 0 0 0 2px var(--primary);
	}
	/* When section is closed, header is the last visible element – show full card radius */
	.collapse-card:not(:has(.collapse-body.open)) .collapse-header {
		border-bottom: none;
	}
	.collapse-title {
		flex: 1;
	}
	.collapse-icon {
		flex-shrink: 0;
		margin-left: 0.5rem;
		font-size: 0.7rem;
		color: var(--text-muted);
	}
	.collapse-body {
		max-height: 0;
		overflow: hidden;
		transition: max-height 0.3s ease-out;
	}
	.collapse-body.open {
		max-height: 5000px;
	}
	.collapse-inner {
		padding: 1.25rem 1.25rem 1.25rem 1.25rem;
		border-top: none;
		background: var(--bg-card);
	}
	.about-assets {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1.5rem;
		margin-bottom: 1rem;
	}
	.about-asset label:first-child {
		display: block;
		margin-bottom: 0.5rem;
	}
	.asset-preview-wrap {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}
	.asset-preview {
		display: block;
		background: var(--bg-muted);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		object-fit: contain;
	}
	.asset-preview--logo {
		width: 120px;
		height: 80px;
	}
	.asset-preview--banner {
		width: 100%;
		max-width: 320px;
		max-height: 120px;
	}
	.asset-actions {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 0.35rem;
	}
	@media (max-width: 600px) {
		.about-assets {
			grid-template-columns: 1fr;
		}
	}
	.form-row--pricing {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
		gap: 1rem;
	}
	.form-hint {
		margin: 0 0 0.75rem 0;
		color: var(--text-muted);
		font-size: 0.9rem;
	}
	.form-array-item--vertical {
		display: flex;
		align-items: flex-start;
		gap: 0.75rem;
		margin-bottom: 1rem;
		padding: 1rem;
		background: var(--bg-muted);
		border-radius: var(--radius);
		flex-wrap: wrap;
	}
	.form-array-item--sponsor .form-array-item-fields,
	.form-array-item--new .form-array-item-fields {
		display: grid;
		grid-template-columns: auto 1fr 1fr auto;
		gap: 1rem;
		align-items: start;
		flex: 1;
		min-width: 0;
	}
	.form-array-item-actions {
		display: flex;
		gap: 0.5rem;
		align-items: center;
		flex-shrink: 0;
	}
	.form-group--logo {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}
	.form-group--logo input[type="file"] {
		font-size: 0.85rem;
	}
	.logo-preview {
		width: 80px;
		height: 50px;
		object-fit: contain;
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
	}
	.form-array-item--news .form-array-item-fields,
	.form-array-item-fields--news {
		display: grid;
		grid-template-columns: auto 1fr 1fr auto;
		gap: 1rem;
		align-items: start;
	}
	.form-array-item--news .form-group--full,
	.form-array-item-fields--news .form-group--full {
		grid-column: 1 / -1;
	}
	.news-media-preview {
		width: 100px;
		max-height: 60px;
		object-fit: contain;
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
	}
	@media (max-width: 720px) {
		.form-array-item--sponsor .form-array-item-fields,
		.form-array-item--new .form-array-item-fields {
			grid-template-columns: 1fr;
		}
		.form-array-item--news .form-array-item-fields,
		.form-array-item-fields--news {
			grid-template-columns: 1fr;
		}
		.form-array-item--news .form-group--full,
		.form-array-item-fields--news .form-group--full {
			grid-column: 1;
		}
	}
	.form-group--checkbox label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}
	.form-actions {
		margin-top: 1rem;
		margin-bottom: 2rem;
	}
</style>
