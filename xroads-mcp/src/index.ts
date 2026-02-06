#!/usr/bin/env node
/**
 * CrossRoads MCP Server
 * MCP server for streaming logs, status updates, and session/handoff management.
 *
 * Tools:
 * - emit_log: Log an entry with level, source, worktree, message
 * - update_status: Update agent status for a worktree
 * - get_state: Get current state (agents, logs, worktrees)
 * - register_session: Register a new agent session for a repo
 * - record_decision: Record a key decision during a session
 * - generate_handoff: Generate compact context handoff for session continuation
 * - get_session: Retrieve the last session for a repo
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import * as fs from "fs";
import * as path from "path";

// ============================================================================
// Types
// ============================================================================

type LogLevel = "debug" | "info" | "warn" | "error";
type AgentStatus = "idle" | "running" | "planning" | "complete" | "error";

interface LogEntry {
  id: string;
  timestamp: string;
  level: LogLevel;
  source: string;
  worktree: string;
  message: string;
  metadata?: Record<string, unknown>;
}

interface AgentState {
  agent: string;
  worktree: string;
  status: AgentStatus;
  task?: string;
  progress?: number;
  updatedAt: string;
}

interface WorktreeInfo {
  path: string;
  agent?: string;
  status: AgentStatus;
}

interface MCPState {
  agents: AgentState[];
  logs: LogEntry[];
  worktrees: WorktreeInfo[];
}

// Session types for context handoff
interface SessionDecision {
  timestamp: string;
  summary: string;
}

interface SessionRecord {
  id: string;
  repoPath: string;
  agentName: string;
  conversationId?: string;
  decisions: SessionDecision[];
  handoff?: string;
  createdAt: string;
  updatedAt: string;
}

// ============================================================================
// In-Memory Storage
// ============================================================================

const MAX_LOGS = 1000;
let logIdCounter = 0;

const state: MCPState = {
  agents: [],
  logs: [],
  worktrees: [],
};

// In-memory session cache (backed by per-repo .crossroads/sessions.json)
const sessionCache: Map<string, SessionRecord> = new Map();

function generateLogId(): string {
  return `log_${Date.now()}_${++logIdCounter}`;
}

function generateSessionId(): string {
  return `session_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

// ============================================================================
// Session File Persistence
// ============================================================================

const CROSSROADS_DIR = ".crossroads";
const SESSIONS_FILE = "sessions.json";

function sessionsFilePath(repoPath: string): string {
  return path.join(repoPath, CROSSROADS_DIR, SESSIONS_FILE);
}

function ensureCrossroadsDir(repoPath: string): void {
  const dir = path.join(repoPath, CROSSROADS_DIR);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function loadSessionsFromDisk(repoPath: string): SessionRecord[] {
  const filePath = sessionsFilePath(repoPath);
  if (!fs.existsSync(filePath)) {
    return [];
  }
  try {
    const data = fs.readFileSync(filePath, "utf-8");
    return JSON.parse(data) as SessionRecord[];
  } catch {
    return [];
  }
}

function saveSessionsToDisk(repoPath: string, sessions: SessionRecord[]): void {
  ensureCrossroadsDir(repoPath);
  const filePath = sessionsFilePath(repoPath);
  fs.writeFileSync(filePath, JSON.stringify(sessions, null, 2), "utf-8");
}

function upsertSessionOnDisk(session: SessionRecord): void {
  const sessions = loadSessionsFromDisk(session.repoPath);
  const index = sessions.findIndex((s) => s.id === session.id);
  if (index >= 0) {
    sessions[index] = session;
  } else {
    sessions.push(session);
  }
  saveSessionsToDisk(session.repoPath, sessions);
}

// ============================================================================
// Tool Definitions
// ============================================================================

const TOOLS: Tool[] = [
  {
    name: "emit_log",
    description: "Emit a log entry from an agent. Logs are stored in memory and can be retrieved via get_state.",
    inputSchema: {
      type: "object" as const,
      properties: {
        level: {
          type: "string",
          enum: ["debug", "info", "warn", "error"],
          description: "Log level",
        },
        source: {
          type: "string",
          description: "Source of the log (e.g., 'claude', 'gemini', 'codex', 'system')",
        },
        worktree: {
          type: "string",
          description: "Worktree path this log is associated with",
        },
        message: {
          type: "string",
          description: "Log message content",
        },
        metadata: {
          type: "object",
          description: "Optional metadata object",
        },
      },
      required: ["level", "source", "worktree", "message"],
    },
  },
  {
    name: "update_status",
    description: "Update the status of an agent working on a worktree.",
    inputSchema: {
      type: "object" as const,
      properties: {
        agent: {
          type: "string",
          description: "Agent identifier (e.g., 'claude', 'gemini', 'codex')",
        },
        worktree: {
          type: "string",
          description: "Worktree path the agent is working on",
        },
        status: {
          type: "string",
          enum: ["idle", "running", "planning", "complete", "error"],
          description: "Current status of the agent",
        },
        task: {
          type: "string",
          description: "Optional current task description",
        },
        progress: {
          type: "number",
          minimum: 0,
          maximum: 100,
          description: "Optional progress percentage (0-100)",
        },
      },
      required: ["agent", "worktree", "status"],
    },
  },
  {
    name: "get_state",
    description: "Get the current state including all agents, recent logs, and worktrees.",
    inputSchema: {
      type: "object" as const,
      properties: {},
      required: [],
    },
  },
  // ---- Session & Handoff Tools ----
  {
    name: "register_session",
    description: "Register a new agent session for a repo. Call this when an agent session starts. Returns a sessionId for subsequent calls.",
    inputSchema: {
      type: "object" as const,
      properties: {
        repoPath: {
          type: "string",
          description: "Absolute path to the git repository",
        },
        agentName: {
          type: "string",
          description: "Name of the agent (e.g., 'claude', 'gemini', 'codex')",
        },
        conversationId: {
          type: "string",
          description: "Optional conversation ID for resume support (Claude Code)",
        },
      },
      required: ["repoPath", "agentName"],
    },
  },
  {
    name: "record_decision",
    description: "Record a key decision made during an agent session. Use this to track important architectural or implementation choices for handoff context.",
    inputSchema: {
      type: "object" as const,
      properties: {
        sessionId: {
          type: "string",
          description: "Session ID from register_session",
        },
        summary: {
          type: "string",
          description: "Brief summary of the decision (1-2 sentences)",
        },
      },
      required: ["sessionId", "summary"],
    },
  },
  {
    name: "generate_handoff",
    description: "Generate a compact context handoff for session continuation. Produces a markdown document with current state, key decisions, solved problems, and next steps. The handoff is stored in the session for later injection.",
    inputSchema: {
      type: "object" as const,
      properties: {
        sessionId: {
          type: "string",
          description: "Session ID from register_session",
        },
        budgetTokens: {
          type: "number",
          description: "Approximate token budget for the handoff (default: 500). Larger budget = more detail.",
          minimum: 100,
          maximum: 2000,
        },
      },
      required: ["sessionId"],
    },
  },
  {
    name: "get_session",
    description: "Retrieve the last session for a repo. Returns the most recent session record with decisions and handoff payload.",
    inputSchema: {
      type: "object" as const,
      properties: {
        repoPath: {
          type: "string",
          description: "Absolute path to the git repository",
        },
      },
      required: ["repoPath"],
    },
  },
];

// ============================================================================
// Tool Handlers — Original
// ============================================================================

function handleEmitLog(args: Record<string, unknown>): { success: boolean; logId: string } {
  const level = args.level as LogLevel;
  const source = args.source as string;
  const worktree = args.worktree as string;
  const message = args.message as string;
  const metadata = args.metadata as Record<string, unknown> | undefined;

  const logEntry: LogEntry = {
    id: generateLogId(),
    timestamp: new Date().toISOString(),
    level,
    source,
    worktree,
    message,
    metadata,
  };

  state.logs.push(logEntry);

  // Trim logs to MAX_LOGS
  if (state.logs.length > MAX_LOGS) {
    state.logs = state.logs.slice(-MAX_LOGS);
  }

  // Update worktree if not exists
  const existingWorktree = state.worktrees.find((w) => w.path === worktree);
  if (!existingWorktree) {
    state.worktrees.push({
      path: worktree,
      agent: source,
      status: "idle",
    });
  }

  return { success: true, logId: logEntry.id };
}

function handleUpdateStatus(args: Record<string, unknown>): { success: boolean; agent: AgentState } {
  const agent = args.agent as string;
  const worktree = args.worktree as string;
  const status = args.status as AgentStatus;
  const task = args.task as string | undefined;
  const progress = args.progress as number | undefined;

  const agentState: AgentState = {
    agent,
    worktree,
    status,
    task,
    progress,
    updatedAt: new Date().toISOString(),
  };

  // Update or add agent state
  const existingIndex = state.agents.findIndex(
    (a) => a.agent === agent && a.worktree === worktree
  );
  if (existingIndex >= 0) {
    state.agents[existingIndex] = agentState;
  } else {
    state.agents.push(agentState);
  }

  // Update worktree status
  const worktreeIndex = state.worktrees.findIndex((w) => w.path === worktree);
  if (worktreeIndex >= 0) {
    state.worktrees[worktreeIndex].status = status;
    state.worktrees[worktreeIndex].agent = agent;
  } else {
    state.worktrees.push({
      path: worktree,
      agent,
      status,
    });
  }

  return { success: true, agent: agentState };
}

function handleGetState(): MCPState {
  return {
    agents: [...state.agents],
    logs: [...state.logs],
    worktrees: [...state.worktrees],
  };
}

// ============================================================================
// Tool Handlers — Session & Handoff
// ============================================================================

function handleRegisterSession(args: Record<string, unknown>): { sessionId: string } {
  const repoPath = args.repoPath as string;
  const agentName = args.agentName as string;
  const conversationId = args.conversationId as string | undefined;

  const now = new Date().toISOString();
  const sessionId = generateSessionId();

  const session: SessionRecord = {
    id: sessionId,
    repoPath,
    agentName,
    conversationId,
    decisions: [],
    createdAt: now,
    updatedAt: now,
  };

  sessionCache.set(sessionId, session);
  upsertSessionOnDisk(session);

  return { sessionId };
}

function handleRecordDecision(args: Record<string, unknown>): { ok: boolean } {
  const sessionId = args.sessionId as string;
  const summary = args.summary as string;

  const session = sessionCache.get(sessionId);
  if (!session) {
    // Try loading from disk by scanning known repos — fall back to error
    throw new Error(`Session not found: ${sessionId}`);
  }

  session.decisions.push({
    timestamp: new Date().toISOString(),
    summary,
  });
  session.updatedAt = new Date().toISOString();

  upsertSessionOnDisk(session);

  return { ok: true };
}

function handleGenerateHandoff(args: Record<string, unknown>): { handoff: string } {
  const sessionId = args.sessionId as string;
  const budgetTokens = (args.budgetTokens as number) || 500;

  const session = sessionCache.get(sessionId);
  if (!session) {
    throw new Error(`Session not found: ${sessionId}`);
  }

  // Build handoff markdown within token budget
  const lines: string[] = [];

  lines.push("## Context Handoff");
  lines.push("");
  lines.push(`**Session:** ${session.id}`);
  lines.push(`**Agent:** ${session.agentName}`);
  lines.push(`**Repo:** ${session.repoPath}`);
  lines.push(`**Started:** ${session.createdAt}`);
  lines.push("");

  // Key decisions (most important for context)
  if (session.decisions.length > 0) {
    lines.push("### Key Decisions");
    lines.push("");

    // Budget: ~4 tokens per word, ~20 words per decision line
    // Reserve ~200 tokens for header/footer, rest for decisions
    const decisionBudget = budgetTokens - 200;
    const maxDecisions = Math.max(3, Math.floor(decisionBudget / 80));

    // Take most recent decisions (they're most relevant)
    const recentDecisions = session.decisions.slice(-maxDecisions);
    for (const decision of recentDecisions) {
      lines.push(`- ${decision.summary}`);
    }
    if (session.decisions.length > maxDecisions) {
      lines.push(`- _(${session.decisions.length - maxDecisions} earlier decisions omitted)_`);
    }
    lines.push("");
  }

  // Current state from agent status
  const agentState = state.agents.find(
    (a) => a.agent === session.agentName
  );
  if (agentState) {
    lines.push("### Current State");
    lines.push("");
    lines.push(`- **Status:** ${agentState.status}`);
    if (agentState.task) {
      lines.push(`- **Working on:** ${agentState.task}`);
    }
    if (agentState.progress !== undefined) {
      lines.push(`- **Progress:** ${agentState.progress}%`);
    }
    lines.push("");
  }

  lines.push("### Next Steps");
  lines.push("");
  lines.push("- Continue from where the previous session left off");
  lines.push("- Review decisions above before making changes");
  lines.push("");
  lines.push(`---`);
  lines.push(`*Generated at ${new Date().toISOString()} by crossroads-mcp*`);

  const handoff = lines.join("\n");

  // Store on session
  session.handoff = handoff;
  session.updatedAt = new Date().toISOString();
  upsertSessionOnDisk(session);

  return { handoff };
}

function handleGetSession(args: Record<string, unknown>): { session: SessionRecord | null } {
  const repoPath = args.repoPath as string;

  // Load from disk to get the most recent
  const sessions = loadSessionsFromDisk(repoPath);
  if (sessions.length === 0) {
    return { session: null };
  }

  // Return the most recently updated session
  const sorted = sessions.sort(
    (a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime()
  );
  const latest = sorted[0];

  // Populate cache
  sessionCache.set(latest.id, latest);

  return { session: latest };
}

// ============================================================================
// Server Setup
// ============================================================================

const server = new Server(
  {
    name: "crossroads-mcp",
    version: "1.1.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: TOOLS };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "emit_log": {
        const result = handleEmitLog(args as Record<string, unknown>);
        return {
          content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        };
      }

      case "update_status": {
        const result = handleUpdateStatus(args as Record<string, unknown>);
        return {
          content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        };
      }

      case "get_state": {
        const result = handleGetState();
        return {
          content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        };
      }

      case "register_session": {
        const result = handleRegisterSession(args as Record<string, unknown>);
        return {
          content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        };
      }

      case "record_decision": {
        const result = handleRecordDecision(args as Record<string, unknown>);
        return {
          content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        };
      }

      case "generate_handoff": {
        const result = handleGenerateHandoff(args as Record<string, unknown>);
        return {
          content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        };
      }

      case "get_session": {
        const result = handleGetSession(args as Record<string, unknown>);
        return {
          content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      content: [{ type: "text", text: JSON.stringify({ error: message }) }],
      isError: true,
    };
  }
});

// ============================================================================
// Main
// ============================================================================

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("CrossRoads MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
