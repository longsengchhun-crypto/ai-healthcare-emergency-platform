package com.healthresponse.platform.common;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;

/** Small JDBC helpers: all timestamps are stored and exchanged as UTC instants. */
public final class Sql {
    private Sql() {}

    public static Timestamp ts(Instant i) { return i == null ? null : Timestamp.from(i); }

    public static Instant instant(ResultSet rs, String col) throws SQLException {
        Timestamp t = rs.getTimestamp(col);
        return t == null ? null : t.toInstant();
    }
}
