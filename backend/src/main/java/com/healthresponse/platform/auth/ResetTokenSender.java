package com.healthresponse.platform.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.healthresponse.platform.notification.EmailSender;
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
    private final EmailSender email;

    public ResetTokenSender(@Value("${DEV_LOG_RESET_TOKENS:false}") boolean logTokens, EmailSender email) {
        this.logTokens = logTokens;
        this.email = email;
    }

    public void send(String to, String token) {
        if (this.email.isConfigured()) {
            try {
                this.email.send(to, "HealthResponse password reset",
                        "Use this code in the app to set a new password (valid 30 minutes):\n\n" + token
                                + "\n\nIf you did not request this, ignore this email.");
                return;
            } catch (Exception e) {
                log.warn("Password reset email could not be sent");
            }
        }
        if (logTokens) {
            log.warn("DEV ONLY - password reset token for {}: {}", to, token);
        } else {
            log.info("Password reset requested; email delivery is not configured so no message was sent.");
        }
    }
}
