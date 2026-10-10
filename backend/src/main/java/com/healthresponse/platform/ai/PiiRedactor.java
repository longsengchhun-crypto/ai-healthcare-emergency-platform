package com.healthresponse.platform.ai;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Best-effort removal of direct identifiers before text leaves the application. It removes e-mail addresses, URLs,
 * phone-like numbers, long identifier numbers and labelled identity lines (Name:, DOB:, Address: ...).
 * It CANNOT find a person's name or address written inside ordinary sentences; docs/AI_DOCUMENTATION.md states this.
 */
public final class PiiRedactor {
    private PiiRedactor() {}

    private static final Pattern EMAIL = Pattern.compile("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}");
    private static final Pattern URL = Pattern.compile("(?i)\\b(?:https?://|www\\.)\\S+");
    private static final Pattern PHONE = Pattern.compile("(?<![\\w])\\+?\\d[\\d\\s().-]{7,}\\d(?![\\w])");
    private static final Pattern LONG_ID = Pattern.compile("\\b[A-Za-z]{0,4}\\d{6,}\\b");
    private static final Pattern DATE_LIKE = Pattern.compile("^\\d{4}-\\d{1,2}-\\d{1,2}$|^\\d{1,2}[/.-]\\d{1,2}[/.-]\\d{2,4}$");
    private static final Pattern LABELLED = Pattern.compile(
            "(?im)^(\\s*(?:patient\\s+)?(?:full\\s+)?(?:name|patient|dob|date\\s+of\\s+birth|address|phone|tel|mobile|"
                    + "e-?mail|nid|national\\s+id|passport|insurance(?:\\s+no\\.?)?|mrn|id\\s*(?:no\\.?|number)?)\\s*[:\\-]\\s*)[^\\n]+?(?=\\.\\s|$)");

    public static String redact(String text) {
        if (text == null || text.isEmpty()) return "";
        String t = LABELLED.matcher(text).replaceAll("$1[REDACTED]");
        t = EMAIL.matcher(t).replaceAll("[EMAIL]");
        t = URL.matcher(t).replaceAll("[LINK]");
        t = replacePhones(t);
        t = LONG_ID.matcher(t).replaceAll("[ID]");
        return t;
    }

    private static String replacePhones(String t) {
        Matcher m = PHONE.matcher(t);
        StringBuilder out = new StringBuilder();
        while (m.find()) {
            String g = m.group();
            long digits = g.chars().filter(Character::isDigit).count();
            String rep = (digits >= 8 && !DATE_LIKE.matcher(g.trim()).matches()) ? "[PHONE]" : g;
            m.appendReplacement(out, Matcher.quoteReplacement(rep));
        }
        m.appendTail(out);
        return out.toString();
    }
}
