package com.healthresponse.platform.notification;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import java.io.FileInputStream;
import java.io.InputStream;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.stereotype.Component;

/**
 * Firebase Cloud Messaging via the Admin SDK. Active only when FCM_SERVICE_ACCOUNT_FILE points to a Firebase
 * service-account JSON key. Messages carry only the generic title/body of the in-app notification.
 */
@Component
@ConditionalOnExpression("'${FCM_SERVICE_ACCOUNT_FILE:}' != ''")
public class FcmPushGateway implements NotificationDispatcher.PushGateway {
    private final FirebaseMessaging messaging;

    public FcmPushGateway(@Value("${FCM_SERVICE_ACCOUNT_FILE}") String file) throws Exception {
        try (InputStream in = new FileInputStream(file)) {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(in)).build();
            FirebaseApp app = FirebaseApp.getApps().isEmpty()
                    ? FirebaseApp.initializeApp(options) : FirebaseApp.getInstance();
            this.messaging = FirebaseMessaging.getInstance(app);
        }
    }

    @Override
    public boolean isConfigured() { return true; }

    @Override
    public void send(String deviceToken, String title, String body) throws Exception {
        messaging.send(Message.builder().setToken(deviceToken)
                .setNotification(Notification.builder().setTitle(title).setBody(body).build()).build());
    }
}
