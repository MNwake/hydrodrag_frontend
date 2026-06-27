import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],

	preview: {
		host: '127.0.0.1',
		port: 3002,
		allowedHosts: [
			'staging-admin.hydrodrags.koesterventures.com'
		]
	}
});


