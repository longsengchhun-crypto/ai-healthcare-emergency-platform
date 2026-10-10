package com.healthresponse.platform.directory;

import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.Sql;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

@Service
public class DirectoryService {
    /** Availability is defined in clinic-local time; all stored/exchanged instants are UTC. */
    public static final ZoneId CLINIC_ZONE = ZoneId.of("Asia/Phnom_Penh");

    public record Page<T>(List<T> items, int page, int size, long total) {}
    public record DoctorView(UUID id, String fullName, String nameLatin, String specialty, String specialtyKm,
                             String bio, String bioEn, String verificationStatus, boolean demo, UUID hospitalId,
                             String hospitalName, String photoUrl, Integer yearsExperience, String languages) {}
    public record HospitalView(UUID id, String name, String nameLatin, String address, String city, String phone,
                               Double latitude, Double longitude, boolean demo, Double distanceKm,
                               List<String> departments, String photoUrl, String openingHours) {}
    public record Slot(Instant startsAt, Instant endsAt) {}

    private static final String DOCTOR_COLUMNS = """
            d.id, u.full_name, d.name_latin, d.specialty, d.specialty_km, d.bio, d.bio_en, d.verification_status,
            d.is_demo, h.id AS hid, h.name AS hname, d.photo_url, d.years_experience, d.languages""";

    private static final String DOCTOR_FROM = """
            FROM doctor_profiles d JOIN users u ON u.id = d.user_id AND u.status = 'ACTIVE' AND u.deleted_at IS NULL
            LEFT JOIN doctor_hospital_affiliations a ON a.doctor_id = d.id
            LEFT JOIN hospitals h ON h.id = a.hospital_id""";

    private final JdbcClient jdbc;

    public DirectoryService(JdbcClient jdbc) { this.jdbc = jdbc; }

    private DoctorView doctorRow(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new DoctorView(rs.getObject("id", UUID.class), rs.getString("full_name"), rs.getString("name_latin"),
                rs.getString("specialty"), rs.getString("specialty_km"), rs.getString("bio"), rs.getString("bio_en"),
                rs.getString("verification_status"), rs.getBoolean("is_demo"), rs.getObject("hid", UUID.class),
                rs.getString("hname"), rs.getString("photo_url"),
                rs.getObject("years_experience") == null ? null : rs.getInt("years_experience"),
                rs.getString("languages"));
    }

    public Page<DoctorView> doctors(String q, String specialty, UUID hospitalId, boolean verifiedOnly, int page, int size) {
        size = Math.min(Math.max(size, 1), 50);
        page = Math.max(page, 0);
        String where = """
                WHERE (CAST(:q AS VARCHAR) IS NULL OR LOWER(u.full_name) LIKE CAST(:qlike AS VARCHAR)
                       OR LOWER(COALESCE(d.name_latin, '')) LIKE CAST(:qlike AS VARCHAR)
                       OR LOWER(d.specialty) LIKE CAST(:qlike AS VARCHAR)
                       OR LOWER(COALESCE(d.specialty_km, '')) LIKE CAST(:qlike AS VARCHAR))
                  AND (CAST(:spec AS VARCHAR) IS NULL OR LOWER(d.specialty) = CAST(:spec AS VARCHAR))
                  AND (CAST(:hid AS UUID) IS NULL OR a.hospital_id = CAST(:hid AS UUID))
                  AND (:verified = FALSE OR d.verification_status = 'VERIFIED')""";
        String qn = q == null || q.isBlank() ? null : q.trim().toLowerCase();
        String sn = specialty == null || specialty.isBlank() ? null : specialty.trim().toLowerCase();
        String like = qn == null ? null : "%" + qn + "%";
        long total = jdbc.sql("SELECT COUNT(*) " + DOCTOR_FROM + " " + where).param("q", qn).param("qlike", like)
                .param("spec", sn).param("hid", hospitalId).param("verified", verifiedOnly).query(Long.class).single();
        List<DoctorView> items = jdbc.sql("SELECT " + DOCTOR_COLUMNS + " " + DOCTOR_FROM + " " + where
                        + " ORDER BY d.name_latin, u.full_name LIMIT :lim OFFSET :off")
                .param("q", qn).param("qlike", like).param("spec", sn).param("hid", hospitalId)
                .param("verified", verifiedOnly).param("lim", size).param("off", page * size)
                .query((rs, n) -> doctorRow(rs)).list();
        return new Page<>(items, page, size, total);
    }

    public DoctorView doctor(UUID id) {
        return jdbc.sql("SELECT " + DOCTOR_COLUMNS + " " + DOCTOR_FROM + " WHERE d.id = :id ORDER BY h.name LIMIT 1")
                .param("id", id).query((rs, n) -> doctorRow(rs)).optional()
                .orElseThrow(() -> ApiException.notFound("Doctor"));
    }

    public Page<HospitalView> hospitals(String q, String city, Double lat, Double lon, int page, int size) {
        size = Math.min(Math.max(size, 1), 50);
        page = Math.max(page, 0);
        String qn = q == null || q.isBlank() ? null : "%" + q.trim().toLowerCase() + "%";
        String cn = city == null || city.isBlank() ? null : city.trim().toLowerCase();
        List<HospitalView> all = new ArrayList<>(jdbc.sql("""
                SELECT id, name, name_latin, address, city, phone, latitude, longitude, is_demo, photo_url, opening_hours
                FROM hospitals
                WHERE active = TRUE AND (CAST(:q AS VARCHAR) IS NULL OR LOWER(name) LIKE CAST(:q AS VARCHAR)
                       OR LOWER(COALESCE(name_latin, '')) LIKE CAST(:q AS VARCHAR)
                       OR LOWER(COALESCE(address, '')) LIKE CAST(:q AS VARCHAR))
                  AND (CAST(:c AS VARCHAR) IS NULL OR LOWER(city) = CAST(:c AS VARCHAR)) ORDER BY name_latin, name""")
                .param("q", qn).param("c", cn)
                .query((rs, n) -> {
                    Double hl = rs.getObject("latitude") == null ? null : rs.getDouble("latitude");
                    Double ho = rs.getObject("longitude") == null ? null : rs.getDouble("longitude");
                    Double dist = (lat != null && lon != null && hl != null && ho != null) ? haversineKm(lat, lon, hl, ho) : null;
                    return new HospitalView(rs.getObject("id", UUID.class), rs.getString("name"), rs.getString("name_latin"),
                            rs.getString("address"), rs.getString("city"), rs.getString("phone"), hl, ho,
                            rs.getBoolean("is_demo"), dist, List.of(), rs.getString("photo_url"),
                            rs.getString("opening_hours"));
                }).list());
        if (lat != null && lon != null) {
            all.sort(Comparator.comparing((HospitalView h) -> h.distanceKm() == null ? Double.MAX_VALUE : h.distanceKm()));
        }
        int from = Math.min(page * size, all.size());
        return new Page<>(all.subList(from, Math.min(from + size, all.size())), page, size, all.size());
    }

    public HospitalView hospital(UUID id) {
        HospitalView h = jdbc.sql("""
                SELECT id, name, name_latin, address, city, phone, latitude, longitude, is_demo, photo_url, opening_hours
                FROM hospitals WHERE id = :id AND active = TRUE""").param("id", id)
                .query((rs, n) -> new HospitalView(rs.getObject("id", UUID.class), rs.getString("name"),
                        rs.getString("name_latin"), rs.getString("address"), rs.getString("city"), rs.getString("phone"),
                        rs.getObject("latitude") == null ? null : rs.getDouble("latitude"),
                        rs.getObject("longitude") == null ? null : rs.getDouble("longitude"),
                        rs.getBoolean("is_demo"), null, List.of(), rs.getString("photo_url"),
                        rs.getString("opening_hours"))).optional()
                .orElseThrow(() -> ApiException.notFound("Hospital"));
        List<String> depts = jdbc.sql("SELECT name FROM hospital_departments WHERE hospital_id = :h ORDER BY name")
                .param("h", id).query(String.class).list();
        return new HospitalView(h.id(), h.name(), h.nameLatin(), h.address(), h.city(), h.phone(), h.latitude(),
                h.longitude(), h.demo(), null, depts, h.photoUrl(), h.openingHours());
    }

    /** Bookable slots for a clinic-local date: availability windows minus slots already held. */
    public List<Slot> slots(UUID doctorId, LocalDate date) {
        List<Slot> candidates = new ArrayList<>();
        jdbc.sql("""
                SELECT start_time, end_time, slot_minutes FROM doctor_availability
                WHERE doctor_id = :d AND day_of_week = :dow ORDER BY start_time""")
                .param("d", doctorId).param("dow", date.getDayOfWeek().getValue())
                .query((rs, n) -> new Object[]{rs.getTime("start_time").toLocalTime(), rs.getTime("end_time").toLocalTime(),
                        rs.getInt("slot_minutes")})
                .list().forEach(w -> {
                    LocalTime t = (LocalTime) w[0];
                    LocalTime end = (LocalTime) w[1];
                    int mins = (Integer) w[2];
                    while (!t.plusMinutes(mins).isAfter(end)) {
                        ZonedDateTime start = date.atTime(t).atZone(CLINIC_ZONE);
                        candidates.add(new Slot(start.toInstant(), start.plusMinutes(mins).toInstant()));
                        t = t.plusMinutes(mins);
                    }
                });
        Instant now = Instant.now();
        List<Instant> held = jdbc.sql("""
                SELECT starts_at FROM appointments WHERE doctor_id = :d AND slot_key IS NOT NULL
                  AND starts_at >= :from AND starts_at < :to""")
                .param("d", doctorId).param("from", Sql.ts(date.atStartOfDay(CLINIC_ZONE).toInstant()))
                .param("to", Sql.ts(date.plusDays(1).atStartOfDay(CLINIC_ZONE).toInstant()))
                .query((rs, n) -> Sql.instant(rs, "starts_at")).list();
        return candidates.stream().filter(s -> s.startsAt().isAfter(now) && !held.contains(s.startsAt())).toList();
    }

    static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        double r = 6371.0088;
        double dLat = Math.toRadians(lat2 - lat1), dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return Math.round(r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)) * 10.0) / 10.0;
    }
}
