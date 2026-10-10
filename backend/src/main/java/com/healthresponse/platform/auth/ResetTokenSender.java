package com.healthresponse.platform.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Delivery boundary for password-reset tokens. No email provider is configured in this repository, so by default
 * the token is NOT delivered anywhere. For local development only, set DEV_LOG_RESET_TOKENS=true to log it.
 * Replace this bean with an SMTP/email-provider implementation for a real deployment.
 */
@Component
public class ResetTokenSender {
    private static final Logger log = LoggerFactory.getLogger(ResetTokenSender.class);
    private final boolean logTokens;

    public ResetTokenSender(@Value("${DEV_LOG_RESET_TOKENS:false}") boolean logTokens) { this.logTokens = logTokens; }

    public void send(String email, String token) {
        if (logTokens) {
            log.warn("DEV ONLY - password reset token for {}: {}", email, token);
        } else {
            log.info("Password reset requested; email delivery is not configured so no message was sent.");
        }
    }
}
