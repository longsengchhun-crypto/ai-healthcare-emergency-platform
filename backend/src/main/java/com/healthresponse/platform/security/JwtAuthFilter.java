package com.healthresponse.platform.security;

import com.healthresponse.platform.auth.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {
    private final JwtService jwt;
    private final UserRepository users;

    public JwtAuthFilter(JwtService jwt, UserRepository users) {
        this.jwt = jwt;
        this.users = users;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String header = req.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            UUID userId = jwt.validate(header.substring(7));
            if (userId != null) {
                users.loadPrincipal(userId).ifPresent(p -> {
                    var authorities = Stream.concat(
                            p.roles().stream().map(r -> "ROLE_" + r),
                            p.permissions().stream()).map(SimpleGrantedAuthority::new).collect(Collectors.toList());
                    SecurityContextHolder.getContext()
                            .setAuthentication(new UsernamePasswordAuthenticationToken(p, null, authorities));
                });
            }
        }
        chain.doFilter(req, res);
    }
}
