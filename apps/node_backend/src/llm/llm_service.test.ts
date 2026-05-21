import { afterEach, describe, expect, it, vi } from "vitest";

import { resolveRuntimeConfigForTest } from "./llm_service.js";
import { getApiConfigs } from "../services/configService.js";

vi.mock("../services/configService.js", () => ({
  getApiConfigs: vi.fn(),
}));

const getApiConfigsMock = vi.mocked(getApiConfigs);
const originalEnv = { ...process.env };

function resetEnv() {
  process.env = { ...originalEnv };
  delete process.env.LOCAL_LLM_CONFIG_ENABLED;
  delete process.env.LOCAL_LLM_PROVIDER;
  delete process.env.LOCAL_LLM_ENDPOINT;
  delete process.env.LOCAL_LLM_API_KEY;
  delete process.env.LOCAL_LLM_MODEL;
  delete process.env.BRICKS_ENV;
  delete process.env.BRICKS_LOCAL_DEV;
  delete process.env.VERCEL_ENV;
  delete process.env.GEMINI_API_KEY;
  delete process.env.GEMINI_MODEL;
  delete process.env.GEMINI_ENDPOINT;
  delete process.env.ANTHROPIC_API_KEY;
}

describe("resolveRuntimeConfigForTest", () => {
  afterEach(() => {
    vi.clearAllMocks();
    resetEnv();
  });

  it("uses database configs when local env config is not enabled", async () => {
    getApiConfigsMock.mockResolvedValueOnce([
      {
        id: "cfg-1",
        provider: "google_ai_studio",
        is_default: true,
        config: {
          endpoint: "https://generativelanguage.googleapis.com",
          api_key: "db-key",
          model_preferences: { default_model: "gemini-flash-latest" },
        },
      },
    ] as any);

    const resolved = await resolveRuntimeConfigForTest("user-1");

    expect(resolved).toEqual({
      provider: "google_ai_studio",
      baseUrl: "https://generativelanguage.googleapis.com",
      apiKey: "db-key",
      defaultModel: "gemini-flash-latest",
    });
    expect(getApiConfigsMock).toHaveBeenCalledWith("user-1", "llm");
  });

  it("uses enabled Gemini env config without reading database configs", async () => {
    process.env.NODE_ENV = "development";
    process.env.LOCAL_LLM_CONFIG_ENABLED = "true";
    process.env.GEMINI_API_KEY = "AIza-local-test-key";
    process.env.GEMINI_MODEL = "gemini-flash-latest";

    const resolved = await resolveRuntimeConfigForTest("user-1");

    expect(resolved).toEqual({
      provider: "google_ai_studio",
      baseUrl: "https://generativelanguage.googleapis.com",
      apiKey: "AIza-local-test-key",
      defaultModel: "gemini-flash-latest",
    });
    expect(getApiConfigsMock).not.toHaveBeenCalled();
  });

  it("falls back to database config when enabled local provider does not match preferred provider", async () => {
    process.env.NODE_ENV = "development";
    process.env.LOCAL_LLM_CONFIG_ENABLED = "true";
    process.env.GEMINI_API_KEY = "AIza-local-test-key";
    process.env.GEMINI_MODEL = "gemini-flash-latest";
    getApiConfigsMock.mockResolvedValueOnce([
      {
        id: "cfg-1",
        provider: "anthropic",
        is_default: true,
        config: {
          endpoint: "https://api.anthropic.com",
          api_key: "anthropic-db-key",
          model_preferences: { default_model: "claude-sonnet-4-5" },
        },
      },
    ] as any);

    const resolved = await resolveRuntimeConfigForTest("user-1", "anthropic");

    expect(resolved.provider).toBe("anthropic");
    expect(resolved.apiKey).toBe("anthropic-db-key");
    expect(getApiConfigsMock).toHaveBeenCalledWith("user-1", "llm");
  });

  it("rejects invalid local env endpoints", async () => {
    process.env.NODE_ENV = "development";
    process.env.LOCAL_LLM_CONFIG_ENABLED = "true";
    process.env.GEMINI_API_KEY = "AIza-local-test-key";
    process.env.GEMINI_ENDPOINT = "https://example.com";

    await expect(resolveRuntimeConfigForTest("user-1")).rejects.toThrow(
      "Endpoint host 'example.com' is not allowed",
    );
    expect(getApiConfigsMock).not.toHaveBeenCalled();
  });

  it("ignores local env config in production even when enabled", async () => {
    process.env.NODE_ENV = "production";
    process.env.LOCAL_LLM_CONFIG_ENABLED = "true";
    process.env.GEMINI_API_KEY = "AIza-local-test-key";
    getApiConfigsMock.mockResolvedValueOnce([
      {
        id: "cfg-1",
        provider: "google_ai_studio",
        is_default: true,
        config: {
          endpoint: "https://generativelanguage.googleapis.com",
          api_key: "db-key",
          model_preferences: { default_model: "gemini-flash-latest" },
        },
      },
    ] as any);

    const resolved = await resolveRuntimeConfigForTest("user-1");

    expect(resolved.apiKey).toBe("db-key");
    expect(getApiConfigsMock).toHaveBeenCalledWith("user-1", "llm");
  });

  it("allows local env config when BRICKS_LOCAL_DEV is explicit and NODE_ENV is unset", async () => {
    delete process.env.NODE_ENV;
    process.env.BRICKS_LOCAL_DEV = "true";
    process.env.LOCAL_LLM_CONFIG_ENABLED = "true";
    process.env.GEMINI_API_KEY = "AIza-local-test-key";

    const resolved = await resolveRuntimeConfigForTest("user-1");

    expect(resolved.apiKey).toBe("AIza-local-test-key");
    expect(getApiConfigsMock).not.toHaveBeenCalled();
  });
});
