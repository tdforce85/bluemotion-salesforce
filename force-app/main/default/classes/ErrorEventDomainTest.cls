@isTest
private class ErrorEventDomainTest {
  @isTest
  static void testEventCreatesErrorLog() {
    DateTime occurred = DateTime.now();
    Error_Event__e evt = new Error_Event__e(
      Correlation_Id__c = 'corr-test-001',
      Source__c = 'LWC',
      Category__c = 'DML',
      Severity__c = 'High',
      Error_Message__c = 'Hamster validation failed',
      Class_Name__c = 'OverEngineeredLeadController',
      Method_Name__c = 'createLead',
      Object_API_Name__c = 'Lead',
      Record_Id__c = '00Q000000000001',
      Occurred_At__c = occurred
    );

    Test.startTest();
    EventBus.publish(evt);
    Test.stopTest();

    List<Error_Log__c> logs = [
      SELECT
        Correlation_Id__c,
        Source__c,
        Category__c,
        Severity__c,
        Error_Message__c,
        Class_Name__c,
        Method_Name__c,
        Object_API_Name__c,
        Record_Id__c,
        Occurred_At__c,
        Is_Public__c
      FROM Error_Log__c
      WHERE Correlation_Id__c = 'corr-test-001'
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Trigger should have inserted exactly one Error_Log__c for the published event'
    );
    Error_Log__c log = logs[0];
    System.assertEquals('LWC', log.Source__c);
    System.assertEquals('DML', log.Category__c);
    System.assertEquals('High', log.Severity__c);
    System.assertEquals('Hamster validation failed', log.Error_Message__c);
    System.assertEquals('OverEngineeredLeadController', log.Class_Name__c);
    System.assertEquals('createLead', log.Method_Name__c);
    System.assertEquals('Lead', log.Object_API_Name__c);
    System.assertEquals('00Q000000000001', log.Record_Id__c);
    System.assertEquals(
      true,
      log.Is_Public__c,
      'Is_Public__c should default to true on the object'
    );
  }

  @isTest
  static void testKillSwitchSkipsWrite() {
    ErrorEventDomain.overrideActive = false;

    Test.startTest();
    EventBus.publish(
      new Error_Event__e(
        Correlation_Id__c = 'corr-killswitch',
        Source__c = 'LWC',
        Severity__c = 'High',
        Error_Message__c = 'Should not be written'
      )
    );
    Test.stopTest();

    List<Error_Log__c> logs = [
      SELECT Id
      FROM Error_Log__c
      WHERE Correlation_Id__c = 'corr-killswitch'
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Kill switch off should prevent any Error_Log__c write'
    );
  }

  @isTest
  static void testMultipleEventsInOneBatch() {
    List<Error_Event__e> events = new List<Error_Event__e>{
      new Error_Event__e(
        Correlation_Id__c = 'batch-A',
        Source__c = 'LWC',
        Severity__c = 'High',
        Error_Message__c = 'A'
      ),
      new Error_Event__e(
        Correlation_Id__c = 'batch-B',
        Source__c = 'Apex Trigger',
        Severity__c = 'Medium',
        Error_Message__c = 'B'
      ),
      new Error_Event__e(
        Correlation_Id__c = 'batch-C',
        Source__c = 'Queueable',
        Severity__c = 'Low',
        Error_Message__c = 'C'
      )
    };

    Test.startTest();
    EventBus.publish(events);
    Test.stopTest();

    List<Error_Log__c> logs = [
      SELECT Correlation_Id__c
      FROM Error_Log__c
      WHERE Correlation_Id__c IN ('batch-A', 'batch-B', 'batch-C')
    ];
    System.assertEquals(
      3,
      logs.size(),
      'All three events should produce three Error_Log__c records'
    );
  }

  @isTest
  static void testRoundTripFromErrorLogger() {
    Test.startTest();
    ErrorLogger.create()
      .source(ErrorLogger.Source.LWC)
      .category(ErrorLogger.Category.VALIDATION)
      .severity(ErrorLogger.Severity.HIGH)
      .className('ErrorEventDomainTest_RoundTrip')
      .methodName('testRoundTrip')
      .message('End-to-end smoke test')
      .log();
    Test.stopTest();

    List<Error_Log__c> logs = [
      SELECT Source__c, Category__c, Severity__c, Error_Message__c
      FROM Error_Log__c
      WHERE Class_Name__c = 'ErrorEventDomainTest_RoundTrip'
    ];
    System.assertEquals(
      1,
      logs.size(),
      'ErrorLogger.log() → EventBus.publish → trigger → Error_Log__c should yield one record'
    );
    System.assertEquals('LWC', logs[0].Source__c);
    System.assertEquals('Validation', logs[0].Category__c);
    System.assertEquals('High', logs[0].Severity__c);
    System.assertEquals('End-to-end smoke test', logs[0].Error_Message__c);
  }
}
