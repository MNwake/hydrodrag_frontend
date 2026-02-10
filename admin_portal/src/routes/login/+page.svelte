<script lang="ts">
	import { goto } from '$app/navigation';
	import { checkCredentials, setAdminLoggedIn } from '$lib/admin-auth';

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
		if (checkCredentials(username.trim(), password)) {
			setAdminLoggedIn();
			goto('/dashboard');
		} else {
			error = 'Invalid username or password';
			loading = false;
		}
	}
</script>

<div class="login-page">
	<div class="login-card">
		<h1 class="login-title">HydroDrags Admin</h1>
		<p class="login-subtitle">Sign in with your admin credentials</p>

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
	</div>
</div>
