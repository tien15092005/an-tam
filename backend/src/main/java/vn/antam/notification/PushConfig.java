package vn.antam.notification;

import java.io.IOException;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PushConfig {

    /** FCM when the service-account file is configured; otherwise pushes are switched off. */
    @Bean
    @ConditionalOnMissingBean(PushSender.class)
    PushSender pushSender(@Value("${antam.fcm.credentials:}") String credentials) throws IOException {
        if (!credentials.isBlank()) return new FcmPushSender(credentials);
        return new PushSender() {
            @Override
            public boolean enabled() {
                return false;
            }

            @Override
            public Result send(String token, String title, String body, Map<String, String> data, boolean urgent) {
                throw new IllegalStateException("Pushes are disabled");
            }
        };
    }
}
