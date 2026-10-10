package com.healthresponse.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.healthresponse.platform.ai.TriageEngine;
import com.healthresponse.platform.ai.TriageEngine.Urgency;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * Measures the deterministic triage rules on a small hand-written fixture and writes the real numbers to
 * target/ai-evaluation.txt. This is NOT clinical validation: the fixture is tiny, written by the developers,
 * English-only, and the rules were authored with similar phrasing in mind (optimistic bias).
 */
class AiEvaluationTest {
    record Case(String text, boolean emergency) {}

    static final List<Case> CASES = List.of(
            new Case("I have crushing chest pain spreading to my arm", true),
            new Case("chest tightness and sweating", true),
            new Case("I think I'm having a heart attack", true),
            new Case("my dad cannot breathe and his lips are blue", true),
            new Case("shortness of breath at rest, getting worse", true),
            new Case("she is struggling to breathe", true),
            new Case("face drooping and slurred speech this morning", true),
            new Case("sudden weakness on one side of the body", true),
            new Case("my son is unconscious after the fall", true),
            new Case("he had a seizure and is not waking up", true),
            new Case("severe bleeding from a deep cut that won't stop", true),
            new Case("I am vomiting blood", true),
            new Case("I want to kill myself", true),
            new Case("thinking about suicide tonight", true),
            new Case("throat is closing after eating peanuts, anaphylaxis", true),
            new Case("he swallowed bleach", true),
            new Case("I took an overdose of tablets", true),
            new Case("hit by a car on the highway", true),
            new Case("coughing up blood for two days", true),
            new Case("my baby passed out and is limp", true),
            // non-emergencies
            new Case("mild runny nose since yesterday", false),
            new Case("sore throat and a slight cough", false),
            new Case("I have a headache after a long day", false),
            new Case("skin rash on my arm that itches", false),
            new Case("lower back ache after gardening", false),
            new Case("need a repeat of my blood pressure tablets", false),
            new Case("feeling tired for the last week", false),
            new Case("small cut on my finger, bleeding stopped", false),
            new Case("stomach is upset after lunch", false),
            new Case("knee pain when climbing stairs", false),
            new Case("trouble sleeping lately", false),
            new Case("seasonal allergies, sneezing", false),
            new Case("my toddler has a mild cold", false),
            new Case("constipation for three days", false),
            new Case("itchy eyes", false),
            // known hard negatives: negated red-flag phrases (rules do not handle negation -> expected false positives)
            new Case("no chest pain, just a cough", false),
            new Case("I do not have trouble breathing", false));

    @Test
    void measureTriageRules() throws Exception {
        TriageEngine engine = new TriageEngine();
        int tp = 0, fn = 0, fp = 0, tn = 0;
        List<String> missed = new ArrayList<>();
        List<String> falseAlarms = new ArrayList<>();
        for (Case c : CASES) {
            boolean predicted = engine.assess(c.text()).urgency() == Urgency.EMERGENCY;
            if (c.emergency() && predicted) tp++;
            else if (c.emergency()) { fn++; missed.add(c.text()); }
            else if (predicted) { fp++; falseAlarms.add(c.text()); }
            else tn++;
        }
        double sensitivity = tp / (double) (tp + fn);
        double specificity = tn / (double) (tn + fp);
        String report = """
                Triage rule evaluation (n=%d, emergencies=%d, non-emergencies=%d)
                TP=%d FN=%d FP=%d TN=%d
                Sensitivity (emergency recall) = %.3f
                Specificity = %.3f
                Missed emergencies: %s
                False alarms: %s
                """.formatted(CASES.size(), tp + fn, tn + fp, tp, fn, fp, tn, sensitivity, specificity, missed, falseAlarms);
        Path out = Path.of("target", "ai-evaluation.txt");
        Files.createDirectories(out.getParent());
        Files.writeString(out, report);
        System.out.println(report);
        // Safety bar for this fixture: no missed emergencies.
        assertThat(fn).as("missed emergencies: %s", missed).isZero();
    }
}
