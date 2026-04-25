@isTest
private class ErrorLoggerTest {

    @isTest
    static void testBuilderWritesToErrorLog() {
        Test.startTest();
        ErrorLogger.create()
            .source(ErrorLogger.Source.LWC)
            .category(ErrorLogger.Category.DML)
            .severity(ErrorLogger.Severity.HIGH)
            .className('TestClass')
            .methodName('testMethod')
            .objectName('Lead')
            .recordId('001000000000001')
            .message('Test error message')
            .log();
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Source__c, Category__c, Severity__c,
                   Class_Name__c, Method_Name__c, Object_API_Name__c,
                   Record_Id__c, Error_Message__c, Correlation_Id__c, Is_Public__c
            FROM Error_Log__c
        ];
        System.assertEquals(1, logs.size(), 'One Error_Log__c record should have been created');
        Error_Log__c log = logs[0];
        System.assertEquals('LWC',          log.Source__c);
        System.assertEquals('DML',          log.Category__c);
        System.assertEquals('High',         log.Severity__c);
        System.assertEquals('TestClass',    log.Class_Name__c);
        System.assertEquals('testMethod',   log.Method_Name__c);
        System.assertEquals('Lead',         log.Object_API_Name__c);
        System.assertEquals('Test error message', log.Error_Message__c);
        System.assertEquals(true,           log.Is_Public__c);
        System.assertNotEquals(null,        log.Correlation_Id__c);
    }

    @isTest
    static void testCorrelationIdReuseWithinTransaction() {
        Test.startTest();
        ErrorLogger.create().source(ErrorLogger.Source.QUEUEABLE).category(ErrorLogger.Category.DML)
            .severity(ErrorLogger.Severity.LOW).message('First').log();
        ErrorLogger.create().source(ErrorLogger.Source.APEX_TRIGGER).category(ErrorLogger.Category.VALIDATION)
            .severity(ErrorLogger.Severity.MEDIUM).message('Second').log();
        Test.stopTest();

        List<Error_Log__c> logs = [SELECT Correlation_Id__c FROM Error_Log__c ORDER BY CreatedDate];
        System.assertEquals(2, logs.size(), 'Two log records expected');
        System.assertEquals(logs[0].Correlation_Id__c, logs[1].Correlation_Id__c,
            'Both records in the same transaction should share the same correlation ID');
    }

    @isTest
    static void testCorrelationIdIsValidUUIDFormat() {
        String corrId = ErrorLogger.getCorrelationId();
        System.assertNotEquals(null, corrId, 'Correlation ID should not be null');
        System.assertEquals(36, corrId.length(), 'UUID should be 36 characters');
        // UUID format: 8-4-4-4-12
        List<String> parts = corrId.split('-');
        System.assertEquals(5, parts.size(), 'UUID should have 5 hyphen-separated segments');
    }

    @isTest
    static void testAllSourceValues() {
        Test.startTest();
        for (ErrorLogger.Source src : ErrorLogger.Source.values()) {
            ErrorLogger.create().source(src).category(ErrorLogger.Category.BUSINESS_RULE)
                .severity(ErrorLogger.Severity.INFO).message('Source test: ' + src).log();
        }
        Test.stopTest();
        // All sources logged without exception — primary assertion is no exception thrown
        System.assert(true, 'All Source enum values should log without error');
    }

    @isTest
    static void testAllCategoryValues() {
        Test.startTest();
        for (ErrorLogger.Category cat : ErrorLogger.Category.values()) {
            ErrorLogger.create().source(ErrorLogger.Source.LWC).category(cat)
                .severity(ErrorLogger.Severity.INFO).message('Category test: ' + cat).log();
        }
        Test.stopTest();
        System.assert(true, 'All Category enum values should log without error');
    }

    @isTest
    static void testAllSeverityValues() {
        Test.startTest();
        for (ErrorLogger.Severity sev : ErrorLogger.Severity.values()) {
            ErrorLogger.create().source(ErrorLogger.Source.LWC).category(ErrorLogger.Category.DML)
                .severity(sev).message('Severity test: ' + sev).log();
        }
        Test.stopTest();
        System.assert(true, 'All Severity enum values should log without error');
    }

    @isTest
    static void testNullFieldsHandledGracefully() {
        Test.startTest();
        // Calling log() with no fields set should not throw
        ErrorLogger.create().message('Minimal log entry').log();
        Test.stopTest();
        System.assert(true, 'Null enum fields should not cause an exception');
    }
}
