package com.healthresponse.platform.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthresponse.platform.ai.LlmClient.LlmException;
import com.healthresponse.platform.ai.LlmClient.LlmException.Kind;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Validation of everything the model returns. Model output is untrusted: it is parsed strictly, length-limited and
 * rejected (never "repaired") when it contains medication dosing, diagnosis claims, or false reassurance. A rejection
 * is handled exactly like a provider failure, so the user gets the deterministic result instead.
 */
final class OutputGuard {
    private OutputGuard() {}

    static final ObjectMapper JSON = new ObjectMapper();

    private static final Pattern DOSE = Pattern.compile("(?i)\\b\\d+(?:\\.\\d+)?\\s?(?:mg|mcg|µg|ml|iu|units?|tablets?|pills?|capsules?)\\b");
    private static final String COND = "(?:heart attack|stroke|cancer|pneumonia|covid(?:-19)?|infection|appendicitis|diabetes"
            + "|asthma|tumou?r|meningitis|sepsis|embolism|hypertension|migraine|anaemia|anemia|[a-z]+itis|[a-z]+osis"
            + "|[a-z]+aemia|[a-z]+emia|disease|syndrome|disorder)";
    // Only an explicit assertion of a named condition counts ("you have pneumonia"); hedged wording such as "can be
    // associated with" and ordinary phrases like "whether you have other symptoms" are fine.
    // Questions ("Do you have asthma?") are stripped first, and a negated object ("you have no infection") is skipped.
    private static final Pattern QUESTION = Pattern.compile("[^.!?\\n]*\\?");
    private static final Pattern DIAGNOSIS = Pattern.compile(
            "(?i)\\byou (?:definitely |probably |likely |most likely |certainly )?(?:have|are suffering from|are diagnosed with|'ve got)"
                    + "\\s+(?!(?:no|not|any|without|never|had)\\b)(?:a |an |the )?(?:[a-z-]+ ){0,2}?" + COND + "\\b"
                    + "|\\b(?:this is|it is|it's) (?:definitely |probably |likely )?(?:a |an )?" + COND + "\\b");
    private static final Pattern PRESCRIBE = Pattern.compile("(?i)\\b(?:i prescribe|take (?:\\d|one|two|an?) |you should take (?:\\w+ )?(?:ibuprofen|paracetamol|aspirin|antibiotic|antibiotics))");
    private static final Pattern REASSURE = Pattern.compile(
            "(?i)\\bno need to (?:see|visit|seek|consult|worry)|\\bnothing to worry|\\bdon'?t need (?:to see|a doctor|medical)|\\bsafe to ignore|\\bdefinitely (?:not serious|fine)|\\bis not serious\\b");

    /** Strip an optional markdown fence and parse the first JSON object. */
    static JsonNode parseObject(String raw) {
        if (raw == null) throw bad("empty");
        int a = raw.indexOf('{');
        int b = raw.lastIndexOf('}');
        if (a < 0 || b <= a) throw bad("no json object");
        try {
            JsonNode n = JSON.readTree(raw.substring(a, b + 1));
            if (n == null || !n.isObject()) throw bad("not an object");
            return n;
        } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
            throw bad("invalid json");
        }
    }

    static LlmException bad(String why) { return new LlmException(Kind.BAD_OUTPUT, "Unusable AI output: " + why); }

    /** Throws BAD_OUTPUT when free text contains content the product must never present as AI guidance. */
    static String safeText(String s, int maxLen) { return safeText(s, maxLen, null); }

    /**
     * @param groundingSource when not null, a dose is allowed if it appears verbatim in this source text (a record
     *                        summary may restate "500mg" because the record says so; guidance may never invent one)
     */
    static String safeText(String s, int maxLen, String groundingSource) {
        if (s == null) throw bad("missing text");
        String t = s.strip();
        if (t.isEmpty() || t.length() > maxLen) throw bad("text length");
        java.util.regex.Matcher dm = DOSE.matcher(t);
        String src = groundingSource == null ? null : norm(groundingSource);
        while (dm.find()) {
            if (src == null || !src.contains(norm(dm.group()))) throw bad("dosage");
        }
        if (DIAGNOSIS.matcher(QUESTION.matcher(t).replaceAll(" ")).find()) throw bad("diagnosis claim");
        if (PRESCRIBE.matcher(t).find()) throw bad("prescription");
        if (REASSURE.matcher(t).find()) throw bad("false reassurance");
        if (t.chars().anyMatch(c -> c < 0x20 && c != '\n' && c != '\t')) throw bad("control characters");
        return t;
    }

    static List<String> safeList(JsonNode n, String field, int maxItems, int maxLen, boolean required) {
        JsonNode arr = n.get(field);
        if (arr == null || arr.isNull()) {
            if (required) throw bad("missing " + field);
            return List.of();
        }
        if (!arr.isArray() || arr.size() > maxItems) throw bad("bad " + field);
        List<String> out = new ArrayList<>();
        for (JsonNode e : arr) {
            if (!e.isTextual()) throw bad("non-text in " + field);
            out.add(safeText(e.asText(), maxLen));
        }
        if (required && out.isEmpty()) throw bad("empty " + field);
        return List.copyOf(out);
    }

    static String norm(String s) {
        return s == null ? "" : s.toLowerCase(Locale.ROOT).replaceAll("\\s+", " ").strip();
    }
}
