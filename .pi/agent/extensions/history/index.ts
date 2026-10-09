/**
 * Session History Browser
 *
 * Review an agent turn without scrolling the transcript:
 * - /history or Ctrl+Shift+H opens a list of turns (one item per user message)
 * - Enter opens a turn viewer with the user question, every tool call/result in
 *   order, and the final answer. Tool output starts collapsed.
 * - / searches inside the turn, [ / ] move between turns
 *
 * Read-only: it never changes the session, active branch, or context.
 */

import type { AgentMessage } from "@earendil-works/pi-agent-core";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import {
	type Component,
	Input,
	Key,
	Markdown,
	matchesKey,
	type Theme,
	truncateToWidth,
	type TUI,
	visibleWidth,
	wrapTextWithAnsi,
} from "@earendil-works/pi-tui";

type ToolBlock = {
	type: "tool";
	callId: string;
	name: string;
	args: Record<string, unknown>;
	argsPreview: string;
	resultText: string;
	resultPreview: string;
	isError: boolean;
	durationMs?: number;
};

type ThinkingBlock = {
	type: "thinking";
	text: string;
};

type AssistantTextBlock = {
	type: "assistantText";
	text: string;
};

type TurnBlock = ToolBlock | ThinkingBlock | AssistantTextBlock;

interface Turn {
	/** 0-based turn index among the turns we keep. */
	position: number;
	userText: string;
	userTimestamp?: number;
	/** Timestamp of the last entry that belongs to this turn. */
	lastTimestamp?: number;
	blocks: TurnBlock[];
	/** Final assistant answer text for this turn (may be empty). */
	finalText: string;
	toolCount: number;
	errorCount: number;
	/** Wall clock from user message to last entry in the turn. */
	durationMs?: number;
	/** Plain-text haystack used for list search. */
	searchText: string;
}

const READER_BODY_ROWS = 18;

/** Durable, non-context browsing position for the history viewer. */
interface HistoryViewState {
	turnPosition: number;
	toolCallId?: string;
	offset: number;
}

const HISTORY_VIEW_ENTRY = "history-view";

function extractText(message: AgentMessage): string {
	const content = (message as { content?: unknown }).content;
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";

	const parts: string[] = [];
	for (const block of content) {
		if (!block || typeof block !== "object") continue;
		const typed = block as { type?: string; text?: string };
		if (typed.type === "text" && typeof typed.text === "string") {
			parts.push(typed.text);
		} else if (typed.type === "image") {
			parts.push("[图片]");
		}
	}
	return parts.join("\n");
}

function extractThinking(message: AgentMessage): string {
	const content = (message as { content?: unknown }).content;
	if (!Array.isArray(content)) return "";
	const parts: string[] = [];
	for (const block of content) {
		if (!block || typeof block !== "object") continue;
		const typed = block as { type?: string; thinking?: string };
		if (typed.type === "thinking" && typeof typed.thinking === "string") {
			parts.push(typed.thinking);
		}
	}
	return parts.join("\n\n");
}

/** Collapse an argument value into a short single-line preview. */
function summarizeArgs(name: string, args: Record<string, unknown>): string {
	if (!args || Object.keys(args).length === 0) return "";
	// Prefer the most identifying argument for common tools.
	const preferred = ["command", "path", "file_path", "pattern", "query", "url", "prompt"];
	for (const key of preferred) {
		const value = args[key];
		if (typeof value === "string" && value.trim()) return oneLine(value);
	}
	const entries = Object.entries(args).slice(0, 3);
	return entries
		.map(([key, value]) => `${key}=${oneLine(typeof value === "string" ? value : JSON.stringify(value))}`)
		.join(" ");
}

function oneLine(text: string): string {
	return text.replace(/\s+/g, " ").trim();
}

function firstLine(text: string): string {
	const line = text
		.split("\n")
		.map((value) => value.trim())
		.find((value) => value.length > 0);
	return line ?? "";
}

function formatTime(timestamp: number | undefined): string {
	if (!timestamp) return "";
	try {
		return new Date(timestamp).toLocaleTimeString();
	} catch {
		return "";
	}
}

function formatDuration(ms: number | undefined): string {
	if (ms === undefined || ms < 0) return "";
	if (ms < 1000) return `${Math.round(ms)}ms`;
	return `${(ms / 1000).toFixed(1)}s`;
}

/**
 * Group session entries into turns. A turn starts at a user message and runs
 * until the next user message. Within a turn we keep blocks in original order
 * so the viewer can replay exactly what the agent did.
 */
function buildTurns(
	entries: ReturnType<ExtensionCommandContext["sessionManager"]["getBranch"]>,
): Turn[] {
	const turns: Turn[] = [];
	let current: Turn | null = null;
	// Map toolCallId -> ToolBlock so a later toolResult fills in its call.
	let toolIndex = new Map<string, ToolBlock>();

	const finalize = () => {
		if (!current) return;
		const lastBlock = current.blocks[current.blocks.length - 1];
		if (lastBlock?.type === "assistantText") current.finalText = lastBlock.text;
		if (current.userTimestamp !== undefined && current.lastTimestamp !== undefined) {
			current.durationMs = Math.max(0, current.lastTimestamp - current.userTimestamp);
		}
		current.searchText = buildSearchText(current);
		turns.push(current);
		current = null;
		toolIndex = new Map();
	};

	for (const entry of entries) {
		if (entry.type !== "message") continue;
		const message = entry.message;
		const timestamp = typeof message.timestamp === "number" ? message.timestamp : undefined;

		if (message.role === "user") {
			finalize();
			current = {
				position: turns.length,
				userText: extractText(message).trim(),
				userTimestamp: timestamp,
				lastTimestamp: timestamp,
				blocks: [],
				finalText: "",
				toolCount: 0,
				errorCount: 0,
				searchText: "",
			};
			continue;
		}

		if (!current) continue; // assistant/tool content before any user message

		if (message.role === "assistant") {
			const thinking = extractThinking(message).trim();
			if (thinking) current.blocks.push({ type: "thinking", text: thinking });

			const content = (message as { content?: unknown }).content;
			if (Array.isArray(content)) {
				for (const raw of content) {
					if (!raw || typeof raw !== "object") continue;
					const block = raw as { type?: string; text?: string; id?: string; name?: string; arguments?: Record<string, unknown> };
					if (block.type === "text" && typeof block.text === "string" && block.text.trim()) {
						current.blocks.push({ type: "assistantText", text: block.text.trim() });
					} else if (block.type === "toolCall" && typeof block.name === "string") {
						const args = (block.arguments ?? {}) as Record<string, unknown>;
						const tool: ToolBlock = {
							type: "tool",
							callId: typeof block.id === "string" ? block.id : `${current.blocks.length}`,
							name: block.name,
							args,
							argsPreview: summarizeArgs(block.name, args),
							resultText: "",
							resultPreview: "",
							isError: false,
						};
						current.blocks.push(tool);
						current.toolCount += 1;
						toolIndex.set(tool.callId, tool);
					}
				}
			}

			if (timestamp !== undefined) current.lastTimestamp = timestamp;
			continue;
		}

		if (message.role === "toolResult") {
			const callId = typeof (message as { toolCallId?: unknown }).toolCallId === "string"
				? (message as { toolCallId: string }).toolCallId
				: "";
			const resultText = extractText(message).trim();
			const isError = Boolean((message as { isError?: unknown }).isError);
			const tool = callId ? toolIndex.get(callId) : undefined;
			if (tool) {
				tool.resultText = resultText;
				tool.resultPreview = summarizeResult(resultText, isError);
				tool.isError = isError;
				if (isError) current.errorCount += 1;
			} else {
				// Orphan result without a matching call: keep it visible anyway.
				current.blocks.push({
					type: "tool",
					callId,
					name: typeof (message as { toolName?: unknown }).toolName === "string" ? (message as { toolName: string }).toolName : "tool",
					args: {},
					argsPreview: "",
					resultText,
					resultPreview: summarizeResult(resultText, isError),
					isError,
				});
				current.toolCount += 1;
				if (isError) current.errorCount += 1;
			}
			if (timestamp !== undefined) current.lastTimestamp = timestamp;
			continue;
		}
	}

	finalize();
	return turns.map((turn, index) => ({ ...turn, position: index }));
}

function summarizeResult(text: string, isError: boolean): string {
	if (!text) return isError ? "error" : "(no output)";
	const lines = text.split("\n").filter((value) => value.trim().length > 0);
	const lineLabel = `${lines.length} 行`;
	return isError ? `error · ${lineLabel}` : lineLabel;
}

function buildSearchText(turn: Turn): string {
	const parts = [turn.userText];
	for (const block of turn.blocks) {
		if (block.type === "assistantText") parts.push(block.text);
		else if (block.type === "thinking") parts.push(block.text);
		else parts.push(block.name, block.argsPreview, block.resultText);
	}
	return parts.join("\n").toLowerCase();
}

function turnPreview(turn: Turn): string {
	return firstLine(turn.finalText) || firstLine(turn.userText) || "(空回合)";
}

export default function historyExtension(pi: ExtensionAPI): void {
	async function openHistory(ctx: ExtensionCommandContext): Promise<void> {
		if (ctx.mode !== "tui" || !ctx.hasUI) {
			ctx.ui.notify("/history 需要在交互式 TUI 模式下使用。", "warning");
			return;
		}

		const turns = buildTurns(ctx.sessionManager.getBranch());
		if (turns.length === 0) {
			ctx.ui.notify("当前会话还没有可浏览的回合。", "info");
			return;
		}

		const saved = readHistoryView(ctx);
		const resumeTurn = clampIndex(saved?.turnPosition ?? turns.length - 1, 0, turns.length - 1);

		const selected = await ctx.ui.custom<number | null>(
			(ui, theme, _kb, done) => new TurnPicker(ui, theme, turns, resumeTurn, done),
			{ overlay: true, overlayOptions: { anchor: "center", width: "84%", maxHeight: 24 } },
		);
		if (selected === null || selected === undefined) return;

		const result = await ctx.ui.custom<HistoryViewState | undefined>(
			(ui, theme, _kb, done) =>
				new TurnViewer(ui, theme, turns, selected, saved, (state) => done(state)),
			{ overlay: true, overlayOptions: { anchor: "center", width: "88%", maxHeight: 32 } },
		);
		if (result) pi.appendEntry<HistoryViewState>(HISTORY_VIEW_ENTRY, result);
	}

	pi.registerCommand("history", {
		description: "Review session turns with tool calls and results",
		handler: async (_args, ctx) => {
			await openHistory(ctx);
		},
	});

	pi.registerShortcut(Key.ctrlShift("h"), {
		description: "Review session turns",
		handler: async (ctx) => {
			await openHistory(ctx);
		},
	});
}

/** Last persisted browsing position on the current branch, if any. */
function readHistoryView(ctx: ExtensionCommandContext): HistoryViewState | undefined {
	const entries = ctx.sessionManager.getBranch();
	for (let i = entries.length - 1; i >= 0; i--) {
		const entry = entries[i];
		if (entry.type === "custom" && entry.customType === HISTORY_VIEW_ENTRY) {
			return entry.data as HistoryViewState;
		}
	}
	return undefined;
}

function clampIndex(value: number, min: number, max: number): number {
	if (!Number.isFinite(value)) return min;
	return Math.max(min, Math.min(value, max));
}

/** Shared box drawing helpers for the picker and viewer. */
class Box {
	constructor(private readonly theme: Theme) {}

	line(width: number): string {
		return this.theme.fg("border", `─`.repeat(Math.max(0, width)));
	}

	top(width: number, title?: string): string {
		const inner = Math.max(0, width - 2);
		if (!title) return this.theme.fg("border", `╭${"─".repeat(inner)}╮`);
		// Truncate without padding: the remaining cells become the top border rule.
		const text = truncateToWidth(` ${title} `, inner, "…");
		const pad = Math.max(0, inner - visibleWidth(text));
		return this.theme.fg("border", "╭") + this.theme.fg("accent", text) + this.theme.fg("border", `${"─".repeat(pad)}╮`);
	}

	bottom(width: number): string {
		return this.theme.fg("border", `╰${"─".repeat(Math.max(0, width - 2))}╯`);
	}

	row(content: string, width: number): string {
		const inner = Math.max(1, width - 2);
		const clipped = truncateToWidth(content, inner, "…", true);
		const gap = Math.max(0, inner - visibleWidth(clipped));
		return this.theme.fg("border", "│") + clipped + " ".repeat(gap) + this.theme.fg("border", "│");
	}
}

class TurnPicker implements Component {
	private readonly search: Input;
	private readonly tui: TUI;
	private readonly theme: Theme;
	private readonly box: Box;
	private readonly turns: Turn[];
	private readonly done: (value: number | null) => void;
	private filtered: Turn[];
	private selectedIndex = 0;
	private cachedWidth = -1;
	private cachedFilter: string | null = null;
	private cachedSelectedIndex = -1;
	private lines: string[] = [];

	focused = true;

	constructor(tui: TUI, theme: Theme, turns: Turn[], startIndex: number, done: (value: number | null) => void) {
		this.tui = tui;
		this.theme = theme;
		this.box = new Box(theme);
		this.turns = turns;
		this.done = done;
		this.filtered = turns;
		this.selectedIndex = clampIndex(startIndex, 0, Math.max(0, turns.length - 1));
		this.search = new Input();
		this.search.focused = true;
		this.search.onSubmit = () => {
			const selected = this.filtered[this.selectedIndex];
			if (selected) this.done(selected.position);
		};
	}

	handleInput(data: string): void {
		if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
			this.done(null);
			return;
		}
		if ((matchesKey(data, "enter") || matchesKey(data, "return")) && this.filtered[this.selectedIndex]) {
			this.done(this.filtered[this.selectedIndex]!.position);
			return;
		}
		if (matchesKey(data, "up")) {
			this.move(-1);
			return;
		}
		if (matchesKey(data, "down")) {
			this.move(1);
			return;
		}
		if (matchesKey(data, "pageUp")) {
			this.move(-8);
			return;
		}
		if (matchesKey(data, "pageDown")) {
			this.move(8);
			return;
		}
		this.search.handleInput(data);
		this.applyFilter();
		this.tui.requestRender();
	}

	invalidate(): void {
		this.cachedWidth = -1;
		this.cachedFilter = null;
	}

	render(width: number): string[] {
		const filter = this.search.getValue();
		if (width === this.cachedWidth && filter === this.cachedFilter && this.selectedIndex === this.cachedSelectedIndex) {
			return this.lines;
		}

		const theme = this.theme;
		const lines: string[] = [];
		lines.push(this.box.top(width, "会话历史 · 回合"));
		lines.push(this.box.row(theme.fg("dim", `  ${this.turns.length} 个回合`), width));

		const [searchLine = ""] = this.search.render(Math.max(1, width - 4));
		lines.push(this.box.row(`  ${searchLine}`, width));

		const maxVisible = 12;
		if (this.filtered.length === 0) {
			lines.push(this.box.row(theme.fg("warning", "  没有匹配的回合"), width));
		} else {
			const start = clampStart(this.selectedIndex, this.filtered.length, maxVisible);
			const end = Math.min(start + maxVisible, this.filtered.length);
			for (let i = start; i < end; i++) {
				const turn = this.filtered[i]!;
				const isSelected = i === this.selectedIndex;
				const prefix = isSelected ? theme.fg("accent", "→ ") : "  ";
				const meta: string[] = [];
				meta.push(`${turn.toolCount} tools`);
				if (turn.errorCount > 0) meta.push(theme.fg("error", `${turn.errorCount} err`));
				const metaText = theme.fg("dim", `  · ${meta.join(" · ")}`);
				const preview = turnPreview(turn);
				lines.push(this.box.row(`${prefix}${theme.fg("accent", `[${turn.position + 1}]`)} ${preview}${metaText}`, width));
			}
			if (this.filtered.length > maxVisible) {
				lines.push(this.box.row(theme.fg("dim", `  (${this.selectedIndex + 1}/${this.filtered.length})`), width));
			}
		}

		lines.push(this.box.row(theme.fg("dim", " 输入搜索 • ↑↓ 移动 • Enter 查看 • Esc 取消"), width));
		lines.push(this.box.bottom(width));

		this.cachedWidth = width;
		this.cachedFilter = filter;
		this.cachedSelectedIndex = this.selectedIndex;
		this.lines = lines;
		return lines;
	}

	private move(delta: number): void {
		if (this.filtered.length === 0) return;
		const next = (this.selectedIndex + delta) % this.filtered.length;
		this.selectedIndex = next < 0 ? next + this.filtered.length : next;
		this.tui.requestRender();
	}

	private applyFilter(): void {
		const query = this.search.getValue().trim().toLowerCase();
		this.filtered = query ? this.turns.filter((turn) => turn.searchText.includes(query)) : this.turns;
		this.selectedIndex = 0;
	}
}

class TurnViewer implements Component {
	private readonly tui: TUI;
	private readonly theme: Theme;
	private readonly box: Box;
	private readonly turns: Turn[];
	private readonly mdTheme = getMarkdownTheme();
	private readonly done: (state?: HistoryViewState) => void;

	private index: number;
	private offset = 0;
	private bodyRows = READER_BODY_ROWS;
	private expanded = new Set<string>();
	private selectedTool = 0;
	private toolLineIndex = new Map<string, number>();
	private cachedWidth = -1;
	private cachedIndex = -1;
	private cachedExpandKey = "";
	private cachedSelectedTool = -1;
	private cachedQuery = "";
	private cachedSearching = false;
	private body: string[] = [];

	private searching = false;
	private search = new Input();
	private matchLines: number[] = [];
	private matchCursor = -1;

	focused = true;

	constructor(
		tui: TUI,
		theme: Theme,
		turns: Turn[],
		startIndex: number,
		resume: HistoryViewState | undefined,
		done: (state?: HistoryViewState) => void,
	) {
		this.tui = tui;
		this.theme = theme;
		this.box = new Box(theme);
		this.turns = turns;
		this.index = clampIndex(startIndex, 0, turns.length - 1);
		this.done = done;
		this.search.focused = true;
		this.search.onSubmit = () => this.jumpMatch(1);

		if (resume && clampIndex(resume.turnPosition, 0, turns.length - 1) === this.index) {
			this.offset = Math.max(0, resume.offset ?? 0);
			if (resume.toolCallId) {
				const at = this.toolsInTurn().findIndex((tool) => tool.callId === resume.toolCallId);
				if (at >= 0) this.selectedTool = at;
			}
		}
	}

	handleInput(data: string): void {
		if (this.searching) {
			if (matchesKey(data, "escape")) {
				this.searching = false;
				this.tui.requestRender();
				return;
			}
			if (matchesKey(data, "enter") || matchesKey(data, "return")) {
				this.jumpMatch(1);
				return;
			}
			this.search.handleInput(data);
			this.invalidate();
			this.recomputeMatches();
			this.jumpMatch(1, true);
			this.tui.requestRender();
			return;
		}

		if (matchesKey(data, "escape") || matchesKey(data, "q") || matchesKey(data, "ctrl+c")) {
			this.done(this.snapshot());
			return;
		}
		if (matchesKey(data, "/")) {
			this.searching = true;
			this.search.setValue("");
			this.invalidate();
			this.recomputeMatches();
			this.tui.requestRender();
			return;
		}
		// Plain-text vertical scrolling, independent of the tool cursor.
		if (matchesKey(data, "k")) {
			this.scrollBy(-1);
			return;
		}
		if (matchesKey(data, "j")) {
			this.scrollBy(1);
			return;
		}
		if (matchesKey(data, "pageUp")) {
			this.scrollBy(-this.bodyRows);
			return;
		}
		if (matchesKey(data, "pageDown")) {
			this.scrollBy(this.bodyRows);
			return;
		}
		if (matchesKey(data, "u")) {
			this.scrollBy(-this.halfPage());
			return;
		}
		if (matchesKey(data, "d")) {
			this.scrollBy(this.halfPage());
			return;
		}
		if (matchesKey(data, "home")) {
			this.offset = 0;
			this.tui.requestRender();
			return;
		}
		if (matchesKey(data, "end")) {
			this.offset = this.maxOffset();
			this.tui.requestRender();
			return;
		}
		// Arrow keys move the tool cursor; Tab is an alias for the next tool.
		if (matchesKey(data, "up")) {
			this.moveTool(-1);
			return;
		}
		if (matchesKey(data, "down")) {
			this.moveTool(1);
			return;
		}
		if (matchesKey(data, "tab")) {
			this.moveTool(1);
			return;
		}
		if (matchesKey(data, "shift+tab") || matchesKey(data, "ctrl+o")) {
			this.toggleAllTools();
			return;
		}
		// Enter toggles the highlighted tool only.
		if (matchesKey(data, "enter") || matchesKey(data, "return")) {
			this.toggleSelectedTool();
			return;
		}
		if (matchesKey(data, "left") || matchesKey(data, "[")) {
			this.move(-1);
			return;
		}
		if (matchesKey(data, "right") || matchesKey(data, "]")) {
			this.move(1);
			return;
		}
		if (matchesKey(data, "n")) {
			this.jumpMatch(1);
			return;
		}
		if (matchesKey(data, "shift+n")) {
			this.jumpMatch(-1);
			return;
		}
	}

	invalidate(): void {
		this.cachedWidth = -1;
		this.cachedIndex = -1;
	}

	render(width: number): string[] {
		const turn = this.turns[this.index]!;
		const expandKey = [...this.expanded].sort().join(",");
		const query = this.search.getValue();
		const dirty =
			width !== this.cachedWidth ||
			this.index !== this.cachedIndex ||
			expandKey !== this.cachedExpandKey ||
			this.selectedTool !== this.cachedSelectedTool ||
			query !== this.cachedQuery ||
			this.searching !== this.cachedSearching;
		if (dirty) {
			const innerWidth = Math.max(1, width - 4);
			this.body = this.buildBody(turn, innerWidth);
			const searchingChanged = this.searching !== this.cachedSearching || query !== this.cachedQuery;
			if (searchingChanged) this.recomputeMatches();
			this.cachedWidth = width;
			this.cachedIndex = this.index;
			this.cachedExpandKey = expandKey;
			this.cachedSelectedTool = this.selectedTool;
			this.cachedQuery = query;
			this.cachedSearching = this.searching;
			this.offset = clampIndex(this.offset, 0, this.maxOffset());
		}

		const theme = this.theme;
		const lines: string[] = [];
		const meta: string[] = [`${turn.toolCount} tools`];
		if (turn.errorCount > 0) meta.push(theme.fg("error", `${turn.errorCount} errors`));
		const duration = formatDuration(turn.durationMs);
		if (duration) meta.push(duration);
		const time = formatTime(turn.userTimestamp);

		lines.push(this.box.top(width, `回合 ${turn.position + 1}/${this.turns.length}  ·  ${meta.join(" · ")}${time ? `  ·  ${time}` : ""}`));
		for (let i = 0; i < this.bodyRows; i++) {
			const bodyIndex = this.offset + i;
			const line = this.body[bodyIndex] ?? "";
			lines.push(this.box.row(this.decorateLine(bodyIndex, line), width));
		}

		if (this.searching) {
			const matchSummary = this.matchLines.length > 0 ? `  ${this.matchCursor + 1}/${this.matchLines.length}` : "  无匹配";
			const prefix = "  / ";
			const available = Math.max(4, width - 2 - visibleWidth(prefix) - visibleWidth(matchSummary));
			const [inputLine = ""] = this.search.render(available);
			const matchInfo = this.matchLines.length > 0 ? this.theme.fg("dim", matchSummary) : this.theme.fg("warning", matchSummary);
			lines.push(this.box.row(`${prefix}${inputLine}${matchInfo}`, width));
		} else {
			const max = this.maxOffset();
			const scroll = max > 0 ? theme.fg("dim", ` ${this.offset}/${max}`) : "";
			const hasTools = turn.toolCount > 0;
			const hint = hasTools
				? " ↑↓/Tab 选工具 • Enter 展开 • jk/U/D 滚动 • Shift+Tab 全部 • [ ] 回合 • / 搜索 • Esc 退出"
				: " jk/U/D 滚动 • PgUp/PgDn 翻页 • [ ] 回合 • / 搜索 • Esc 退出";
			lines.push(this.box.row(theme.fg("dim", hint) + scroll, width));
		}
		lines.push(this.box.bottom(width));
		return lines;
	}

	private buildBody(turn: Turn, innerWidth: number): string[] {
		const theme = this.theme;
		const lines: string[] = [];
		this.toolLineIndex.clear();

		// User question: a single accent line, no section header or extra spacing.
		const question = renderParagraph(turn.userText || "(空提问)", innerWidth - 4);
		lines.push(theme.fg("accent", "user") + "  " + theme.fg("text", question[0] ?? ""));
		for (const line of question.slice(1)) lines.push(`      ${line}`);
		lines.push("");

		let toolOrdinal = 0;
		for (const block of turn.blocks) {
			if (block.type === "assistantText") {
				lines.push(...indent(this.renderMarkdown(block.text, innerWidth - 2), 2));
				lines.push("");
			} else if (block.type === "thinking") {
				lines.push(indent([theme.fg("muted", `thinking · ${block.text.split("\n").length} 行`)], 2)[0]!);
				lines.push("");
			} else {
				this.toolLineIndex.set(block.callId, lines.length);
				lines.push(...this.renderTool(block, innerWidth, toolOrdinal === this.selectedTool));
				toolOrdinal += 1;
				lines.push("");
			}
		}

		if (turn.blocks.length === 0) {
			lines.push(theme.fg("muted", "(这一回合没有可展示的内容)"));
		}
		return lines;
	}

	private renderTool(tool: ToolBlock, innerWidth: number, selected: boolean): string[] {
		const theme = this.theme;
		const expanded = this.expanded.has(tool.callId);
		const marker = expanded ? "▾" : "▸";
		const cursor = selected ? theme.fg("accent", "❯ ") : "  ";
		const color = tool.isError ? "error" : selected ? "accent" : "toolTitle";
		const duration = formatDuration(tool.durationMs);
		const args = tool.argsPreview ? theme.fg("muted", truncateToWidth(tool.argsPreview, Math.max(8, innerWidth - 22), "…")) : "";
		const status = tool.isError
			? theme.fg("error", tool.resultPreview || "error")
			: theme.fg("dim", tool.resultPreview || "(pending)");
		const header =
			cursor +
			theme.fg(color, `${marker} ${tool.name}`) +
			(args ? ` ${args}` : "") +
			(duration ? theme.fg("dim", `  ${duration}`) : "") +
			`  ${status}`;

		const lines = [indent([header], 2)[0]!];
		if (expanded) {
			const argText = JSON.stringify(tool.args, null, 2);
			lines.push(...indent(renderParagraph(argText, innerWidth - 6), 6));
			if (tool.resultText) {
				lines.push(...indent(renderParagraph(tool.resultText, innerWidth - 6), 6));
			}
		}
		return lines;
	}

	private renderMarkdown(text: string, width: number): string[] {
		if (!text) return [this.theme.fg("muted", "(空)")];
		try {
			return new Markdown(text, 0, 0, this.mdTheme).render(Math.max(1, width));
		} catch {
			return renderParagraph(text, width);
		}
	}

	private decorateLine(bodyIndex: number, line: string): string {
		if (this.matchLines.length === 0) return line;
		if (this.matchLines.indexOf(bodyIndex) === -1) return line;
		return this.theme.style(line, { bg: "searchMatchBg" });
	}

	private recomputeMatches(): void {
		const query = this.search.getValue().trim().toLowerCase();
		this.matchLines = [];
		if (!query) {
			this.matchCursor = -1;
			return;
		}
		for (let i = 0; i < this.body.length; i++) {
			const plain = stripAnsi(this.body[i]!).toLowerCase();
			if (plain.includes(query)) this.matchLines.push(i);
		}
		// Preserve the active match across re-renders; only clamp when it is gone.
		if (this.matchLines.length === 0) this.matchCursor = -1;
		else if (this.matchCursor >= this.matchLines.length) this.matchCursor = this.matchLines.length - 1;
	}

	private jumpMatch(direction: number, firstMatch = false): void {
		if (this.matchLines.length === 0) return;
		if (firstMatch || this.matchCursor === -1) {
			this.matchCursor = direction > 0 ? 0 : this.matchLines.length - 1;
		} else {
			this.matchCursor = (this.matchCursor + direction + this.matchLines.length) % this.matchLines.length;
		}
		const target = this.matchLines[this.matchCursor]!;
		this.offset = Math.max(0, Math.min(target - Math.floor(this.bodyRows / 2), this.maxOffset()));
		this.tui.requestRender();
	}

	private toolsInTurn(): ToolBlock[] {
		return this.turns[this.index]!.blocks.filter((block): block is ToolBlock => block.type === "tool");
	}

	private moveTool(delta: number): void {
		const tools = this.toolsInTurn();
		if (tools.length === 0) {
			// No tools in this turn: keep arrow keys useful as plain scrolling.
			this.scrollBy(delta);
			return;
		}
		this.selectedTool = (this.selectedTool + delta + tools.length) % tools.length;
		this.ensureToolVisible();
		this.tui.requestRender();
	}

	private ensureToolVisible(): void {
		const tool = this.toolsInTurn()[this.selectedTool];
		if (!tool) return;
		const line = this.toolLineIndex.get(tool.callId);
		if (line === undefined) return;
		if (line < this.offset) this.offset = line;
		else if (line >= this.offset + this.bodyRows) this.offset = Math.min(line - this.bodyRows + 1, this.maxOffset());
	}

	private toggleSelectedTool(): void {
		const tool = this.toolsInTurn()[this.selectedTool];
		if (!tool) return;
		if (this.expanded.has(tool.callId)) this.expanded.delete(tool.callId);
		else this.expanded.add(tool.callId);
		this.invalidate();
		this.tui.requestRender();
	}

	private toggleAllTools(): void {
		const tools = this.toolsInTurn();
		const anyCollapsed = tools.some((tool) => !this.expanded.has(tool.callId));
		for (const tool of tools) {
			if (anyCollapsed) this.expanded.add(tool.callId);
			else this.expanded.delete(tool.callId);
		}
		this.invalidate();
		this.tui.requestRender();
	}

	private maxOffset(): number {
		return Math.max(0, this.body.length - this.bodyRows);
	}

	private halfPage(): number {
		return Math.max(1, Math.floor(this.bodyRows / 2));
	}

	private scrollBy(delta: number): void {
		const next = Math.max(0, Math.min(this.offset + delta, this.maxOffset()));
		if (next === this.offset) return;
		this.offset = next;
		this.tui.requestRender();
	}

	private move(delta: number): void {
		const next = this.index + delta;
		if (next < 0 || next >= this.turns.length) return;
		this.index = next;
		this.offset = 0;
		this.selectedTool = 0;
		this.expanded.clear();
		this.invalidate();
		this.tui.requestRender();
	}

	private snapshot(): HistoryViewState {
		const tool = this.toolsInTurn()[this.selectedTool];
		return {
			turnPosition: this.turns[this.index]!.position,
			toolCallId: tool?.callId,
			offset: this.offset,
		};
	}
}

function clampStart(selected: number, total: number, visible: number): number {
	return Math.max(0, Math.min(selected - Math.floor(visible / 2), total - visible));
}

function indent(lines: string[], spaces: number): string[] {
	const prefix = " ".repeat(Math.max(0, spaces));
	return lines.map((line) => prefix + line);
}

/** Wrap plain text to the visible width, preserving existing newlines. */
function renderParagraph(text: string, width: number): string[] {
	if (!text) return [];
	const safeWidth = Math.max(1, width);
	const out: string[] = [];
	for (const raw of text.split("\n")) {
		if (raw.length === 0) {
			out.push("");
			continue;
		}
		out.push(...wrapTextWithAnsi(raw, safeWidth));
	}
	return out;
}

const ANSI_PATTERN = /\x1b\[[0-9;]*m/g;

function stripAnsi(text: string): string {
	return text.replace(ANSI_PATTERN, "");
}
