/**
 * @description Over-Engineered Lead Controller — guest-callable from Experience Cloud.
 *
 * Sharing model: outer class is `with sharing` so DML (createLead) runs as the guest user.
 * Cross-account Lead reads (duplicate detection) require `without sharing` because guest
 * profiles cannot see existing Lead records, so that one query lives in an inner class.
 *
 * All errors route through ErrorLogger for dual-write to Error_Log__c + Error_Event__e.
 */
public with sharing class OverEngineeredLeadController {

    public class LeadResult {
        @AuraEnabled public String  leadId;
        @AuraEnabled public Boolean eventPublished;
    }

    @AuraEnabled(cacheable=false)
    public static List<Lead> checkForDuplicates(String email, String firstName, String lastName) {
        if (String.isBlank(email)) {
            return new List<Lead>();
        }
        return new DuplicateFinder().findByEmailOrName(email, firstName, lastName);
    }

    @AuraEnabled
    public static LeadResult createLead(Map<String, String> leadData) {
        if (leadData == null || String.isBlank(leadData.get('lastName'))) {
            throw new AuraHandledException('LastName is required (obviously)');
        }
        if (String.isBlank(leadData.get('company'))) {
            throw new AuraHandledException('Company is required (we need to know who to invoice)');
        }

        if (!Schema.sObjectType.Lead.isCreateable()
            || !Schema.sObjectType.Lead.fields.LastName.isCreateable()
            || !Schema.sObjectType.Lead.fields.Email.isCreateable()
            || !Schema.sObjectType.Lead.fields.Company.isCreateable()) {
            ErrorLogger.create()
                .source(ErrorLogger.Source.LWC)
                .category(ErrorLogger.Category.SECURITY)
                .severity(ErrorLogger.Severity.HIGH)
                .className('OverEngineeredLeadController')
                .methodName('createLead')
                .objectName('Lead')
                .message('Guest user lacks Create permission on Lead or required fields.')
                .log();
            throw new AuraHandledException('You do not have permission to create Leads.');
        }

        Lead newLead = new Lead(
            FirstName  = leadData.get('firstName'),
            LastName   = leadData.get('lastName'),
            Email      = leadData.get('email'),
            Company    = leadData.get('company'),
            Phone      = leadData.get('phone'),
            LeadSource = 'Over-Engineered Web Form',
            Status     = 'Open - Not Contacted'
        );

        Database.SaveResult result = Database.insert(newLead, false);

        if (!result.isSuccess()) {
            List<String> msgs = new List<String>();
            for (Database.Error err : result.getErrors()) {
                msgs.add(err.getMessage());
            }
            String errorMsg = String.join(msgs, ' ');
            ErrorLogger.create()
                .source(ErrorLogger.Source.LWC)
                .category(ErrorLogger.Category.DML)
                .severity(ErrorLogger.Severity.HIGH)
                .className('OverEngineeredLeadController')
                .methodName('createLead')
                .objectName('Lead')
                .message(errorMsg)
                .log();
            throw new AuraHandledException(errorMsg);
        }

        LeadResult res      = new LeadResult();
        res.leadId          = result.getId();

        LeadSubmission__e evt = new LeadSubmission__e(
            Lead_ID__c = result.getId(),
            Email__c   = leadData.get('email'),
            Company__c = leadData.get('company'),
            Source__c  = 'Over-Engineered Web Form'
        );
        Database.SaveResult evtResult = EventBus.publish(evt);

        if (evtResult.isSuccess()) {
            res.eventPublished = true;
        } else {
            res.eventPublished = false;
            List<String> evtMsgs = new List<String>();
            for (Database.Error err : evtResult.getErrors()) {
                evtMsgs.add(err.getMessage());
            }
            ErrorLogger.create()
                .source(ErrorLogger.Source.PLATFORM_EVENT)
                .category(ErrorLogger.Category.INTEGRATION)
                .severity(ErrorLogger.Severity.MEDIUM)
                .className('OverEngineeredLeadController')
                .methodName('createLead')
                .objectName('LeadSubmission__e')
                .recordId(result.getId())
                .message('Platform Event publish failed: ' + String.join(evtMsgs, ' '))
                .log();
        }

        return res;
    }

    @AuraEnabled(cacheable=true)
    public static Integer getPlatformFeatureCount() {
        return 42;
    }

    /**
     * Elevated read for duplicate detection. Guest users cannot see existing Leads
     * under sharing rules, so this inner class runs `without sharing`. Only the
     * minimal fields needed to render the UI warning are returned.
     */
    private without sharing class DuplicateFinder {
        List<Lead> findByEmailOrName(String email, String firstName, String lastName) {
            String soql = 'SELECT Id, FirstName, LastName, Email FROM Lead WHERE Email = :email';
            Map<String, Object> binds = new Map<String, Object>{ 'email' => email };

            if (String.isNotBlank(firstName) && String.isNotBlank(lastName)) {
                soql += ' OR (FirstName = :firstName AND LastName = :lastName)';
                binds.put('firstName', firstName);
                binds.put('lastName', lastName);
            }
            soql += ' ORDER BY CreatedDate DESC LIMIT 10';

            return Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
        }
    }
}
