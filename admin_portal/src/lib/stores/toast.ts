import { writable } from 'svelte/store';

export type ToastKind = 'default' | 'success' | 'error';

export interface ToastMessage {
	id: number;
	text: string;
	kind: ToastKind;
}

let id = 0;
const { subscribe, update } = writable<ToastMessage[]>([]);

export const toastMessages = { subscribe };

export function toast(text: string, kind: ToastKind = 'default') {
	const n = ++id;
	update((list) => [...list, { id: n, text, kind }]);
	setTimeout(() => {
		update((list) => list.filter((x) => x.id !== n));
	}, 4000);
}

export function dismissToast(messageId: number) {
	update((list) => list.filter((x) => x.id !== messageId));
}
