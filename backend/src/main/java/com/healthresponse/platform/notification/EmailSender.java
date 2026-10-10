package com.healthresponse.platform.notification;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

/**
 * SMTP email. Enabled by setting MAIL_HOST (+ MAIL_PORT, MAIL_USERNAME, MAIL_PASSWORD, MAIL_FROM). Works with any
 * SMTP provider (Gmail app password, Brevo, Mailgun, SES SMTP...).
 */
@Component
public class EmailSender {
    private final ObjectProvider<JavaMailSender> mail;
    private final String from;
    private final boolean configured;

    public EmailSender(ObjectProvider<JavaMailSender> mail,
                       @Value("${MAIL_HOST:}") String host,
                       @Value("${MAIL_FROM:}") String from) {
        this.mail = mail;
        this.from = from;
        this.configured = !host.isBlank() && !from.isBlank();
    }

    public boolean isConfigured() { return configured && mail.getIfAvailable() != null; }

    public void send(String to, String subject, String body) {
        JavaMailSender sender = mail.getIfAvailable();
        if (!isConfigured() || sender == null) throw new IllegalStateException("Email provider not configured");
        SimpleMailMessage m = new SimpleMailMessage();
        m.setFrom(from);
        m.setTo(to);
        m.setSubject(subject);
        m.setText(body);
        sender.send(m);
    }
}
