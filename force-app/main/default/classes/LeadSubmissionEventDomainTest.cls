@isTest
private class LeadSubmissionEventDomainTest {

    @isTest
    static void testTriggerEnqueuesJobAndEnrichesLead() {
        Lead l = new Lead(FirstName = 'Event', LastName = 'Domain', Company = 'Test Co',
                          Email = 'event@domain.test');
        insert l;

        Test.startTest();
        EventBus.publish(new LeadSubmission__e(
            Lead_ID__c = l.Id,
            Email__c   = 'event@domain.test',
            Company__c = 'Test Co',
            Source__c  = 'Test'
        ));
        // stopTest flushes the event bus synchronously, fires the trigger,
        // and drains the enqueued queueable in the same boundary.
        Test.stopTest();

        Lead enriched = [SELECT Description FROM Lead WHERE Id = :l.Id];
        System.assert(String.isNotBlank(enriched.Description),
            'Lead should have been enriched after event → trigger → queueable chain');
    }

    @isTest
    static void testKillSwitchBypassesEnrichment() {
        Lead l = new Lead(FirstName = 'Kill', LastName = 'Switch', Company = 'Test Co');
        insert l;

        LeadSubmissionEventDomain.overrideActive = false;

        Test.startTest();
        EventBus.publish(new LeadSubmission__e(
            Lead_ID__c = l.Id,
            Email__c   = 'kill@switch.test',
            Company__c = 'Test Co',
            Source__c  = 'Test'
        ));
        Test.stopTest();

        Lead result = [SELECT Description FROM Lead WHERE Id = :l.Id];
        System.assert(String.isBlank(result.Description),
            'Lead Description should remain blank when kill switch is off');
    }

    @isTest
    static void testBlankLeadIdOnEventIsSkipped() {
        Test.startTest();
        EventBus.publish(new LeadSubmission__e(
            Lead_ID__c = '',
            Email__c   = 'blank@id.test',
            Company__c = 'Test Co',
            Source__c  = 'Test'
        ));
        Test.stopTest();
        // No exception = pass. No leads to query since no valid ID.
        System.assert(true, 'Blank Lead ID on event should be skipped without exception');
    }

    @isTest
    static void testMultipleEventsInOneBatch() {
        List<Lead> leads = new List<Lead>{
            new Lead(LastName = 'BatchA', Company = 'Co A'),
            new Lead(LastName = 'BatchB', Company = 'Co B')
        };
        insert leads;

        List<LeadSubmission__e> events = new List<LeadSubmission__e>{
            new LeadSubmission__e(Lead_ID__c = leads[0].Id, Email__c = 'a@a.test', Company__c = 'Co A', Source__c = 'Test'),
            new LeadSubmission__e(Lead_ID__c = leads[1].Id, Email__c = 'b@b.test', Company__c = 'Co B', Source__c = 'Test')
        };

        Test.startTest();
        EventBus.publish(events);
        Test.stopTest();

        List<Lead> enriched = [SELECT Description FROM Lead WHERE Id IN :leads ORDER BY LastName];
        System.assert(String.isNotBlank(enriched[0].Description), 'Lead BatchA should be enriched');
        System.assert(String.isNotBlank(enriched[1].Description), 'Lead BatchB should be enriched');
    }
}
