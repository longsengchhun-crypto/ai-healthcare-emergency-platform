package com.healthresponse.platform.admin;

import com.healthresponse.platform.auth.UserRepository;
import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.directory.DirectoryService;
import com.healthresponse.platform.security.AppProperties;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
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
 * Creates clearly-fictional DEMO data for local development: bilingual (Khmer / Latin) hospitals and doctors with
 * illustrated avatars, a patient with records, medications, appointments and a finished emergency.
 * Runs only when SEED_DEMO_DATA=true AND SEED_DEMO_PASSWORD is supplied via the environment. Every hospital and
 * doctor is flagged is_demo and named "(គំរូ)" / "Sample"; none refers to a real person or institution.
 * Never enable seeding in production.
 */
@Component
public class DemoDataSeeder implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(DemoDataSeeder.class);

    public static final String PATIENT = "patient.demo@example.test";
    public static final String DOCTOR = "doctor.demo@example.test";
    public static final String DOCTOR2 = "doctor2.demo@example.test";
    public static final String STAFF = "staff.demo@example.test";
    public static final String ADMIN = "admin.demo@example.test";

    private record Hosp(String km, String latin, String address, String city, String phone, double lat, double lon,
                        String hours) {}

    private record Doc(String km, String latin, String specEn, String specKm, int hospital, int years, String langs,
                       String email) {}

    private static final Hosp[] HOSPITALS = {
        new Hosp("មន្ទីរពេទ្យទូទៅភ្នំពេញ (គំរូ)", "Phnom Penh General Hospital (Sample)", "ផ្លូវលេខ ២៧១ សង្កាត់ទួលទំពូង", "Phnom Penh", "+855000000001", 11.5564, 104.9282, "24 ម៉ោង / 24 hours"),
        new Hosp("គ្លីនិកមិត្តភាព សៀមរាប (គំរូ)", "Siem Reap Friendship Clinic (Sample)", "ផ្លូវសាលាកំរើក ក្រុងសៀមរាប", "Siem Reap", "+855000000002", 13.3671, 103.8448, "07:00 – 19:00"),
        new Hosp("មន្ទីរពេទ្យខេត្តបាត់ដំបង (គំរូ)", "Battambang Provincial Hospital (Sample)", "ផ្លូវលេខ ១ ក្រុងបាត់ដំបង", "Battambang", "+855000000003", 13.0957, 103.2022, "24 ម៉ោង / 24 hours"),
        new Hosp("មជ្ឈមណ្ឌលសុខភាពកំពង់ចាម (គំរូ)", "Kampong Cham Health Centre (Sample)", "ផ្លូវជាតិលេខ ៧ ក្រុងកំពង់ចាម", "Kampong Cham", "+855000000004", 11.9934, 105.4635, "08:00 – 17:00"),
        new Hosp("គ្លីនិកមាតា និងកុមារ កំពត (គំរូ)", "Kampot Mother & Child Clinic (Sample)", "មហាវិថីព្រះមុនីវង្ស ក្រុងកំពត", "Kampot", "+855000000005", 10.6104, 104.1815, "07:30 – 18:00"),
        new Hosp("មន្ទីរពេទ្យព្រះសីហនុ (គំរូ)", "Sihanoukville Hospital (Sample)", "ផ្លូវលេខ ៤ ក្រុងព្រះសីហនុ", "Sihanoukville", "+855000000006", 10.6275, 103.5222, "24 ម៉ោង / 24 hours"),
    };

    private static final Doc[] DOCTORS = {
        new Doc("វេជ្ជ. សុខ វិសាល", "Dr. Sok Visal", "Cardiology", "បេះដូង", 0, 14, "ខ្មែរ, English", DOCTOR),
        new Doc("វេជ្ជ. ចាន់ សុភាព", "Dr. Chan Sopheap", "General Practice", "វេជ្ជសាស្ត្រទូទៅ", 1, 9, "ខ្មែរ, English", DOCTOR2),
        new Doc("វេជ្ជ. គង់ សុភ័ក្ត្រ", "Dr. Kong Sophak", "Pediatrics", "កុមារ", 0, 11, "ខ្មែរ, English, Français", "doctor3.demo@example.test"),
        new Doc("វេជ្ជ. ហេង រតនា", "Dr. Heng Rattana", "Orthopedics", "ឆ្អឹង និងសន្លាក់", 2, 16, "ខ្មែរ, English", "doctor4.demo@example.test"),
        new Doc("វេជ្ជ. ឈិន មុនីរ័ត្ន", "Dr. Chhin Monirath", "Obstetrics & Gynecology", "ស្ត្រី និងសម្ភព", 0, 12, "ខ្មែរ, English", "doctor5.demo@example.test"),
        new Doc("វេជ្ជ. ពៅ សុវណ្ណ", "Dr. Pov Sovann", "Dermatology", "ស្បែក", 5, 8, "ខ្មែរ, English", "doctor6.demo@example.test"),
        new Doc("វេជ្ជ. លី ចន្ធូ", "Dr. Ly Chanthou", "Ophthalmology", "ភ្នែក", 1, 10, "ខ្មែរ, 中文", "doctor7.demo@example.test"),
        new Doc("វេជ្ជ. ម៉ៅ សំអាត", "Dr. Mao Samat", "Internal Medicine", "វេជ្ជសាស្ត្រផ្ទៃក្នុង", 3, 18, "ខ្មែរ", "doctor8.demo@example.test"),
        new Doc("វេជ្ជ. ស៊ឹម ស្រីនាង", "Dr. Sim Sreyneang", "Pediatrics", "កុមារ", 4, 7, "ខ្មែរ, English", "doctor9.demo@example.test"),
        new Doc("វេជ្ជ. អ៊ុក ដារ៉ា", "Dr. Ouk Dara", "Emergency Medicine", "សង្គ្រោះបន្ទាន់", 0, 13, "ខ្មែរ, English", "doctor10.demo@example.test"),
        new Doc("វេជ្ជ. រស់ ម៉ាលីន", "Dr. Ros Maleen", "Dentistry", "ទន្តសាស្ត្រ", 2, 6, "ខ្មែរ, English", "doctor11.demo@example.test"),
        new Doc("វេជ្ជ. តាំង វុទ្ធី", "Dr. Tang Vutthy", "Neurology", "សរសៃប្រសាទ", 5, 20, "ខ្មែរ, English", "doctor12.demo@example.test"),
    };

    private static final String[] DEPARTMENTS = {
        "បេះដូង · Cardiology", "សុខភាពទូទៅ · General", "កុមារ · Pediatrics",
        "ស្ត្រី និងសម្ភព · Obstetrics", "ឆ្អឹង និងសន្លាក់ · Orthopedics", "សង្គ្រោះបន្ទាន់ · Emergency",
    };

    private final AppProperties props;
    private final UserRepository users;
    private final JdbcClient jdbc;
    private final PasswordEncoder encoder;
    private final TransactionTemplate tx;

    public DemoDataSeeder(AppProperties props, UserRepository users, JdbcClient jdbc, PasswordEncoder encoder,
                          TransactionTemplate tx) {
        this.props = props;
        this.users = users;
        this.jdbc = jdbc;
        this.encoder = encoder;
        this.tx = tx;
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

        // ---- hospitals + departments
        UUID[] hospitalIds = new UUID[HOSPITALS.length];
        UUID[][] deptIds = new UUID[HOSPITALS.length][];
        for (int i = 0; i < HOSPITALS.length; i++) {
            Hosp h = HOSPITALS[i];
            hospitalIds[i] = UUID.randomUUID();
            jdbc.sql("""
                    INSERT INTO hospitals (id, name, name_latin, address, city, phone, latitude, longitude, is_demo,
                                           photo_url, opening_hours, created_at)
                    VALUES (:id, :n, :nl, :a, :c, :p, :la, :lo, TRUE, :ph, :oh, :now)""")
                    .param("id", hospitalIds[i]).param("n", h.km()).param("nl", h.latin()).param("a", h.address())
                    .param("c", h.city()).param("p", h.phone()).param("la", h.lat()).param("lo", h.lon())
                    .param("ph", "/media/hospitals/h" + (i + 1) + ".jpg").param("oh", h.hours())
                    .param("now", Sql.ts(now)).update();
            deptIds[i] = new UUID[DEPARTMENTS.length];
            for (int d = 0; d < DEPARTMENTS.length; d++) {
                if ((i + d) % 2 != 0 && d > 1) continue; // vary the departments per hospital
                deptIds[i][d] = UUID.randomUUID();
                jdbc.sql("INSERT INTO hospital_departments (id, hospital_id, name) VALUES (:id, :h, :n)")
                        .param("id", deptIds[i][d]).param("h", hospitalIds[i]).param("n", DEPARTMENTS[d]).update();
            }
        }

        // ---- doctors
        UUID[] doctorProfileIds = new UUID[DOCTORS.length];
        UUID[] doctorUserIds = new UUID[DOCTORS.length];
        for (int i = 0; i < DOCTORS.length; i++) {
            Doc d = DOCTORS[i];
            doctorUserIds[i] = users.insertUser(d.email(), hash, d.km(), null, "DOCTOR");
            doctorProfileIds[i] = UUID.randomUUID();
            String bioKm = "វេជ្ជបណ្ឌិតឯកទេស" + d.specKm() + " មានបទពិសោធន៍ " + d.years()
                    + " ឆ្នាំ។ នេះជាប្រវត្តិរូបគំរូសម្រាប់បង្ហាញកម្មវិធីប៉ុណ្ណោះ មិនមែនជាគ្រូពេទ្យពិតប្រាកដទេ។";
            String bioEn = d.specEn() + " specialist with " + d.years()
                    + " years of (fictional) experience. Sample profile for demonstration only - not a real clinician.";
            jdbc.sql("""
                    INSERT INTO doctor_profiles (id, user_id, specialty, specialty_km, name_latin, bio, bio_en,
                                                 verification_status, is_demo, photo_url, years_experience, languages,
                                                 created_at)
                    VALUES (:id, :u, :s, :sk, :nl, :b, :be, 'UNVERIFIED', TRUE, :ph, :y, :l, :now)""")
                    .param("id", doctorProfileIds[i]).param("u", doctorUserIds[i]).param("s", d.specEn())
                    .param("sk", d.specKm()).param("nl", d.latin()).param("b", bioKm).param("be", bioEn)
                    .param("ph", String.format("/media/doctors/d%02d.jpg", i + 1)).param("y", d.years())
                    .param("l", d.langs()).param("now", Sql.ts(now)).update();
            UUID dep = deptIds[d.hospital()][i % 2 == 0 ? 0 : 1];
            jdbc.sql("INSERT INTO doctor_hospital_affiliations (doctor_id, hospital_id, department_id) VALUES (:d, :h, :dep)")
                    .param("d", doctorProfileIds[i]).param("h", hospitalIds[d.hospital()]).param("dep", dep).update();
            // Mon-Fri; alternate morning / afternoon blocks so the directory shows varied availability
            LocalTime start = i % 3 == 0 ? LocalTime.of(9, 0) : (i % 3 == 1 ? LocalTime.of(13, 30) : LocalTime.of(8, 0));
            LocalTime end = start.plusHours(i % 3 == 2 ? 4 : 3);
            for (int dow = 1; dow <= 5; dow++) {
                jdbc.sql("""
                        INSERT INTO doctor_availability (id, doctor_id, day_of_week, start_time, end_time, slot_minutes)
                        VALUES (:id, :d, :dow, :s, :e, 30)""")
                        .param("id", UUID.randomUUID()).param("d", doctorProfileIds[i]).param("dow", dow)
                        .param("s", java.sql.Time.valueOf(start)).param("e", java.sql.Time.valueOf(end)).update();
            }
        }

        // ---- staff and admin
        UUID staffUser = users.insertUser(STAFF, hash, "ប៊ុន សុផល", "+855000000020", "HOSPITAL_STAFF");
        jdbc.sql("INSERT INTO hospital_staff (user_id, hospital_id) VALUES (:u, :h)").param("u", staffUser)
                .param("h", hospitalIds[0]).update();
        users.insertUser(ADMIN, hash, "អ៊ឹម សុភាព", null, "SYSTEM_ADMIN");

        // ---- patient with a realistic history
        UUID patientUser = users.insertUser(PATIENT, hash, "ស៊ុន ចាន់ថា", "+855000000010", "PATIENT");
        UUID patient = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO patient_profiles (id, user_id, date_of_birth, gender, blood_group, allergies, conditions,
                                              address, created_at, updated_at)
                VALUES (:id, :u, DATE '1992-04-17', 'FEMALE', 'O+', :al, :co, :ad, :n, :n)""")
                .param("id", patient).param("u", patientUser)
                .param("al", "ប៉េនីស៊ីលីន (គំរូ) / Penicillin (sample data)")
                .param("co", "សម្ពាធឈាមខ្ពស់កម្រិតស្រាល (គំរូ) / Mild hypertension (sample data)")
                .param("ad", "ភ្នំពេញ / Phnom Penh").param("n", Sql.ts(now)).update();

        contact(patient, "ស៊ុន សុខា", "ម្តាយ · Mother", "+855000000031", 1, now);
        contact(patient, "ជា ដារ៉ែន", "ប្តី · Spouse", "+855000000032", 2, now);

        // appointments: one finished, one confirmed in the near future, one waiting for confirmation
        appointment(patient, doctorProfileIds[0], hospitalIds[0], now.minus(Duration.ofDays(21)), "COMPLETED",
                "ពិនិត្យសម្ពាធឈាម / Blood-pressure check", false, now);
        appointment(patient, doctorProfileIds[0], hospitalIds[0], nextSlot(now, 2, 9, 30), "CONFIRMED",
                "តាមដានការព្យាបាល / Follow-up visit", true, now);
        appointment(patient, doctorProfileIds[2], hospitalIds[0], nextSlot(now, 4, 10, 0), "REQUESTED",
                "ពិនិត្យសុខភាពទូទៅ / General check-up", true, now);

        // records: clinician-authored + patient-authored
        record(patient, doctorUserIds[0], "CLINICIAN", "CLINICAL_NOTE", "ការពិនិត្យសម្ពាធឈាម · Blood pressure review",
                "Diagnosis: mild hypertension (sample)\nMedication: Amlodipine 5 mg once daily (sample)\n"
                        + "Allergy: Penicillin\nPlan: reduce salt, walk 30 minutes daily, review in 3 months.",
                now.minus(Duration.ofDays(21)));
        record(patient, doctorUserIds[0], "CLINICIAN", "TEST_REPORT", "លទ្ធផលពិនិត្យឈាម · Blood test results",
                "Haemoglobin: 12.8 g/dL\nGlucose (fasting): 5.1 mmol/L\nCholesterol: 4.9 mmol/L\n"
                        + "Reported 2026-09-20 (sample data)",
                now.minus(Duration.ofDays(20)));
        record(patient, patientUser, "PATIENT", "HISTORY", "កំណត់ចំណាំរបស់ខ្ញុំ · My notes",
                "Allergy: Penicillin\nMedication: Vitamin D 1000 IU\nHeadache sometimes in the evening, improves with rest.",
                now.minus(Duration.ofDays(5)));

        // medications + reminders
        UUID amlo = medication(patient, "Amlodipine", "5 mg", "ថ្ងៃម្តង ពេលព្រឹក / once daily in the morning",
                "PRESCRIPTION", now);
        UUID vitD = medication(patient, "Vitamin D", "1000 IU", "ក្រោយអាហារ / after a meal", "USER_ENTERED", now);
        reminder(amlo, LocalTime.of(7, 30), now);
        reminder(vitD, LocalTime.of(20, 0), now);

        // one finished demonstration emergency with a full timeline
        finishedEmergency(patient, patientUser, staffUser, hospitalIds[0], now.minus(Duration.ofDays(3)));

        // notification inbox
        notification(patientUser, "APPOINTMENT_CONFIRMED", "ការណាត់ជួបត្រូវបានបញ្ជាក់ · Appointment confirmed",
                "វេជ្ជបណ្ឌិតបានបញ្ជាក់ការណាត់ជួបរបស់អ្នក។", now.minus(Duration.ofHours(6)));
        notification(patientUser, "MEDICATION_REMINDER", "ការរំលឹកថ្នាំ · Medication reminder",
                "ដល់ពេលលេបថ្នាំហើយ។", now.minus(Duration.ofHours(30)));
        log.info("Demo data seeded: {} hospitals, {} doctors (fictional, Khmer/Latin)", HOSPITALS.length, DOCTORS.length);
    }

    // ------------------------------------------------------------------ helpers

    private Instant nextSlot(Instant from, int daysAhead, int hour, int minute) {
        LocalDate date = from.atZone(DirectoryService.CLINIC_ZONE).toLocalDate().plusDays(daysAhead);
        while (date.getDayOfWeek().getValue() > 5) date = date.plusDays(1); // working days only
        return date.atTime(hour, minute).atZone(DirectoryService.CLINIC_ZONE).toInstant();
    }

    private void contact(UUID patient, String name, String relation, String phone, int priority, Instant now) {
        jdbc.sql("""
                INSERT INTO emergency_contacts (id, patient_id, name, relationship, phone, priority, created_at)
                VALUES (:id, :p, :n, :r, :ph, :pr, :now)""").param("id", UUID.randomUUID()).param("p", patient)
                .param("n", name).param("r", relation).param("ph", phone).param("pr", priority)
                .param("now", Sql.ts(now)).update();
    }

    private void appointment(UUID patient, UUID doctor, UUID hospital, Instant start, String status, String reason,
                             boolean active, Instant now) {
        jdbc.sql("""
                INSERT INTO appointments (id, patient_id, doctor_id, hospital_id, starts_at, ends_at, status, reason,
                                          slot_key, created_at, updated_at)
                VALUES (:id, :p, :d, :h, :s, :e, :st, :r, :k, :now, :now)""")
                .param("id", UUID.randomUUID()).param("p", patient).param("d", doctor).param("h", hospital)
                .param("s", Sql.ts(start)).param("e", Sql.ts(start.plus(Duration.ofMinutes(30)))).param("st", status)
                .param("r", reason).param("k", active ? doctor + "|" + start.getEpochSecond() : null)
                .param("now", Sql.ts(now)).update();
    }

    private void record(UUID patient, UUID author, String kind, String type, String title, String body, Instant at) {
        jdbc.sql("""
                INSERT INTO medical_records (id, patient_id, author_user_id, author_kind, record_type, title, body,
                                             created_at)
                VALUES (:id, :p, :a, :k, :t, :ti, :b, :at)""").param("id", UUID.randomUUID()).param("p", patient)
                .param("a", author).param("k", kind).param("t", type).param("ti", title).param("b", body)
                .param("at", Sql.ts(at)).update();
    }

    private UUID medication(UUID patient, String name, String dose, String instructions, String source, Instant now) {
        UUID id = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO medications (id, patient_id, name, dosage, instructions, source, created_at)
                VALUES (:id, :p, :n, :d, :i, :s, :now)""").param("id", id).param("p", patient).param("n", name)
                .param("d", dose).param("i", instructions).param("s", source).param("now", Sql.ts(now)).update();
        return id;
    }

    private void reminder(UUID medication, LocalTime time, Instant now) {
        jdbc.sql("""
                INSERT INTO medication_reminders (id, medication_id, time_of_day, timezone, start_date, active, created_at)
                VALUES (:id, :m, :t, 'Asia/Phnom_Penh', :sd, TRUE, :now)""").param("id", UUID.randomUUID())
                .param("m", medication).param("t", java.sql.Time.valueOf(time))
                .param("sd", java.sql.Date.valueOf(LocalDate.now().minusDays(14))).param("now", Sql.ts(now)).update();
    }

    private void finishedEmergency(UUID patient, UUID patientUser, UUID staff, UUID hospital, Instant created) {
        UUID id = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO emergency_events (id, patient_id, hospital_id, status, trigger_source, description,
                                              idempotency_key, is_demo, acknowledged_by, created_at, updated_at)
                VALUES (:id, :p, :h, 'RESOLVED', 'DEMO', 'Demonstration event (seed data)', :k, TRUE, :s, :c, :u)""")
                .param("id", id).param("p", patient).param("h", hospital).param("k", "seed-" + id)
                .param("s", staff).param("c", Sql.ts(created)).param("u", Sql.ts(created.plusSeconds(1500))).update();
        jdbc.sql("""
                INSERT INTO emergency_event_locations (id, event_id, latitude, longitude, accuracy_m, captured_at)
                VALUES (:id, :e, 11.5564, 104.9282, 15, :c)""").param("id", UUID.randomUUID()).param("e", id)
                .param("c", Sql.ts(created)).update();
        String[][] steps = {{null, "CREATED"}, {"CREATED", "SUBMITTED"}, {"SUBMITTED", "ACKNOWLEDGED"},
                {"ACKNOWLEDGED", "RESPONDER_ASSIGNED"}, {"RESPONDER_ASSIGNED", "RESPONDER_EN_ROUTE"},
                {"RESPONDER_EN_ROUTE", "ARRIVED"}, {"ARRIVED", "RESOLVED"}};
        for (int i = 0; i < steps.length; i++) {
            jdbc.sql("""
                    INSERT INTO emergency_event_history (id, event_id, from_status, to_status, actor_id, note, created_at)
                    VALUES (:id, :e, :f, :t, :a, :n, :at)""").param("id", UUID.randomUUID()).param("e", id)
                    .param("f", steps[i][0]).param("t", steps[i][1]).param("a", i >= 2 ? staff : patientUser)
                    .param("n", i == 0 ? "Event persisted (seed data)" : null)
                    .param("at", Sql.ts(created.plusSeconds(i * 240L))).update();
        }
    }

    private void notification(UUID user, String category, String title, String body, Instant at) {
        jdbc.sql("""
                INSERT INTO notifications (id, user_id, category, title, body, created_at)
                VALUES (:id, :u, :c, :t, :b, :at)""").param("id", UUID.randomUUID()).param("u", user)
                .param("c", category).param("t", title).param("b", body).param("at", Sql.ts(at)).update();
    }
}
