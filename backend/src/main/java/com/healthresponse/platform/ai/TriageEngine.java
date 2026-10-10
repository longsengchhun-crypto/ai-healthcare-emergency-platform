package com.healthresponse.platform.ai;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * Deterministic, documented red-flag triage rules. This is NOT a language model and NOT a diagnosis:
 * safety-critical recognition never depends on an LLM. Any red-flag match yields EMERGENCY immediately.
 * Rules are intentionally conservative (over-triage is preferred to under-triage). English only; see
 * docs/AI_DOCUMENTATION.md for limitations.
 */
@Component
public class TriageEngine {
    public enum Urgency { EMERGENCY, URGENT, ROUTINE, UNCERTAIN }

    public record Rule(String id, String description, Pattern pattern) {}
    public record Result(Urgency urgency, List<String> matchedRules, String guidance, boolean emergencyActionRecommended,
                         List<String> followUpQuestions, String disclaimer) {}

    public static final String DISCLAIMER =
            "This is informational preliminary triage support, not a diagnosis and not a substitute for a qualified "
            + "medical professional. If you think this may be an emergency, use emergency services now.";

    private static Pattern p(String regex) { return Pattern.compile(regex, Pattern.CASE_INSENSITIVE); }

    static final List<Rule> RED_FLAGS = List.of(
            new Rule("CHEST_PAIN", "Chest pain/pressure/tightness", p("chest\\s+(pain|pressure|tight\\w*)|pain\\s+in\\s+(my\\s+)?chest|heart\\s+attack")),
            new Rule("BREATHING", "Severe breathing difficulty", p("(can'?t|cannot|unable to|hard to|trouble|difficulty)\\s+(breath\\w*)|short(ness)?\\s+of\\s+breath|struggling to breathe|choking")),
            new Rule("STROKE", "Stroke signs", p("face\\s+drooping|slurred\\s+speech|sudden\\s+(weakness|numbness)|one\\s+side.*(weak|numb|paraly)|stroke")),
            new Rule("UNCONSCIOUS", "Unconscious / unresponsive / seizure", p("unconscious|unresponsive|passed\\s+out|not\\s+(waking|responding)|seizure|convuls\\w*|fainted")),
            new Rule("BLEEDING", "Severe bleeding", p("(severe|heavy|uncontrolled|won'?t stop)\\s+bleed\\w*|bleeding\\s+(heavily|badly|a lot)|coughing\\s+(up\\s+)?blood|vomiting\\s+blood")),
            new Rule("SUICIDE", "Self-harm / suicidal intent", p("suicid\\w*|kill\\s+myself|end\\s+my\\s+life|want\\s+to\\s+die|self[- ]harm")),
            new Rule("ANAPHYLAXIS", "Severe allergic reaction", p("anaphyla\\w*|throat\\s+(is\\s+)?(closing|swelling)|swollen\\s+(tongue|throat|lips).*(breath|allerg)")),
            new Rule("POISON", "Poisoning / overdose", p("overdos\\w*|poison\\w*|swallowed\\s+(bleach|chemical|pills)")),
            new Rule("HEAD_INJURY", "Serious head injury / accident", p("head\\s+injury.*(vomit|confus|drows)|serious\\s+(accident|crash)|hit\\s+by\\s+a\\s+(car|vehicle)"))
    );

    static final List<Rule> URGENT_FLAGS = List.of(
            new Rule("HIGH_FEVER", "High or persistent fever", p("fever.*(3\\s*days|three\\s*days|40\\s*°?c|104)|high\\s+fever|temperature.*(40|104)")),
            new Rule("PERSISTENT_VOMITING", "Persistent vomiting / dehydration", p("(can'?t|cannot)\\s+keep\\s+(food|water|fluids)\\s+down|vomiting\\s+(for|since).*(day|days)|dehydrat\\w*")),
            new Rule("SEVERE_PAIN", "Severe pain", p("(severe|worst|unbearable|intense)\\s+(pain|headache|stomach\\s+ache|abdominal)")),
            new Rule("PREGNANCY", "Pregnancy-related concern", p("pregnan\\w*.*(bleed|pain|cramp|dizz|reduced movement)")),
            new Rule("INFANT", "Unwell infant", p("(baby|infant|newborn).*(fever|not feeding|lethargic|limp|rash)"))
    );

    public Result assess(String symptoms) {
        String text = symptoms == null ? "" : symptoms.toLowerCase(Locale.ROOT).trim();
        List<String> red = match(RED_FLAGS, text);
        if (!red.isEmpty()) {
            return new Result(Urgency.EMERGENCY, red,
                    "These symptoms can be life-threatening. Use the Emergency button or call your local emergency "
                            + "number now. Do not wait for further questions.", true, List.of(), DISCLAIMER);
        }
        List<String> urgent = match(URGENT_FLAGS, text);
        if (!urgent.isEmpty()) {
            return new Result(Urgency.URGENT, urgent,
                    "Please seek in-person medical evaluation today. If symptoms get worse or you feel unsafe, treat it as an emergency.",
                    false, List.of("How long have the symptoms lasted?", "Are they getting worse?"), DISCLAIMER);
        }
        if (text.length() < 8) {
            return new Result(Urgency.UNCERTAIN, List.of(),
                    "I need a little more detail. Please describe your main symptom, when it started, and how severe it is.",
                    false, List.of("What is the main symptom?", "When did it start?", "How severe is it from 1 to 10?"), DISCLAIMER);
        }
        // Absence of a matched rule is never reassurance: the engine cannot rule anything out.
        return new Result(Urgency.ROUTINE, List.of(),
                "No emergency warning signs were recognised in what you wrote, but this tool cannot rule out a serious "
                        + "problem. Consider booking an appointment with a qualified clinician, and seek urgent care if "
                        + "things worsen or you are worried.", false,
                List.of("Do you have chest pain, trouble breathing, or confusion?", "How long has this been going on?"), DISCLAIMER);
    }

    private List<String> match(List<Rule> rules, String text) {
        List<String> out = new ArrayList<>();
        for (Rule r : rules) if (r.pattern().matcher(text).find()) out.add(r.id());
        return out;
    }
}
