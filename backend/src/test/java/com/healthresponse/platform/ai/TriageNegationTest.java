package com.healthresponse.platform.ai;

import static org.assertj.core.api.Assertions.assertThat;

import com.healthresponse.platform.ai.TriageEngine.Urgency;
import java.util.List;
import org.junit.jupiter.api.Test;

/** The negation guard may only remove plain, explicit denials; anything doubtful must still be an emergency. */
class TriageNegationTest {
    final TriageEngine engine = new TriageEngine();

    Urgency u(String s) { return engine.assess(s).urgency(); }

    @Test
    void plainDenialsAreNotTreatedAsSymptoms() {
        for (String s : List.of(
                "no chest pain, just a cough",
                "I do not have trouble breathing",
                "I don't have any chest pain",
                "without chest pain or breathing problems, only a sore throat",
                "denies chest pain")) {
            assertThat(u(s)).as(s).isNotEqualTo(Urgency.EMERGENCY);
        }
        assertThat(engine.assessDetailed("no chest pain, just a cough").negatedRules()).contains("CHEST_PAIN");
    }

    @Test
    void anyDoubtOrReversalKeepsTheEmergency() {
        for (String s : List.of(
                "no chest pain but I can't breathe",
                "no chest pain, my father is unconscious",
                "I don't have chest pain anymore but it was crushing",
                "I had no chest pain before, now I do have chest pain",
                "not sure if it is chest pain",
                "no relief of chest pain",
                "I have chest pain. no fever",
                "know chest pain well, I have it now",
                "chest pain and no cough")) {
            assertThat(u(s)).as(s).isEqualTo(Urgency.EMERGENCY);
        }
    }

    @Test
    void anOccurrenceThatIsNotDeniedStillFires() {
        assertThat(u("no chest pain this morning. chest pain again tonight")).isEqualTo(Urgency.EMERGENCY);
    }
}
