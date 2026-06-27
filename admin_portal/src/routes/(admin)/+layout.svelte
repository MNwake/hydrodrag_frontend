<script lang="ts">
	import { page } from '$app/stores';
	import { getPortalUsername, clearPortalSession, isStaffPortal } from '$lib/admin-auth';

	const navAdmin = [
		{ href: '/dashboard', label: 'Dashboard' },
		{ href: '/company', label: 'Company' },
		{ href: '/events', label: 'Events' },
		{ href: '/racers', label: 'Racers' },
		{ href: '/registrations', label: 'Registrations' },
		{ href: '/spectators', label: 'Attendees / passes' },
		{ href: '/shirts', label: 'Shirt sales' },
		{ href: '/payments', label: 'Payments' }
	];

	const navStaff = [
		{ href: '/events', label: 'Events' },
		{ href: '/racers', label: 'Racers' }
	];

	$: nav = isStaffPortal() ? navStaff : navAdmin;

	let sidebarOpen = false;

	function logout() {
		clearPortalSession();
		window.location.href = '/login';
	}

	function closeSidebar() {
		sidebarOpen = false;
	}

	// Close sidebar on navigation (mobile)
	$: if ($page.url.pathname) {
		sidebarOpen = false;
	}
</script>

<div class="admin-layout">
	<button
		type="button"
		class="sidebar-toggle"
		aria-label="Toggle menu"
		aria-expanded={sidebarOpen}
		on:click={() => (sidebarOpen = !sidebarOpen)}
	>
		<span class="sidebar-toggle-bar"></span>
		<span class="sidebar-toggle-bar"></span>
		<span class="sidebar-toggle-bar"></span>
	</button>
	<button
		type="button"
		class="sidebar-overlay"
		aria-label="Close menu"
		class:open={sidebarOpen}
		on:click={closeSidebar}
	></button>
	<aside class="sidebar" class:open={sidebarOpen}>
		<div class="sidebar-brand">HydroDrags {isStaffPortal() ? 'Staff' : 'Admin'}</div>
		<nav class="sidebar-nav">
			{#each nav as item}
				<a
					href={item.href}
					class="sidebar-link"
					class:active={$page.url.pathname === item.href}
					on:click={closeSidebar}
				>
					{item.label}
				</a>
			{/each}
		</nav>
	</aside>
	<div class="main">
		<header class="topbar">
			<div class="topbar-spacer"></div>
			<div class="topbar-actions">
				<span class="topbar-email">{getPortalUsername()}</span>
				<button type="button" class="btn btn-secondary btn-sm" on:click={logout}>
					Logout
				</button>
			</div>
		</header>
		<main class="content">
			<slot />
		</main>
	</div>
</div>
