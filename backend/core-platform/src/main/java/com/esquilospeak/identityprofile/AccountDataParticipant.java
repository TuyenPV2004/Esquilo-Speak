package com.esquilospeak.identityprofile;

import java.util.Map;
import java.util.UUID;

public interface AccountDataParticipant {

    String dataDomain();

    Map<String, Object> exportData(UUID learnerId);

    void deleteData(UUID learnerId);
}
