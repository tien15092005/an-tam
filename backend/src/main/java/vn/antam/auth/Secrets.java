package vn.antam.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.HexFormat;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Random codes and their stored fingerprints. Invite / pairing codes are short, so they are stored
 * as an HMAC with a server secret (a leaked database alone cannot be brute-forced offline);
 * refresh tokens are long and random, so a plain SHA-256 is enough.
 */
@Component
public class Secrets {

    private static final char[] INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".toCharArray();

    private final SecureRandom random = new SecureRandom();
    private final SecretKeySpec codeKey;

    public Secrets(@Value("${antam.codes.secret}") String codeSecret) {
        if (codeSecret == null || codeSecret.length() < 32) {
            throw new IllegalStateException("CODES_SECRET must be at least 32 characters");
        }
        this.codeKey = new SecretKeySpec(codeSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    }

    /** Six digits, what an elder can type: 000000–999999. */
    public String sixDigitCode() {
        return String.format("%06d", random.nextInt(1_000_000));
    }

    /** Ten characters without look-alikes (no 0/O, 1/I), shared by caregivers via Zalo etc. */
    public String inviteCode() {
        char[] c = new char[10];
        for (int i = 0; i < c.length; i++) c[i] = INVITE_ALPHABET[random.nextInt(INVITE_ALPHABET.length)];
        return new String(c);
    }

    public String refreshToken() {
        byte[] b = new byte[32];
        random.nextBytes(b);
        return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(b);
    }

    public String hashCode(String code) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(codeKey);
            return HexFormat.of().formatHex(mac.doFinal(normalize(code).getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    public String hashToken(String token) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    /** Users may type invite codes in lower case or with spaces/dashes. */
    static String normalize(String code) {
        return code == null ? "" : code.replaceAll("[\\s-]", "").toUpperCase(java.util.Locale.ROOT);
    }
}
