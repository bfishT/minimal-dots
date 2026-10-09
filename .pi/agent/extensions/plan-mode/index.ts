/**
 * Enhanced Plan Mode
 *
 * Read-only exploration with structured user clarification:
 * - /plan toggles read-only planning mode
 * - The questionnaire tool lets the model ask several option-based questions
 *   with a free-form "Type something" answer
 * - The user approves, refines, or continues questioning before execution
 * - plan_update tracks execution progress with structured tool calls
 * - State is persisted in the pi session and restored on resume/tree branches
 */

import type { AgentMessage } from "@earendil-works/pi-agent-core";
import type { AssistantMessage, TextContent } from "@earendil-works/pi-ai";
import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { extractTodoItems, isSafeCommand, markCompletedSteps, type TodoItem, type TodoStatus } from "./utils.ts";

const PLAN_MODE_TOOLS = ["read", "bash", "grep", "find", "ls", "questionnaire"];
const NORMAL_MODE_TOOLS = ["read", "bash", "edit", "write", "grep", "find", "ls"];
const PLAN_MODE_DISABLED_TOOLS = new Set(["edit", "write", "plan_update"]);
const PLAN_MANAGED_TOOLS = new Set([
	...PLAN_MODE_TOOLS,
	...NORMAL_MODE_TOOLS,
	"plan_update",
]);

type PlanPhase = "idle" | "planning" | "awaiting-approval" | "executing" | "completed" | "cancelled";

interface PlanAnswer {
	id: string;
	value: string;
	label: string;
	wasCustom: boolean;
	index?: number;
}

interface PlanModeState {
	enabled: boolean;
	todos: TodoItem[];
	executing: boolean;
	toolsBeforePlanMode?: string[];
	phase?: PlanPhase;
	planId?: string;
	answers?: PlanAnswer[];
	questionsAsked?: number;
}

interface QuestionnaireResultLike {
	answers?: PlanAnswer[];
	cancelled?: boolean;
}

function isAssistantMessage(message: AgentMessage): message is AssistantMessage {
	return message.role === "assistant" && Array.isArray(message.content);
}

function getTextContent(message: AssistantMessage): string {
	return message.content
		.filter((block): block is TextContent => block.type === "text")
		.map((block) => block.text)
		.join("\n");
}

function uniqueToolNames(toolNames: string[]): string[] {
	return [...new Set(toolNames)];
}

export default function planModeExtension(pi: ExtensionAPI): void {
	let planModeEnabled = false;
	let executionMode = false;
	let planPhase: PlanPhase = "idle";
	let planId: string | undefined;
	let todoItems: TodoItem[] = [];
	let planAnswers: PlanAnswer[] = [];
	let questionsAsked = 0;
	let toolsBeforePlanMode: string[] | undefined;

	pi.registerFlag("plan", {
		description: "Start in plan mode (read-only exploration)",
		type: "boolean",
		default: false,
	});

	function updateStatus(ctx: ExtensionContext): void {
		if (todoItems.length > 0 && (executionMode || planPhase === "completed")) {
			const completed = todoItems.filter((todo) => todo.completed).length;
			const status = planPhase === "completed" ? `✓ ${completed}/${todoItems.length}` : `📋 ${completed}/${todoItems.length}`;
			ctx.ui.setStatus("plan-mode", ctx.ui.theme.fg(planPhase === "completed" ? "success" : "accent", status));
		} else if (planModeEnabled) {
			const suffix = planPhase === "awaiting-approval" ? " • ready" : "";
			ctx.ui.setStatus("plan-mode", ctx.ui.theme.fg("warning", `⏸ plan${suffix}`));
		} else {
			ctx.ui.setStatus("plan-mode", undefined);
		}

		if (todoItems.length > 0 && (executionMode || planPhase === "completed")) {
			const lines = todoItems.map((todo) => {
				if (todo.completed || todo.status === "completed") {
					return ctx.ui.theme.fg("success", "☑ ") + ctx.ui.theme.fg("muted", ctx.ui.theme.strikethrough(todo.text));
				}
				if (todo.status === "in_progress") {
					return ctx.ui.theme.fg("accent", "▶ ") + todo.text;
				}
				if (todo.status === "blocked") {
					return ctx.ui.theme.fg("error", "! ") + todo.text;
				}
				return `${ctx.ui.theme.fg("muted", "☐ ")}${todo.text}`;
			});
			ctx.ui.setWidget("plan-todos", lines);
		} else {
			ctx.ui.setWidget("plan-todos", undefined);
		}
	}

	function getPlanModeTools(activeToolNames: string[]): string[] {
		return uniqueToolNames([
			...activeToolNames.filter((name) => !PLAN_MODE_DISABLED_TOOLS.has(name)),
			...PLAN_MODE_TOOLS,
		]);
	}

	function getNormalModeTools(activeToolNames: string[]): string[] {
		return uniqueToolNames([
			...NORMAL_MODE_TOOLS,
			...activeToolNames.filter((name) => !PLAN_MANAGED_TOOLS.has(name)),
		]);
	}

	function enablePlanModeTools(): void {
		if (toolsBeforePlanMode === undefined) {
			toolsBeforePlanMode = pi.getActiveTools();
		}
		pi.setActiveTools(getPlanModeTools(toolsBeforePlanMode));
	}

	function restoreNormalModeTools(): void {
		pi.setActiveTools(toolsBeforePlanMode ?? getNormalModeTools(pi.getActiveTools()));
		toolsBeforePlanMode = undefined;
	}

	function enableExecutionTools(): void {
		restoreNormalModeTools();
		pi.setActiveTools(uniqueToolNames([...pi.getActiveTools(), "plan_update"]));
	}

	function persistState(): void {
		pi.appendEntry<PlanModeState>("plan-mode", {
			enabled: planModeEnabled,
			todos: todoItems,
			executing: executionMode,
			toolsBeforePlanMode,
			phase: planPhase,
			planId,
			answers: planAnswers,
			questionsAsked,
		});
	}

	function resetPlan(): void {
		planId = `plan-${Date.now().toString(36)}`;
		todoItems = [];
		planAnswers = [];
		questionsAsked = 0;
		planPhase = "planning";
	}

	function togglePlanMode(ctx: ExtensionContext): void {
		if (executionMode) {
			ctx.ui.notify("计划正在执行中，请等待完成后再切换模式。", "warning");
			return;
		}

		planModeEnabled = !planModeEnabled;
		if (planModeEnabled) {
			resetPlan();
			enablePlanModeTools();
			ctx.ui.notify("Plan Mode 已开启：写文件工具和危险命令已禁用。", "info");
		} else {
			restoreNormalModeTools();
			planPhase = "idle";
			ctx.ui.notify("Plan Mode 已关闭：已恢复完整工具权限。", "info");
		}
		updateStatus(ctx);
		persistState();
	}

	function beginExecution(ctx: ExtensionContext): void {
		if (todoItems.length === 0) {
			ctx.ui.notify("还没有可执行的计划，请先生成 Plan。", "warning");
			return;
		}
		if (executionMode) return;

		planModeEnabled = false;
		executionMode = true;
		planPhase = "executing";
		enableExecutionTools();
		updateStatus(ctx);
		persistState();

		const remaining = todoItems
			.filter((todo) => !todo.completed)
			.map((todo) => `${todo.step}. ${todo.text}`)
			.join("\n");
		const first = todoItems.find((todo) => !todo.completed);
		const kickoff = `执行计划。

剩余步骤：
${remaining}

从第 ${first?.step ?? 1} 步开始：${first?.text ?? "继续计划"}
完成或阻塞每一步后，必须调用 plan_update 工具更新状态。`;

		pi.sendMessage(
			{
				customType: "plan-todo-list",
				content: `**开始执行计划**\n\n${todoItems.map((todo) => `${todo.step}. ☐ ${todo.text}`).join("\n")}`,
				display: true,
			},
			{ deliverAs: "followUp" },
		);
		pi.sendUserMessage(kickoff, { deliverAs: "followUp" });
	}

	function requestMoreQuestions(): void {
		planPhase = "planning";
		persistState();
		pi.sendUserMessage(
			"请重新检查当前需求和计划。如果仍存在会影响实现的重要不确定性，请调用 questionnaire 工具继续询问我；如果信息已经足够，请直接完善 Plan。不要修改文件。",
			{ deliverAs: "followUp" },
		);
	}

	async function refinePlan(ctx: ExtensionContext): Promise<void> {
		const instruction = await ctx.ui.editor("请输入对计划的修改意见：", "");
		if (!instruction?.trim()) return;
		planPhase = "planning";
		persistState();
		pi.sendUserMessage(instruction.trim(), { deliverAs: "followUp" });
	}

	pi.registerCommand("plan", {
		description: "Toggle read-only plan mode; use /plan ask or /plan execute",
		handler: async (args, ctx) => {
			const command = args.trim().toLowerCase();
			if (command === "ask") {
				if (!planModeEnabled) {
					ctx.ui.notify("请先使用 /plan 进入计划模式。", "warning");
					return;
				}
				requestMoreQuestions();
				return;
			}
			if (command === "execute") {
				beginExecution(ctx);
				return;
			}
			togglePlanMode(ctx);
		},
	});

	pi.registerCommand("todos", {
		description: "Show current plan progress",
		handler: async (_args, ctx) => {
			if (todoItems.length === 0) {
				ctx.ui.notify("当前没有计划。请先使用 /plan。", "info");
				return;
			}
			const list = todoItems
				.map((todo) => `${todo.step}. ${todo.completed ? "✓" : todo.status === "blocked" ? "!" : todo.status === "in_progress" ? "▶" : "○"} ${todo.text}`)
				.join("\n");
			ctx.ui.notify(`Plan Progress:\n${list}`, "info");
		},
	});

	pi.registerShortcut("ctrl+shift+p", {
		description: "Toggle plan mode",
		handler: async (ctx) => togglePlanMode(ctx),
	});

	// Structured progress updates are more reliable than parsing [DONE:n] markers alone.
	pi.registerTool({
		name: "plan_update",
		label: "Update Plan",
		description: "Update the status of one step in the current execution plan.",
		promptSnippet: "Update plan step progress after completing or blocking a step",
		promptGuidelines: [
			"Use plan_update after each execution step to mark it in_progress, completed, or blocked.",
			"Do not claim a plan step is completed without first performing and checking the work.",
		],
		parameters: Type.Object({
			step: Type.Integer({ minimum: 1, description: "The 1-based plan step number" }),
			status: StringEnum(["in_progress", "completed", "blocked"] as const),
			note: Type.Optional(Type.String({ description: "Short progress note or blocking reason" })),
		}),
		executionMode: "sequential",
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			if (!executionMode) {
				throw new Error("plan_update is only available while executing a plan");
			}

			const todo = todoItems.find((item) => item.step === params.step);
			if (!todo) {
				throw new Error(`Unknown plan step: ${params.step}`);
			}

			const status = params.status as TodoStatus;
			todo.status = status;
			todo.completed = status === "completed";
			persistState();
			updateStatus(ctx);

			return {
				content: [{ type: "text", text: `Plan step ${params.step} is now ${status}${params.note ? `: ${params.note}` : ""}` }],
				details: { step: params.step, status, note: params.note },
			};
		},
		renderCall(args, theme) {
			return new Text(theme.fg("toolTitle", theme.bold("plan_update ")) + theme.fg("muted", `step ${args.step} → ${args.status}`), 0, 0);
		},
		renderResult(result, _options, theme) {
			const text = result.content[0];
			return new Text(theme.fg("success", "✓ ") + (text?.type === "text" ? text.text : "Plan updated"), 0, 0);
		},
	});

	// Block destructive bash commands in plan mode.
	pi.on("tool_call", async (event) => {
		if (!planModeEnabled || event.toolName !== "bash") return;

		const command = String(event.input.command ?? "");
		if (!isSafeCommand(command)) {
			return {
				block: true,
				reason: `Plan Mode 只允许只读命令，已阻止：${command}`,
			};
		}
	});

	// Record answers so /resume and the plan widget know that clarification happened.
	pi.on("tool_result", async (event) => {
		if (event.toolName !== "questionnaire" || !planModeEnabled || executionMode) return;

		const details = event.details as QuestionnaireResultLike | undefined;
		if (!details) return;
		if (details.cancelled) {
			planPhase = "planning";
			persistState();
			return;
		}

		if (details.answers?.length) {
			const byId = new Map(planAnswers.map((answer) => [answer.id, answer]));
			for (const answer of details.answers) byId.set(answer.id, answer);
			planAnswers = [...byId.values()];
			questionsAsked += 1;
			planPhase = "planning";
			persistState();
		}
	});

	// Remove stale internal instructions after leaving a mode.
	pi.on("context", async (event) => {
		return {
			messages: event.messages.filter((message) => {
				const candidate = message as AgentMessage & { customType?: string };
				if (candidate.customType === "plan-mode-context") return planModeEnabled && !executionMode;
				if (candidate.customType === "plan-execution-context") return executionMode;
				return true;
			}),
		};
	});

	pi.on("before_agent_start", async () => {
		if (executionMode && todoItems.length > 0) {
			const remaining = todoItems
				.filter((todo) => !todo.completed)
				.map((todo) => `${todo.step}. ${todo.text}`)
				.join("\n");
			return {
				message: {
					customType: "plan-execution-context",
					content: `[PLAN EXECUTION]\n\n剩余步骤：\n${remaining}\n\n请按顺序执行。每完成或阻塞一步，必须调用 plan_update 工具。`,
					display: false,
				},
			};
		}

		if (planModeEnabled) {
			return {
				message: {
					customType: "plan-mode-context",
					content: `[PLAN MODE]\n\n当前处于只读计划模式：\n- 不要修改文件。\n- 不要运行有副作用的命令。\n- 可以读取、搜索和分析项目。\n- 只有当信息不足且会影响方案时，才调用 questionnaire 工具。\n- questionnaire 一次最多询问 3-5 个相关问题，并允许用户自定义回答。\n- 收到答案后，结合答案继续分析。\n- 最终请在 Plan: 标题下输出详细的编号计划。\n\nPlan:\n1. 步骤标题 - 详细说明\n2. 步骤标题 - 详细说明`,
					display: false,
				},
			};
		}
	});

	// Track legacy [DONE:n] markers as a fallback, while plan_update is preferred.
	pi.on("turn_end", async (event, ctx) => {
		if (!executionMode || todoItems.length === 0) return;
		if (!isAssistantMessage(event.message)) return;

		const text = getTextContent(event.message);
		if (markCompletedSteps(text, todoItems) > 0) {
			updateStatus(ctx);
			persistState();
		}
	});

	pi.on("agent_end", async (event, ctx) => {
		if (executionMode && todoItems.length > 0) {
			if (todoItems.every((todo) => todo.completed)) {
				executionMode = false;
				planPhase = "completed";
				pi.sendMessage(
					{
						customType: "plan-complete",
						content: `**Plan Complete!** ✓\n\n${todoItems.map((todo) => `~~${todo.text}~~`).join("\n")}`,
						display: true,
					},
					{ triggerTurn: false },
				);
				updateStatus(ctx);
				persistState();
			}
			return;
		}

		if (!planModeEnabled || !ctx.hasUI) return;

		const lastAssistant = [...event.messages].reverse().find(isAssistantMessage);
		if (!lastAssistant) return;

		const extracted = extractTodoItems(getTextContent(lastAssistant));
		if (extracted.length === 0) return;

		todoItems = extracted;
		planPhase = "awaiting-approval";
		persistState();
		updateStatus(ctx);

		const choice = await ctx.ui.select("计划已生成，下一步做什么？", [
			"执行计划",
			"继续提问",
			"手动修改计划",
			"保持计划模式",
			"取消计划",
		]);

		if (choice === "执行计划") {
			beginExecution(ctx);
		} else if (choice === "继续提问") {
			requestMoreQuestions();
		} else if (choice === "手动修改计划") {
			await refinePlan(ctx);
		} else if (choice === "取消计划") {
			planModeEnabled = false;
			planPhase = "cancelled";
			restoreNormalModeTools();
			updateStatus(ctx);
			persistState();
		}
	});

	pi.on("session_start", async (_event, ctx) => {
		const entries = ctx.sessionManager.getBranch();
		const lastStateEntry = [...entries]
			.reverse()
			.find((entry) => entry.type === "custom" && entry.customType === "plan-mode") as
			| { data?: PlanModeState }
			| undefined;

		if (lastStateEntry?.data) {
			const state = lastStateEntry.data;
			planModeEnabled = state.enabled ?? false;
			executionMode = state.executing ?? false;
			planPhase = state.phase ?? (executionMode ? "executing" : planModeEnabled ? "planning" : "idle");
			planId = state.planId;
			todoItems = state.todos ?? [];
			planAnswers = state.answers ?? [];
			questionsAsked = state.questionsAsked ?? 0;
			toolsBeforePlanMode = state.toolsBeforePlanMode;
		}

		if (pi.getFlag("plan") === true) {
			planModeEnabled = true;
			if (!executionMode && planPhase === "idle") planPhase = "planning";
		}

		// Re-scan assistant messages after execution started for old sessions that
		// used [DONE:n] markers instead of plan_update.
		if (executionMode && todoItems.length > 0) {
			let executeIndex = -1;
			for (let i = entries.length - 1; i >= 0; i--) {
				const entry = entries[i] as { type: string; customType?: string };
				if (entry.type === "custom" && entry.customType === "plan-mode-execute") {
					executeIndex = i;
					break;
				}
			}

			const messages: AssistantMessage[] = [];
			for (let i = executeIndex + 1; i < entries.length; i++) {
				const entry = entries[i];
				if (entry.type === "message" && "message" in entry && isAssistantMessage(entry.message as AgentMessage)) {
					messages.push(entry.message as AssistantMessage);
				}
			}
			markCompletedSteps(messages.map(getTextContent).join("\n"), todoItems);
		}

		if (executionMode) {
			enableExecutionTools();
		} else if (planModeEnabled) {
			enablePlanModeTools();
		}
		updateStatus(ctx);
	});
}
