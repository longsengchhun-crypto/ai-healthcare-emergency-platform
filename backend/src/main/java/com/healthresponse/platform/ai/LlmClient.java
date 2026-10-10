package com.healthresponse.platform.ai;

/**
 * Provider boundary for a hosted language model. Implementations must never log prompt or response text.
 * Production uses {@link AnthropicLlmClient}; tests supply a fake so no paid API call is ever needed.
 */
public interface LlmClient {
    /** Binary document (PDF or image) sent alongside the text prompt. */
    record Attachment(String mediaType, byte[] bytes) {}

    record Request(String system, String userText, Attachment attachment, int maxTokens) {
        public Request(String system, String userText, int maxTokens) { this(system, userText, null, maxTokens); }
    }

    /** Returns the model's text output, or throws {@link LlmException}. Never returns a fabricated result. */
    String complete(Request request) throws LlmException;

    class LlmException extends RuntimeException {
        public enum Kind { NOT_CONFIGURED, AUTH, RATE_LIMITED, LOCAL_LIMIT, TIMEOUT, UNAVAILABLE, BAD_OUTPUT, CIRCUIT_OPEN }

        private final Kind kind;

        public LlmException(Kind kind, String message) {
            super(message);
            this.kind = kind;
        }

        public Kind kind() { return kind; }

        /** True when retrying the same request later could succeed (used to choose 429/503 vs. fallback wording). */
        public boolean throttled() { return kind == Kind.RATE_LIMITED || kind == Kind.LOCAL_LIMIT; }
    }
}
