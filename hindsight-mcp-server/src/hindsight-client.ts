/**
 * Hindsight HTTP API Client
 * Wraps the Hindsight HTTP API for use in the MCP server
 */

import axios, { AxiosInstance, AxiosError } from 'axios';
import type {
  HindsightConfig,
  RetainInput,
  RetainResponse,
  RecallInput,
  RecallResponse,
  ReflectInput,
  ReflectResponse,
  ListBanksResponse,
  CreateBankInput,
  CreateBankResponse,
  MemoryStatistics
} from './types.js';

export class HindsightClient {
  private client: AxiosInstance;
  private defaultBankId: string;

  constructor(config: HindsightConfig) {
    this.defaultBankId = config.defaultBankId;

    this.client = axios.create({
      baseURL: config.baseUrl,
      timeout: config.timeout || 30000,
      headers: {
        'Content-Type': 'application/json',
        ...(config.apiKey && { 'Authorization': `Bearer ${config.apiKey}` })
      }
    });

    // Add request logging
    this.client.interceptors.request.use(request => {
      console.error(`[Hindsight] ${request.method?.toUpperCase()} ${request.url}`);
      return request;
    });

    // Add response/error logging
    this.client.interceptors.response.use(
      response => {
        console.error(`[Hindsight] ✓ ${response.status} ${response.config.url}`);
        return response;
      },
      (error: AxiosError) => {
        console.error(`[Hindsight] ✗ ${error.response?.status || 'ERROR'} ${error.config?.url}`, error.message);
        throw error;
      }
    );
  }

  /**
   * Store a memory in Hindsight
   */
  async retain(input: RetainInput): Promise<RetainResponse> {
    const bankId = input.bank_id || this.defaultBankId;

    try {
      const response = await this.client.post<RetainResponse>(
        `/v1/default/banks/${bankId}/memories/retain`,
        {
          content: input.content,
          context: input.context || 'general',
          timestamp: input.timestamp || new Date().toISOString(),
          metadata: input.metadata || {},
          tags: input.tags || []
        }
      );

      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        return {
          status: 'error',
          error: error.code || 'UNKNOWN_ERROR',
          detail: error.response?.data?.detail || error.message
        };
      }
      throw error;
    }
  }

  /**
   * Search memories using multi-strategy retrieval
   */
  async recall(input: RecallInput): Promise<RecallResponse> {
    const bankId = input.bank_id || this.defaultBankId;

    try {
      const response = await this.client.post<RecallResponse>(
        `/v1/default/banks/${bankId}/memories/recall`,
        {
          query: input.query,
          max_tokens: input.max_tokens || 4096,
          types: input.types,
          budget: input.budget || 'MID',
          query_timestamp: input.query_timestamp,
          tags: input.tags || [],
          trace: true  // Enable tracing for debugging
        }
      );

      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(`Recall failed: ${error.response?.data?.detail || error.message}`);
      }
      throw error;
    }
  }

  /**
   * Generate insights by combining memories with reasoning
   */
  async reflect(input: ReflectInput): Promise<ReflectResponse> {
    const bankId = input.bank_id || this.defaultBankId;

    try {
      const response = await this.client.post<ReflectResponse>(
        `/v1/default/banks/${bankId}/reflect`,
        {
          query: input.query,
          context: input.context,
          budget: input.budget || 'mid',
          max_tokens: input.max_tokens || 2048,
          response_schema: input.response_schema,
          tags: input.tags || []
        }
      );

      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(`Reflect failed: ${error.response?.data?.detail || error.message}`);
      }
      throw error;
    }
  }

  /**
   * List all available memory banks
   */
  async listBanks(): Promise<ListBanksResponse> {
    try {
      const response = await this.client.get<ListBanksResponse>('/v1/default/banks');
      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(`List banks failed: ${error.response?.data?.detail || error.message}`);
      }
      throw error;
    }
  }

  /**
   * Create a new memory bank or get existing one
   */
  async createBank(input: CreateBankInput): Promise<CreateBankResponse> {
    try {
      const response = await this.client.post<CreateBankResponse>('/v1/default/banks', {
        bank_id: input.bank_id,
        name: input.name || input.bank_id,
        mission: input.mission || '',
        disposition: {
          skepticism: input.disposition?.skepticism || 3,
          literalism: input.disposition?.literalism || 3,
          empathy: input.disposition?.empathy || 3
        }
      });

      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        // If bank already exists, fetch it
        if (error.response?.status === 409 || error.response?.status === 400) {
          return this.getBank(input.bank_id);
        }
        throw new Error(`Create bank failed: ${error.response?.data?.detail || error.message}`);
      }
      throw error;
    }
  }

  /**
   * Get memory bank details
   */
  async getBank(bankId: string): Promise<CreateBankResponse> {
    try {
      const response = await this.client.get<CreateBankResponse>(
        `/v1/default/banks/${bankId}`
      );
      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(`Get bank failed: ${error.response?.data?.detail || error.message}`);
      }
      throw error;
    }
  }

  /**
   * Get memory statistics for a bank
   */
  async getStatistics(bankId?: string): Promise<MemoryStatistics> {
    const targetBank = bankId || this.defaultBankId;

    try {
      const response = await this.client.get(`/v1/default/banks/${targetBank}/stats`);
      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(`Get stats failed: ${error.response?.data?.detail || error.message}`);
      }
      throw error;
    }
  }

  /**
   * Health check
   */
  async healthCheck(): Promise<{ status: string; database: string }> {
    try {
      const response = await this.client.get('/health');
      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        return {
          status: 'unhealthy',
          database: 'disconnected'
        };
      }
      throw error;
    }
  }
}
