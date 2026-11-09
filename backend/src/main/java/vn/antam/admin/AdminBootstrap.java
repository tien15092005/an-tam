package vn.antam.admin;

import java.time.Clock;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import vn.antam.user.User;
import vn.antam.user.UserRepository;

/** Creates the system admin once from ADMIN_EMAIL / ADMIN_PASSWORD (kept in .env). Nothing happens if unset. */
@Component
public class AdminBootstrap implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminBootstrap.class);

    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final Clock clock;
    private final String email;
    private final String password;

    public AdminBootstrap(UserRepository users, PasswordEncoder encoder, Clock clock,
                          @Value("${antam.admin.email:}") String email, @Value("${antam.admin.password:}") String password) {
        this.users = users;
        this.encoder = encoder;
        this.clock = clock;
        this.email = email.trim().toLowerCase(java.util.Locale.ROOT);
        this.password = password;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (email.isEmpty() || password.length() < 12 || users.existsByEmailIgnoreCase(email)) return;
        users.save(User.admin(email, encoder.encode(password), clock.instant()));
        log.info("System admin account created");
    }
}
