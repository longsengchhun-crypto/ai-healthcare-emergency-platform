package com.healthresponse.platform.ai;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class PiiRedactorTest {
    @Test
    void removesDirectIdentifiersButKeepsClinicalContent() {
        String in = """
                Patient: Sok Dara
                DOB: 01/02/1980
                Address: 12 Street 51, Phnom Penh
                Contact sok@example.com or +855 12 345 678, see https://clinic.example/p/9
                National ID 123456789012
                Allergy: shellfish. Hemoglobin 13.2 g/dL on 2024-03-02, BP 120/80.""";
        String out = PiiRedactor.redact(in);
        assertThat(out).doesNotContain("Sok Dara").doesNotContain("01/02/1980").doesNotContain("Street 51")
                .doesNotContain("sok@example.com").doesNotContain("345 678").doesNotContain("clinic.example")
                .doesNotContain("123456789012");
        assertThat(out).contains("Allergy: shellfish").contains("13.2 g/dL").contains("2024-03-02").contains("120/80");
    }

    @Test
    void nullAndEmptyAreSafe() {
        assertThat(PiiRedactor.redact(null)).isEmpty();
        assertThat(PiiRedactor.redact("")).isEmpty();
    }
}
