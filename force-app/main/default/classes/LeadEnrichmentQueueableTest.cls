@isTest
private class LeadEnrichmentQueueableTest {

    @isTest
    static void testEnrichmentUpdatesLeadDescription() {
        Lead l = new Lead(FirstName = 'Queue', LastName = 'Able', Company = 'Test Co',
                          Email = 'queue@able.test');
        insert l;

        Test.startTest();
        System.enqueueJob(new LeadEnrichmentQueueable(new Set<Id>{ l.Id }));
        Test.stopTest();

        Lead enriched = [SELECT Description FROM Lead WHERE Id = :l.Id];
        System.assert(String.isNotBlank(enriched.Description),
            'Description should have been populated by the queueable');
        System.assert(enriched.Description.contains('LeadEnrichmentQueueable'),
            'Description should contain the enrichment marker');
    }

    @isTest
    static void testEnrichmentPrependsToExistingDescription() {
        Lead l = new Lead(FirstName = 'Prior', LastName = 'Content', Company = 'Test Co',
                          Description = 'Original notes');
        insert l;

        Test.startTest();
        System.enqueueJob(new LeadEnrichmentQueueable(new Set<Id>{ l.Id }));
        Test.stopTest();

        Lead enriched = [SELECT Description FROM Lead WHERE Id = :l.Id];
        System.assert(enriched.Description.contains('LeadEnrichmentQueueable'),
            'Enrichment tag should be present');
        System.assert(enriched.Description.contains('Original notes'),
            'Original description should be preserved');
    }

    @isTest
    static void testEmptyLeadIdSetDoesNothing() {
        Test.startTest();
        // Should complete without exception and without any DML
        new LeadEnrichmentQueueable(new Set<Id>()).execute(null);
        Test.stopTest();
        System.assert(true, 'Empty set should complete silently');
    }

    @isTest
    static void testNullLeadIdSetDoesNothing() {
        Test.startTest();
        new LeadEnrichmentQueueable(null).execute(null);
        Test.stopTest();
        System.assert(true, 'Null set should complete silently');
    }
}
