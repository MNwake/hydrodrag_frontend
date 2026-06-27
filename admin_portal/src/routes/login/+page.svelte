<script lang="ts">
	import { goto } from '$app/navigation';
	import { tryPortalLogin, setPortalSession, isStaffLoginConfigured } from '$lib/admin-auth';

	let username = '';
	let password = '';
	let loading = false;
	let error = '';

	function handleSubmit(e: Event) {
		e.preventDefault();
		error = '';
		if (!username.trim() || !password) {
			error = 'Enter username and password';
			return;
		}
		loading = true;
		const role = tryPortalLogin(username.trim(), password);
		if (role) {
			setPortalSession(role, username.trim());
			goto(role === 'staff' ? '/events' : '/dashboard');
		} else {
			error = 'Invalid username or password';
			loading = false;
		}
	}
</script>

<div class="login-page">
	<div class="login-card">
		<h1 class="login-title">HydroDrags Admin</h1>
		<p class="login-subtitle">Sign in with admin or staff credentials</p>

		<form class="login-form" on:submit|preventDefault={handleSubmit}>
			<label for="username">Username</label>
			<input
				id="username"
				type="text"
				bind:value={username}
				placeholder="admin"
				autocomplete="username"
				disabled={loading}
			/>
			<label for="password">Password</label>
			<input
				id="password"
				type="password"
				bind:value={password}
				placeholder="Password"
				autocomplete="current-password"
				disabled={loading}
			/>
			<button type="submit" class="btn btn-primary" disabled={loading}>
				{loading ? 'Signing in…' : 'Sign in'}
			</button>
		</form>

		{#if error}
			<p class="login-error" role="alert">{error}</p>
		{/if}

		{#if import.meta.env.DEV && !isStaffLoginConfigured()}
			<p class="login-hint">
				Staff login is off: add <code>VITE_STAFF_USERNAME</code> and <code>VITE_STAFF_PASSWORD</code> to
				<code>.env.local</code> in this app folder, then restart <code>npm run dev</code>. For production, set
				them before <code>vite build</code> (see <code>deploy_admin_frontend.py</code>).
			</p>
		{/if}
	</div>
</div>
