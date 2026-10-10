package com.healthresponse.platform.admin;

import com.healthresponse.platform.auth.UserRepository;
import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.security.AppProperties;
import java.time.Instant;
import java.time.LocalTime;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Creates clearly-fictional DEMO data for local development. It runs only when SEED_DEMO_DATA=true AND
 * SEED_DEMO_PASSWORD is supplied via the environment. No password is stored in source control, and the seeder
 * must never be enabled in production. All records are flagged is_demo and use the reserved .test domain.
 */
@Component
public class DemoDataSeeder implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(DemoDataSeeder.class);

    public static final String PATIENT = "patient.demo@example.test";
    public static final String DOCTOR = "doctor.demo@example.test";
    public static final String DOCTOR2 = "doctor2.demo@example.test";
    public static final String STAFF = "staff.demo@example.test";
    public static final String ADMIN = "admin.demo@example.test";

    private final AppProperties props;
    private final UserRepository users;
    private final JdbcClient jdbc;
    private final PasswordEncoder encoder;
    private final TransactionTemplate tx;

    public DemoDataSeeder(AppProperties props, UserRepository users, JdbcClient jdbc, PasswordEncoder encoder,
                          TransactionTemplate tx) {
        this.tx = tx;
        this.props = props;
        this.users = users;
        this.jdbc = jdbc;
        this.encoder = encoder;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!props.seed().demoEnabled()) return;
        String pw = props.seed().demoPassword();
        if (pw == null || pw.length() < 10) {
            log.warn("SEED_DEMO_DATA is true but SEED_DEMO_PASSWORD is missing/short (min 10); skipping demo seed");
            return;
        }
        tx.executeWithoutResult(status -> seed(pw)); // atomic: all demo data or none
    }

    void seed(String password) {
        if (users.emailExists(PATIENT)) return; // repeatable: seed once
        String hash = encoder.encode(password);
        Instant now = Instant.now();

        UUID h1 = hospital("Demo General Hospital (SAMPLE)", "1 Sample Street", "Phnom Penh", "+855000000001", 11.5564, 104.9282);
        UUID h2 = hospital("Demo Riverside Clinic (SAMPLE)", "2 Sample Avenue", "Siem Reap", "+855000000002", 13.3671, 103.8448);
        UUID cardio = department(h1, "Cardiology");
        department(h1, "Emergency");
        UUID gp = department(h2, "General Practice");

        UUID patientUser = users.insertUser(PATIENT, hash, "Demo Patient", "+855000000010", "PATIENT");
        jdbc.sql("""
                INSERT INTO patient_profiles (id, user_id, date_of_birth, blood_group, allergies, created_at, updated_at)
                VALUES (:id, :u, DATE '1990-01-01', 'O+', 'Sample allergy: penicillin (demo data)', :n, :n)""")
                .param("id", UUID.randomUUID()).param("u", patientUser).param("n", Sql.ts(now)).update();

        doctor(DOCTOR, hash, "Dr. Demo Cardiologist", "Cardiology", h1, cardio, now);
        doctor(DOCTOR2, hash, "Dr. Demo Generalist", "General Practice", h2, gp, now);

        UUID staffUser = users.insertUser(STAFF, hash, "Demo Hospital Operator", "+855000000020", "HOSPITAL_STAFF");
        jdbc.sql("INSERT INTO hospital_staff (user_id, hospital_id) VALUES (:u, :h)").param("u", staffUser).param("h", h1).update();
        users.insertUser(ADMIN, hash, "Demo Administrator", null, "SYSTEM_ADMIN");
        log.info("Demo data seeded (fictional accounts under @example.test)");
    }

    private UUID hospital(String name, String address, String city, String phone, double lat, double lon) {
        UUID id = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO hospitals (id, name, address, city, phone, latitude, longitude, is_demo, created_at)
                VALUES (:id, :n, :a, :c, :p, :la, :lo, TRUE, :now)""")
                .param("id", id).param("n", name).param("a", address).param("c", city).param("p", phone)
                .param("la", lat).param("lo", lon).param("now", Sql.ts(Instant.now())).update();
        return id;
    }

    private UUID department(UUID hospital, String name) {
        UUID id = UUID.randomUUID();
        jdbc.sql("INSERT INTO hospital_departments (id, hospital_id, name) VALUES (:id, :h, :n)")
                .param("id", id).param("h", hospital).param("n", name).update();
        return id;
    }

    private void doctor(String email, String hash, String name, String specialty, UUID hospital, UUID dept, Instant now) {
        UUID user = users.insertUser(email, hash, name, null, "DOCTOR");
        UUID doc = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO doctor_profiles (id, user_id, specialty, bio, verification_status, is_demo, created_at)
                VALUES (:id, :u, :s, :b, 'UNVERIFIED', TRUE, :now)""")
                .param("id", doc).param("u", user).param("s", specialty)
                .param("b", "Fictional demonstration clinician. Not a real doctor.").param("now", Sql.ts(now)).update();
        jdbc.sql("INSERT INTO doctor_hospital_affiliations (doctor_id, hospital_id, department_id) VALUES (:d, :h, :dep)")
                .param("d", doc).param("h", hospital).param("dep", dept).update();
        for (int dow = 1; dow <= 5; dow++) {
            jdbc.sql("""
                    INSERT INTO doctor_availability (id, doctor_id, day_of_week, start_time, end_time, slot_minutes)
                    VALUES (:id, :d, :dow, :s, :e, 30)""")
                    .param("id", UUID.randomUUID()).param("d", doc).param("dow", dow)
                    .param("s", java.sql.Time.valueOf(LocalTime.of(9, 0))).param("e", java.sql.Time.valueOf(LocalTime.of(12, 0)))
                    .update();
        }
    }
}
