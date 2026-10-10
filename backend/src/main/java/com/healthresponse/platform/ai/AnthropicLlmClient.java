package com.healthresponse.platform.ai;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.errors.AnthropicIoException;
import com.anthropic.errors.AnthropicServiceException;
import com.anthropic.errors.PermissionDeniedException;
import com.anthropic.errors.RateLimitException;
import com.anthropic.errors.UnauthorizedException;
import com.anthropic.models.messages.Base64ImageSource;
import com.anthropic.models.messages.Base64PdfSource;
import com.anthropic.models.messages.ContentBlockParam;
import com.anthropic.models.messages.DocumentBlockParam;
import com.anthropic.models.messages.ImageBlockParam;
import com.anthropic.models.messages.Message;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.OutputConfig;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.TextBlockParam;
import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Claude API provider built on the official Anthropic Java SDK. The SDK performs the controlled retries
 * (408/409/429/5xx and connection errors, exponential backoff) up to {@code maxRetries}; each attempt is bounded by
 * {@code timeout}. Only failure classes (never prompts, responses or exception messages, which may echo content)
 * are logged.
 */
public class AnthropicLlmClient implements LlmClient {
    private static final Logger LOG = LoggerFactory.getLogger(AnthropicLlmClient.class);

    private final AnthropicClient client;
    private final String model;

    public AnthropicLlmClient(String apiKey, String model, Duration timeout, int maxRetries, String baseUrlOrNull) {
        AnthropicOkHttpClient.Builder b = AnthropicOkHttpClient.builder()
                .apiKey(apiKey)
                .timeout(timeout)
                .maxRetries(maxRetries);
        if (baseUrlOrNull != null && !baseUrlOrNull.isBlank()) b.baseUrl(baseUrlOrNull);
        this.client = b.build();
        this.model = model;
    }

    @Override
    public String complete(Request r) {
        MessageCreateParams.Builder p = MessageCreateParams.builder()
                .model(model)
                .maxTokens(r.maxTokens())
                .system(r.system())
                // short, bounded answers: low effort keeps latency and cost small for this use case
                .outputConfig(OutputConfig.builder().effort(OutputConfig.Effort.LOW).build());
        if (r.attachment() == null) {
            p.addUserMessage(r.userText());
        } else {
            p.addUserMessageOfBlockParams(List.of(attachmentBlock(r.attachment()),
                    ContentBlockParam.ofText(TextBlockParam.builder().text(r.userText()).build())));
        }
        Message msg;
        try {
            msg = client.messages().create(p.build());
        } catch (UnauthorizedException | PermissionDeniedException e) {
            LOG.warn("AI provider rejected the credentials (HTTP {})", e.statusCode());
            throw new LlmException(LlmException.Kind.AUTH, "AI provider credentials were rejected");
        } catch (RateLimitException e) {
            LOG.warn("AI provider rate limit reached");
            throw new LlmException(LlmException.Kind.RATE_LIMITED, "AI provider rate limit reached");
        } catch (AnthropicServiceException e) {
            LOG.warn("AI provider error (HTTP {})", e.statusCode());
            throw new LlmException(LlmException.Kind.UNAVAILABLE, "AI provider error");
        } catch (AnthropicIoException e) {
            boolean timeoutLike = e.getCause() instanceof java.net.SocketTimeoutException
                    || e.getCause() instanceof java.io.InterruptedIOException;
            LOG.warn("AI provider connection problem ({})", timeoutLike ? "timeout" : "io");
            throw new LlmException(timeoutLike ? LlmException.Kind.TIMEOUT : LlmException.Kind.UNAVAILABLE,
                    "AI provider connection problem");
        } catch (RuntimeException e) {
            LOG.warn("AI provider call failed ({})", e.getClass().getSimpleName());
            throw new LlmException(LlmException.Kind.UNAVAILABLE, "AI provider call failed");
        }
        if (msg.stopReason().map(s -> s.equals(StopReason.REFUSAL) || s.equals(StopReason.MAX_TOKENS)).orElse(false)) {
            throw new LlmException(LlmException.Kind.BAD_OUTPUT, "AI provider did not complete the answer");
        }
        String text = msg.content().stream().flatMap(c -> c.text().stream()).map(t -> t.text())
                .collect(Collectors.joining());
        if (text.isBlank()) throw new LlmException(LlmException.Kind.BAD_OUTPUT, "AI provider returned no text");
        return text;
    }

    private static ContentBlockParam attachmentBlock(Attachment a) {
        String b64 = Base64.getEncoder().encodeToString(a.bytes());
        if ("application/pdf".equals(a.mediaType())) {
            return ContentBlockParam.ofDocument(DocumentBlockParam.builder()
                    .source(Base64PdfSource.builder().data(b64).build()).build());
        }
        Base64ImageSource.MediaType mt = switch (a.mediaType()) {
            case "image/png" -> Base64ImageSource.MediaType.IMAGE_PNG;
            case "image/jpeg" -> Base64ImageSource.MediaType.IMAGE_JPEG;
            case "image/webp" -> Base64ImageSource.MediaType.IMAGE_WEBP;
            case "image/gif" -> Base64ImageSource.MediaType.IMAGE_GIF;
            default -> throw new LlmException(LlmException.Kind.BAD_OUTPUT, "Unsupported attachment type");
        };
        return ContentBlockParam.ofImage(ImageBlockParam.builder()
                .source(Base64ImageSource.builder().data(b64).mediaType(mt).build()).build());
    }
}
