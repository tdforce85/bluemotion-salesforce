@isTest
private class ErrorLogControllerTest {

    @TestSetup
    static void makeData() {
        List<Error_Log__c> logs = new List<Error_Log__c>{
            new Error_Log__c(
                Source__c = 'LWC', Category__c = 'DML', Severity__c = 'High',
                Error_Message__c = 'Test LWC error', Is_Public__c = true,
                Occurred_At__c = System.now()
            ),
            new Error_Log__c(
                Source__c = 'Queueable', Category__c = 'Business Rule', Severity__c = 'Critical',
                Error_Message__c = 'Test Queueable error', Is_Public__c = true,
                Occurred_At__c = System.now()
            ),
            new Error_Log__c(
                Source__c = 'Apex Trigger', Category__c = 'Validation', Severity__c = 'High',
                Error_Message__c = 'Private error — should not appear', Is_Public__c = false,
                Occurred_At__c = System.now()
            )
        };
        Database.insert(logs, AccessLevel.SYSTEM_MODE);
    }

    @isTest
    static void testGetErrorSummaryReturnsSeverityCounts() {
        List<ErrorLogController.SeveritySummary> summaries = ErrorLogController.getErrorSummary();
        System.assertNotEquals(null, summaries, 'Summary should not be null');

        Map<String, Integer> countBySev = new Map<String, Integer>();
        for (ErrorLogController.SeveritySummary s : summaries) {
            countBySev.put(s.severity, s.count);
        }
        // Critical=1, High=1 from public records; private record excluded
        System.assertEquals(1, countBySev.get('Critical'), 'Should have 1 Critical');
        System.assertEquals(1, countBySev.get('High'),     'Should have 1 High');
        System.assertEquals(false, countBySev.containsKey(null), 'No null severity expected');
    }

    @isTest
    static void testGetRecentErrorsExcludesPrivate() {
        List<Error_Log__c> recent = ErrorLogController.getRecentErrors();
        System.assertNotEquals(null, recent, 'Recent errors should not be null');
        for (Error_Log__c log : recent) {
            System.assertNotEquals('Private error — should not appear', log.Error_Message__c,
                'Private records should not appear in the public feed');
        }
        System.assertEquals(2, recent.size(), 'Should return only the 2 public records');
    }

    @isTest
    static void testGetErrorsBySourceGroupsCorrectly() {
        List<ErrorLogController.SourceSummary> summaries = ErrorLogController.getErrorsBySource();
        System.assertNotEquals(null, summaries, 'Source summary should not be null');

        Map<String, Integer> countBySrc = new Map<String, Integer>();
        for (ErrorLogController.SourceSummary s : summaries) {
            countBySrc.put(s.source, s.count);
        }
        System.assertEquals(1, countBySrc.get('LWC'),       'LWC should have 1 public record');
        System.assertEquals(1, countBySrc.get('Queueable'), 'Queueable should have 1 public record');
        System.assertEquals(false, countBySrc.containsKey('Apex Trigger'),
            'Apex Trigger record is private and should be excluded');
    }
}
