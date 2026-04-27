/**
 * Subscriber domain for Error_Event__e. Inserts Error_Log__c records on behalf of
 * the publisher — the only viable write path from guest user contexts, since
 * Error_Log__c OWD is Private and post-Summer-'21 platform restrictions block
 * guest DML on private objects even with `without sharing` + SYSTEM_MODE.
 *
 * Trigger runs as the Automated Process user (full system context). Critically,
 * this class must NOT call ErrorLogger on its own DML failures — that would
 * republish Error_Event__e and create an infinite loop. Failures here fall
 * back to System.debug only.
 */
public with sharing class ErrorEventDomain extends fflib_SObjectDomain {
  @TestVisible
  private static Boolean overrideActive;

  public ErrorEventDomain(List<Error_Event__e> events) {
    super(events);
  }

  public override void onAfterInsert() {
    if (!isTriggerActive()) {
      return;
    }
    writeLogs();
  }

  private Boolean isTriggerActive() {
    if (Test.isRunningTest() && overrideActive != null) {
      return overrideActive;
    }
    List<Trigger_Control__mdt> controls = [
      SELECT Is_Active__c
      FROM Trigger_Control__mdt
      WHERE Object_Name__c = 'Error_Event__e'
      WITH SECURITY_ENFORCED
      LIMIT 1
    ];
    return controls.isEmpty() || controls[0].Is_Active__c;
  }

  private void writeLogs() {
    List<Error_Log__c> logs = new List<Error_Log__c>();
    for (Error_Event__e evt : (List<Error_Event__e>) Records) {
      logs.add(
        new Error_Log__c(
          Correlation_Id__c = evt.Correlation_Id__c,
          Source__c = evt.Source__c,
          Category__c = evt.Category__c,
          Severity__c = evt.Severity__c,
          Error_Message__c = evt.Error_Message__c,
          Class_Name__c = evt.Class_Name__c,
          Method_Name__c = evt.Method_Name__c,
          Object_API_Name__c = evt.Object_API_Name__c,
          Record_Id__c = evt.Record_Id__c,
          Occurred_At__c = evt.Occurred_At__c
        )
      );
    }

    if (logs.isEmpty()) {
      return;
    }

    Database.SaveResult[] results = Database.insert(logs, false);
    for (Integer i = 0; i < results.size(); i++) {
      if (!results[i].isSuccess()) {
        // Cannot route through ErrorLogger — would feedback-loop on the same event
        System.debug(
          LoggingLevel.ERROR,
          'ErrorEventDomain insert failed for event ' +
            i +
            ': ' +
            results[i].getErrors()
        );
      }
    }
  }

  public class Constructor implements fflib_SObjectDomain.IConstructable {
    public fflib_SObjectDomain construct(List<SObject> sObjectList) {
      return new ErrorEventDomain(sObjectList);
    }
  }
}
