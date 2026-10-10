package com.healthresponse.platform.notification;

/** Boundary for sending a text message. The shipped implementation is {@link TwilioSmsSender}. */
public interface SmsSender {
    /** False when no provider credentials are configured; callers must then not claim anything was sent. */
    boolean isConfigured();

    /** @throws Exception if the provider did not accept the message (the dispatcher retries). */
    void send(String toE164, String body) throws Exception;
}
