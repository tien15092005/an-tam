package vn.antam.notification;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;

/**
 * Firebase Cloud Messaging through the Admin SDK. Created only when FIREBASE_CREDENTIALS points to the
 * team leader's service-account file (kept outside Git). Without it the outbox closes entries as DISABLED
 * and the apps fall back to refreshing on open and on a timer.
 */
public class FcmPushSender implements PushSender {

    private static final Logger log = LoggerFactory.getLogger(FcmPushSender.class);

    private final FirebaseMessaging messaging;

    public FcmPushSender(String credentialsPath) throws IOException {
        try (InputStream in = new FileInputStream(credentialsPath)) {
            FirebaseOptions options = FirebaseOptions.builder().setCredentials(GoogleCredentials.fromStream(in)).build();
            FirebaseApp app = FirebaseApp.getApps().stream().filter(a -> a.getName().equals("antam")).findFirst()
                    .orElseGet(() -> FirebaseApp.initializeApp(options, "antam"));
            this.messaging = FirebaseMessaging.getInstance(app);
        }
        log.info("FCM pushes enabled");
    }

    @Override
    public boolean enabled() {
        return true;
    }

    @Override
    public Result send(String token, String title, String body, Map<String, String> data, boolean urgent) {
        Message.Builder m = Message.builder()
                .setToken(token)
                .putAllData(data)
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(urgent || title == null ? AndroidConfig.Priority.HIGH : AndroidConfig.Priority.NORMAL)
                        .build());
        if (title != null) m.setNotification(Notification.builder().setTitle(title).setBody(body).build());
        try {
            messaging.send(m.build());
            return Result.SENT;
        } catch (FirebaseMessagingException e) {
            MessagingErrorCode code = e.getMessagingErrorCode();
            if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.INVALID_ARGUMENT
                    || code == MessagingErrorCode.SENDER_ID_MISMATCH) {
                return Result.INVALID_TOKEN;
            }
            // Never log the message content (it names medicines); the error code is enough.
            log.warn("FCM send failed: {}", code);
            return Result.RETRY;
        }
    }
}
