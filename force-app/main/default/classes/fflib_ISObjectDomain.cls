// Sourced from fflib-apex-common (MIT License). Inlined to avoid package dependency on Developer Edition.
// https://github.com/apex-enterprise-patterns/fflib-apex-common
public interface fflib_ISObjectDomain {
    void handleBeforeInsert();
    void handleAfterInsert();
    void handleBeforeUpdate(Map<Id, SObject> existingRecords);
    void handleAfterUpdate(Map<Id, SObject> existingRecords);
    void handleBeforeDelete();
    void handleAfterDelete();
    void handleAfterUndelete();
}
