public with sharing class LeadSubmissionEventDomain extends fflib_SObjectDomain {
  // Allows tests to override the CMT kill-switch check without DML on CMT records.
  @TestVisible
  private static Boolean overrideActive;

  public LeadSubmissionEventDomain(List<LeadSubmission__e> events) {
    super(events);
  }

  public override void onAfterInsert() {
    if (!isTriggerActive()) {
      return;
    }
    enqueueEnrichment();
  }

  private Boolean isTriggerActive() {
    if (Test.isRunningTest() && overrideActive != null) {
      return overrideActive;
    }
    List<Trigger_Control__mdt> controls = [
      SELECT Is_Active__c
      FROM Trigger_Control__mdt
      WHERE Object_Name__c = 'LeadSubmission__e'
      WITH SECURITY_ENFORCED
      LIMIT 1
    ];
    // Fail-open: absence of a CMT record means no kill switch is configured
    return controls.isEmpty() || controls[0].Is_Active__c;
  }

  private void enqueueEnrichment() {
    Set<Id> leadIds = new Set<Id>();
    for (LeadSubmission__e evt : (List<LeadSubmission__e>) Records) {
      if (String.isBlank(evt.Lead_ID__c)) {
        continue;
      }
      try {
        leadIds.add((Id) evt.Lead_ID__c);
      } catch (Exception e) {
        ErrorLogger.create()
          .source(ErrorLogger.Source.PLATFORM_EVENT)
          .category(ErrorLogger.Category.VALIDATION)
          .severity(ErrorLogger.Severity.LOW)
          .className('LeadSubmissionEventDomain')
          .methodName('enqueueEnrichment')
          .message('Invalid Lead ID on event: ' + evt.Lead_ID__c)
          .log();
      }
    }

    if (leadIds.isEmpty()) {
      return;
    }

    try {
      System.enqueueJob(new LeadEnrichmentQueueable(leadIds));
    } catch (Exception e) {
      ErrorLogger.create()
        .source(ErrorLogger.Source.PLATFORM_EVENT)
        .category(ErrorLogger.Category.BUSINESS_RULE)
        .severity(ErrorLogger.Severity.HIGH)
        .className('LeadSubmissionEventDomain')
        .methodName('enqueueEnrichment')
        .message('Failed to enqueue LeadEnrichmentQueueable: ' + e.getMessage())
        .log();
    }
  }

  public class Constructor implements fflib_SObjectDomain.IConstructable {
    public fflib_SObjectDomain construct(List<SObject> sObjectList) {
      return new LeadSubmissionEventDomain(sObjectList);
    }
  }
}
