<script lang="ts">
	/** Initial/synced HTML (e.g. from server). Updated when prop changes; edits are kept in the contenteditable until getHtml() is called. */
	export let content = '';
	/** Optional id for the contenteditable (e.g. for label for=""). */
	export let id: string | undefined = undefined;

	let editorEl: HTMLDivElement;
	let lastContentFromParent = '';
	let savedRange: Range | null = null;

	/** Sync contenteditable from parent when content prop changes (e.g. after config load). */
	$: if (content !== lastContentFromParent && editorEl) {
		lastContentFromParent = content;
		editorEl.innerHTML = content || '';
	}

	function saveSelection() {
		const sel = window.getSelection();
		if (!sel || !editorEl?.contains(sel.anchorNode)) return;
		try {
			savedRange = sel.getRangeAt(0).cloneRange();
		} catch {
			savedRange = null;
		}
	}

	function restoreSelection() {
		if (!savedRange || !editorEl) return;
		const sel = window.getSelection();
		if (!sel) return;
		sel.removeAllRanges();
		sel.addRange(savedRange);
	}

	/** Get current HTML from the editor (call before save). */
	export function getHtml(): string {
		return editorEl?.innerHTML ?? '';
	}

	function exec(cmd: string, value: string | undefined = undefined) {
		if (!editorEl) return;
		editorEl.focus();
		restoreSelection();
		document.execCommand(cmd, false, value);
	}
</script>

<div class="rich-text-editor">
	<div class="rich-text-toolbar" role="toolbar">
		<button type="button" class="rich-text-btn" title="Bold" on:click|preventDefault={() => exec('bold')}>B</button>
		<button type="button" class="rich-text-btn" title="Italic" on:click|preventDefault={() => exec('italic')}>I</button>
		<button type="button" class="rich-text-btn" title="Underline" on:click|preventDefault={() => exec('underline')}>U</button>
		<span class="rich-text-sep" aria-hidden="true">|</span>
		<button type="button" class="rich-text-btn" title="Bullet list" on:click|preventDefault={() => exec('insertUnorderedList')}>• List</button>
		<button type="button" class="rich-text-btn" title="Numbered list" on:click|preventDefault={() => exec('insertOrderedList')}>1. List</button>
		<span class="rich-text-sep" aria-hidden="true">|</span>
		<button type="button" class="rich-text-btn" title="Paragraph" on:click|preventDefault={() => exec('formatBlock', 'p')}>P</button>
		<button type="button" class="rich-text-btn" title="Heading 2" on:click|preventDefault={() => exec('formatBlock', 'h2')}>H2</button>
		<button type="button" class="rich-text-btn" title="Heading 3" on:click|preventDefault={() => exec('formatBlock', 'h3')}>H3</button>
		<span class="rich-text-sep" aria-hidden="true">|</span>
		<button type="button" class="rich-text-btn" title="Insert link" on:click|preventDefault={() => exec('createLink', prompt('URL:') || undefined)}>Link</button>
	</div>
	<div
		id={id}
		class="rich-text-body"
		contenteditable="true"
		role="textbox"
		aria-label="Waiver content"
		bind:this={editorEl}
		on:blur={saveSelection}
		data-placeholder="Enter waiver text… Use the toolbar for bold, lists, headings, etc."
	></div>
</div>

<style>
	.rich-text-editor {
		border: 1px solid var(--border);
		border-radius: var(--radius);
		overflow: hidden;
		background: var(--bg-card);
	}
	.rich-text-toolbar {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 0.25rem;
		padding: 0.5rem;
		border-bottom: 1px solid var(--border);
		background: var(--bg-muted);
	}
	.rich-text-btn {
		padding: 0.35rem 0.6rem;
		font-size: 0.85rem;
		font-weight: 600;
		color: var(--text);
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		cursor: pointer;
	}
	.rich-text-btn:hover {
		background: var(--border);
	}
	.rich-text-sep {
		color: var(--text-muted);
		margin: 0 0.25rem;
		font-size: 0.8rem;
	}
	.rich-text-body {
		min-height: 280px;
		padding: 1rem;
		font-size: 1rem;
		line-height: 1.6;
		color: var(--text);
		outline: none;
		overflow-y: auto;
	}
	.rich-text-body:empty::before {
		content: attr(data-placeholder);
		color: var(--text-muted);
	}
	.rich-text-body:focus {
		box-shadow: inset 0 0 0 2px var(--primary);
	}
</style>
