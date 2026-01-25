/**
 * Hindsight MCP Server Types
 * Type definitions for the Hindsight API and MCP integration
 */

// Hindsight API Response Types
export interface RetainResponse {
  status: "success" | "error";
  memory_id?: string;
  operation_id?: string;
  error?: string;
  detail?: string;
}

export interface RecallResult {
  id: string;
  text: string;
  type: "world" | "experience" | "mental_model";
  entities: string[];
  mentioned_at: string;
  document_id?: string;
  metadata?: Record<string, any>;
  relevance_score?: number;
}

export interface RecallResponse {
  results: RecallResult[];
  trace?: {
    retrieval_strategy?: string;
    num_results?: number;
    processing_time_ms?: number;
  };
  usage?: {
    input_tokens: number;
    output_tokens: number;
  };
}

export interface ReflectResponse {
  text: string;
  based_on?: {
    facts?: RecallResult[];
    mental_models?: any[];
  };
  structured_output?: Record<string, any>;
  usage?: {
    input_tokens: number;
    output_tokens: number;
  };
}

export interface MemoryBank {
  bank_id: string;
  name: string;
  mission?: string;
  disposition: {
    skepticism: number;  // 1-5
    literalism: number;   // 1-5
    empathy: number;      // 1-5
  };
}

export interface ListBanksResponse {
  banks: MemoryBank[];
}

export interface CreateBankResponse extends MemoryBank {}

// MCP Tool Input Types
export interface RetainInput {
  content: string;
  context?: string;
  timestamp?: string;
  bank_id?: string;
  metadata?: Record<string, string>;
  tags?: string[];
}

export interface RecallInput {
  query: string;
  max_tokens?: number;
  bank_id?: string;
  types?: ("world" | "experience" | "mental_model")[];
  budget?: "LOW" | "MID" | "HIGH";
  query_timestamp?: string;
  tags?: string[];
}

export interface ReflectInput {
  query: string;
  context?: string;
  budget?: "low" | "mid" | "high";
  bank_id?: string;
  max_tokens?: number;
  response_schema?: Record<string, any>;
  tags?: string[];
}

export interface CreateBankInput {
  bank_id: string;
  name?: string;
  mission?: string;
  disposition?: {
    skepticism?: number;
    literalism?: number;
    empathy?: number;
  };
}

// Configuration Types
export interface HindsightConfig {
  baseUrl: string;
  defaultBankId: string;
  apiKey?: string;
  timeout?: number;
}

// Automation Types
export interface AutoRetentionRule {
  id: string;
  name: string;
  enabled: boolean;
  trigger: "file_write" | "bash_execution" | "git_commit" | "error_occurred" | "manual";
  condition?: (event: AutoRetentionEvent) => boolean;
  transform?: (event: AutoRetentionEvent) => string;
  context?: string;
  tags?: string[];
}

export interface AutoRetentionEvent {
  type: "file_write" | "bash_execution" | "git_commit" | "error_occurred" | "custom";
  timestamp: string;
  data: {
    file_path?: string;
    command?: string;
    commit_message?: string;
    error_message?: string;
    tool?: string;
    result?: any;
  };
  metadata?: Record<string, any>;
}

// Statistics Types
export interface MemoryStatistics {
  total_memories: number;
  world_facts: number;
  experiences: number;
  opinions: number;
  total_links: number;
  total_entities: number;
  last_updated: string;
}
