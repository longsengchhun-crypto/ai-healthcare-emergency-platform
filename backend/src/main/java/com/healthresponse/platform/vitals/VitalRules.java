package com.healthresponse.platform.vitals;

import java.util.Map;
import java.util.Set;

/**
 * Plausibility limits (to catch typos) and general adult reference bands (to give the user a quiet heads-up).
 * This is information, not a diagnosis: the app never tells anyone they have a condition.
 */
final class VitalRules {
    private VitalRules() {}

    static final Set<String> TYPES = Set.of("BLOOD_PRESSURE", "HEART_RATE", "BLOOD_GLUCOSE", "WEIGHT",
            "TEMPERATURE", "OXYGEN_SATURATION");

    /** Units are fixed per type so a chart never mixes scales. */
    static final Map<String, String> UNITS = Map.of(
            "BLOOD_PRESSURE", "mmHg", "HEART_RATE", "bpm", "BLOOD_GLUCOSE", "mg/dL", "WEIGHT", "kg",
            "TEMPERATURE", "°C", "OXYGEN_SATURATION", "%");

    record Assessment(String level, String code) {}

    static final Assessment NORMAL = new Assessment("NORMAL", "WITHIN_TYPICAL");

    /** @return an error message when the numbers are impossible, otherwise null. */
    static String implausible(String type, double v1, Double v2) {
        return switch (type) {
            case "BLOOD_PRESSURE" -> {
                if (v2 == null) yield "Blood pressure needs both numbers (systolic and diastolic)";
                if (v1 < 50 || v1 > 300 || v2 < 30 || v2 > 200) yield "Blood pressure is outside a possible range";
                yield v1 <= v2 ? "The top number (systolic) must be higher than the bottom number" : null;
            }
            case "HEART_RATE" -> v1 < 20 || v1 > 250 ? "Heart rate is outside a possible range" : null;
            case "BLOOD_GLUCOSE" -> v1 < 20 || v1 > 800 ? "Blood glucose is outside a possible range (mg/dL)" : null;
            case "WEIGHT" -> v1 < 2 || v1 > 400 ? "Weight is outside a possible range (kg)" : null;
            case "TEMPERATURE" -> v1 < 30 || v1 > 45 ? "Temperature is outside a possible range (°C)" : null;
            case "OXYGEN_SATURATION" -> v1 < 50 || v1 > 100 ? "Oxygen saturation must be between 50 and 100 %" : null;
            default -> "Unknown measurement type";
        };
    }

    static Assessment assess(String type, double v1, Double v2) {
        return switch (type) {
            case "BLOOD_PRESSURE" -> {
                double d = v2 == null ? 0 : v2;
                if (v1 >= 180 || d >= 120) yield new Assessment("URGENT", "BP_VERY_HIGH");
                if (v1 < 90 || d < 60) yield new Assessment("ATTENTION", "BP_LOW");
                if (v1 >= 130 || d >= 80) yield new Assessment("ATTENTION", "BP_HIGH");
                yield NORMAL;
            }
            case "HEART_RATE" -> {
                if (v1 > 150 || v1 < 40) yield new Assessment("URGENT", "HR_EXTREME");
                if (v1 > 100) yield new Assessment("ATTENTION", "HR_HIGH");
                if (v1 < 50) yield new Assessment("ATTENTION", "HR_LOW");
                yield NORMAL;
            }
            case "BLOOD_GLUCOSE" -> {
                if (v1 < 54 || v1 >= 300) yield new Assessment("URGENT", v1 < 54 ? "GLUCOSE_VERY_LOW" : "GLUCOSE_VERY_HIGH");
                if (v1 < 70) yield new Assessment("ATTENTION", "GLUCOSE_LOW");
                if (v1 > 180) yield new Assessment("ATTENTION", "GLUCOSE_HIGH");
                yield NORMAL;
            }
            case "TEMPERATURE" -> {
                if (v1 >= 39.5) yield new Assessment("URGENT", "TEMP_VERY_HIGH");
                if (v1 >= 38.0) yield new Assessment("ATTENTION", "TEMP_FEVER");
                if (v1 < 35.0) yield new Assessment("ATTENTION", "TEMP_LOW");
                yield NORMAL;
            }
            case "OXYGEN_SATURATION" -> {
                if (v1 < 90) yield new Assessment("URGENT", "SPO2_VERY_LOW");
                if (v1 < 95) yield new Assessment("ATTENTION", "SPO2_LOW");
                yield NORMAL;
            }
            default -> new Assessment("RECORDED", "NO_REFERENCE"); // weight: no band without height/age
        };
    }
}
