package vn.antam.auth;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import vn.antam.common.ApiException;

/**
 * Sliding-window limit on login and code attempts, per key (e.g. "pair:ip:1.2.3.4").
 * In-memory is enough for a single backend instance; it resets on restart.
 */
@Component
public class AttemptLimiter {

    private final Clock clock;
    private final Map<String, Deque<Instant>> attempts = new ConcurrentHashMap<>();

    public AttemptLimiter(Clock clock) {
        this.clock = clock;
    }

    /** Records one attempt and throws 429 if the key has used up its allowance. */
    public void check(String key, int max, Duration window) {
        Instant now = clock.instant();
        Deque<Instant> q = attempts.computeIfAbsent(key, k -> new ArrayDeque<>());
        synchronized (q) {
            while (!q.isEmpty() && q.peekFirst().isBefore(now.minus(window))) q.pollFirst();
            if (q.size() >= max) {
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "too_many_attempts",
                        "Bạn đã thử quá nhiều lần. Vui lòng đợi " + window.toMinutes() + " phút rồi thử lại.");
            }
            q.addLast(now);
        }
    }

    /** Throws 429 if the key has used up its allowance, without counting this call. */
    public void requireUnder(String key, int max, Duration window) {
        Instant now = clock.instant();
        Deque<Instant> q = attempts.get(key);
        if (q == null) return;
        synchronized (q) {
            while (!q.isEmpty() && q.peekFirst().isBefore(now.minus(window))) q.pollFirst();
            if (q.size() >= max) {
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "too_many_attempts",
                        "Hệ thống đang tạm khóa nhập mã vì có quá nhiều lần thử sai. Vui lòng đợi vài phút rồi thử lại.");
            }
        }
    }

    /** Counts one event (e.g. a wrong code) under the key. */
    public void record(String key) {
        Deque<Instant> q = attempts.computeIfAbsent(key, k -> new ArrayDeque<>());
        synchronized (q) {
            q.addLast(clock.instant());
        }
    }

    /** Forgets a key after success so a correct login doesn't count against the user. */
    public void reset(String key) {
        attempts.remove(key);
    }

    /** Forgets everything. Used by tests, which all come from the same address. */
    public void clear() {
        attempts.clear();
    }
}
