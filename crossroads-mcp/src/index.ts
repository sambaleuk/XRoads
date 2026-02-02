#!/usr/bin/env node
/**
 * CrossRoads MCP Server
 * Minimal MCP server for streaming logs and status updates from AI agents.
 *
 * Tools:
 * - emit_log: Log an entry with level, source, worktree, message
 * - update_status: Update agent status for a worktree
 * - get_state: Get current state (agents, logs, worktrees)
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";

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

function generateLogId(): string {
  return `log_${Date.now()}_${++logIdCounter}`;
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
];

// ============================================================================
// Tool Handlers
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
// Server Setup
// ============================================================================

const server = new Server(
  {
    name: "crossroads-mcp",
    version: "1.0.0",
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

    default:
      throw new Error(`Unknown tool: ${name}`);
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
