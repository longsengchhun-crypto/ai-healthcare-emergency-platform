package com.healthresponse.platform.notification;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Twilio Programmable SMS via the public REST API (no SDK). Configure with TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN
 * and TWILIO_FROM (a Twilio number or messaging-service sender). Without all three the sender reports
 * {@code isConfigured() == false} and nothing is sent.
 */
@Component
public class TwilioSmsSender implements SmsSender {
    private final String sid;
    private final String token;
    private final String from;
    private final String baseUrl;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();

    public TwilioSmsSender(@Value("${TWILIO_ACCOUNT_SID:}") String sid,
                           @Value("${TWILIO_AUTH_TOKEN:}") String token,
                           @Value("${TWILIO_FROM:}") String from,
                           @Value("${TWILIO_BASE_URL:https://api.twilio.com}") String baseUrl) {
        this.sid = sid;
        this.token = token;
        this.from = from;
        this.baseUrl = baseUrl;
    }

    @Override
    public boolean isConfigured() {
        return !sid.isBlank() && !token.isBlank() && !from.isBlank();
    }

    @Override
    public void send(String to, String body) throws Exception {
        if (!isConfigured()) throw new IllegalStateException("SMS provider not configured");
        String form = "To=" + enc(to) + "&From=" + enc(from) + "&Body=" + enc(body);
        String auth = Base64.getEncoder().encodeToString((sid + ":" + token).getBytes(StandardCharsets.UTF_8));
        HttpRequest req = HttpRequest.newBuilder(URI.create(baseUrl + "/2010-04-01/Accounts/" + sid + "/Messages.json"))
                .timeout(Duration.ofSeconds(10))
                .header("Authorization", "Basic " + auth)
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(form)).build();
        HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString());
        if (res.statusCode() / 100 != 2) {
            // Status only: the response body may echo the phone number.
            throw new java.io.IOException("SMS provider rejected the message (HTTP " + res.statusCode() + ")");
        }
    }

    private static String enc(String v) { return URLEncoder.encode(v, StandardCharsets.UTF_8); }
}
