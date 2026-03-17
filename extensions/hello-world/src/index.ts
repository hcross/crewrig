#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
} from "@modelcontextprotocol/sdk/types.js";

const server = new Server(
  { name: "hello-world", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "greet",
      description: "Produce a greeting for the given name",
      inputSchema: {
        type: "object" as const,
        properties: {
          name: { type: "string", description: "Who to greet" },
        },
        required: ["name"],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name !== "greet") {
    throw new McpError(ErrorCode.MethodNotFound, `No such tool: ${request.params.name}`);
  }

  const who = String(request.params.arguments?.name ?? "World");
  return {
    content: [{ type: "text", text: `Hello, ${who}! Sent from the hello-world extension.` }],
  };
});

const transport = new StdioServerTransport();
server.connect(transport).catch((err) => {
  console.error("Failed to start hello-world MCP server:", err);
  process.exit(1);
});
