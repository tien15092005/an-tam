package vn.antam.auth;

import java.io.IOException;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * An access token stays valid for a few minutes after it is issued. When an admin locks an account, this
 * makes the lock take effect on the very next request instead (plan §10: "khóa làm mất phiên").
 */
public class DisabledAccountFilter extends OncePerRequestFilter {

    private final JdbcTemplate jdbc;

    public DisabledAccountFilter(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && auth.getName() != null && auth.getName().matches("\\d+")) {
            Boolean disabled = jdbc.query("SELECT disabled FROM users WHERE id = ?",
                    rs -> rs.next() ? rs.getBoolean(1) : Boolean.TRUE, Long.valueOf(auth.getName()));
            if (Boolean.TRUE.equals(disabled)) {
                SecurityContextHolder.clearContext();
                res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                res.setContentType("application/json;charset=UTF-8");
                res.getWriter().write("{\"code\":\"account_disabled\",\"detail\":\"Tài khoản đã bị khóa.\"}");
                return;
            }
        }
        chain.doFilter(req, res);
    }
}
